import os
import json
import re
from datetime import datetime
from typing import Dict, List
from dataclasses import dataclass

from google.cloud import bigquery
from flask import Flask, render_template, request, jsonify, session

# Nuevo import para ADK
from google.generativeai.agents import Agent, FunctionTool

PROJECT_ID = "jrodriguez-sandbox"

class ConversationContext:
    """Maneja el contexto de la conversación por usuario"""
    def __init__(self):
        self.consultant_id = None
        self.consultant_name = None
        self.plan_type = None
        self.last_quarter = None
        self.last_year = None
        self.conversation_history = []

    def update_consultant(self, consultant_id, consultant_name=None, plan_type=None):
        self.consultant_id = consultant_id
        self.consultant_name = consultant_name
        self.plan_type = plan_type

    def update_time_period(self, quarter=None, year=None):
        if quarter:
            self.last_quarter = quarter
        if year:
            self.last_year = year

    def add_to_history(self, user_message, agent_response):
        self.conversation_history.append({
            "user": user_message,
            "agent": agent_response,
            "timestamp": datetime.now().isoformat()
        })
        if len(self.conversation_history) > 5:
            self.conversation_history = self.conversation_history[-5:]

@dataclass
class BonusCalculation:
    consultant_id: str
    consultant_name: str
    plan_type: str
    quarter: int
    year: int
    total_bonus: float
    breakdown: Dict[str, float]
    recommendations: List[str]

class BonusAdvisorAgent:
    def __init__(self):
        self.client = bigquery.Client(project=PROJECT_ID)
        self.table_id = f"{PROJECT_ID}.hackathon_bonus_update.quarterly_bonus_results"

        # Mapeo de consultores
        self.consultants = {
            "CONS001": {"name": "Rodolfo Solar", "plan": "Sales"},
            "CONS002": {"name": "Anthony Alarcon", "plan": "Delivery"},
            "CONS003": {"name": "Julian Rodriguez", "plan": "Hybrid"}
        }

        # Construimos el agente del ADK
        self.agent = Agent(
            model="models/gemini-2.5-flash",
            instructions=(
                "Eres un asistente experto en el sistema de bonos de la empresa. "
                "Responde en tono conversacional y directo, usando contexto cuando esté disponible. "
                "Si se requiere información sobre bonos, llama a las funciones registradas. "
                "Si ya tienes el ID del consultor, úsalo sin pedirlo nuevamente."
            )
        )

        # Registramos funciones como herramientas del agente
        self.agent.register_tool(FunctionTool(self.get_consultant_bonus))
        self.agent.register_tool(FunctionTool(self.get_bonus_breakdown))
        self.agent.register_tool(FunctionTool(self.get_improvement_recommendations))

    # === FUNCIONES DE NEGOCIO (mantenemos igual) ===
    def get_consultant_bonus(self, consultant_id: str, quarter: int = None, year: int = None) -> Dict:
        try:
            query = f"""
            SELECT *
            FROM `{self.table_id}`
            WHERE consultant_id = @consultant_id
            """
            job_config = bigquery.QueryJobConfig(
                query_parameters=[bigquery.ScalarQueryParameter("consultant_id", "STRING", consultant_id)]
            )
            if quarter and year:
                query += " AND quarter = @quarter AND year = @year"
                job_config.query_parameters.extend([
                    bigquery.ScalarQueryParameter("quarter", "INT64", quarter),
                    bigquery.ScalarQueryParameter("year", "INT64", year)
                ])
            query += " ORDER BY year DESC, quarter DESC LIMIT 1"

            results = self.client.query(query, job_config=job_config).to_dataframe()
            if results.empty:
                return {"error": "Consultor no encontrado"}
            return results.iloc[0].to_dict()
        except Exception as e:
            return {"error": f"Error consultando BigQuery: {str(e)}"}

    def get_bonus_breakdown(self, consultant_id: str, quarter: int = None, year: int = None) -> Dict:
        data = self.get_consultant_bonus(consultant_id, quarter, year)
        if "error" in data:
            return data
        breakdown = {
            "Company Performance": {
                "Company Booking Bonus": data.get("company_booking_bonus", 0),
                "Recurring Business Bonus": data.get("recurring_business_bonus", 0)
            },
            "Individual Performance": {
                "Individual Commission": data.get("individual_commission", 0),
                "Utilization Bonus": data.get("utilization_bonus", 0),
                "Efficiency Bonus": data.get("efficiency_bonus", 0),
                "Timeline Bonus": data.get("timeline_bonus", 0)
            },
            "Global Performance": {
                "Customer Satisfaction Bonus": data.get("customer_satisfaction_bonus", 0),
                "MBO Bonus": data.get("mbo_bonus", 0)
            }
        }
        return {
            "consultant_name": data.get("consultant_name"),
            "plan_type": data.get("plan_type"),
            "total_bonus": data.get("total_bonus", 0),
            "breakdown": breakdown,
            "period": f"Q{data.get('quarter', 'N/A')} {data.get('year', 'N/A')}"
        }

    def get_improvement_recommendations(self, consultant_id: str, plan_type: str) -> List[str]:
        data = self.get_consultant_bonus(consultant_id)
        if "error" in data:
            return ["Error: Consultor no encontrado"]

        recommendations = []
        if plan_type == "Sales":
            if data.get("individual_tcv", 0) < 1000000:
                recommendations.append("Enfócate en cerrar deals de mayor valor para alcanzar $1M TCV.")
        elif plan_type == "Hybrid":
            if data.get("project_hours", 0) < 225:
                recommendations.append("Incrementa horas de proyecto para obtener utilization bonus.")
        elif plan_type == "Delivery":
            if data.get("project_hours", 0) < 450:
                recommendations.append("Aumenta las horas de proyecto para maximizar el bonus.")
        return recommendations

    def chat_with_agent(self, user_message: str, session_id: str) -> str:
        """Llamada principal al agente usando ADK."""
        response = self.agent.query(user_message, session_id=session_id)
        return response.text or "No pude procesar tu consulta."

# Flask App
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key')
bonus_agent = BonusAdvisorAgent()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    data = request.json
    user_message = data.get('message', '')
    session_id = session.get('session_id', 'default')
    if 'session_id' not in session:
        session['session_id'] = session_id
    response = bonus_agent.chat_with_agent(user_message, session_id)
    return jsonify({'response': response})

@app.route('/api/bonus/<consultant_id>')
def get_bonus_api(consultant_id):
    quarter = request.args.get('quarter', type=int)
    year = request.args.get('year', type=int)
    result = bonus_agent.get_consultant_bonus(consultant_id, quarter, year)
    return jsonify(result)

@app.route('/api/breakdown/<consultant_id>')
def get_breakdown_api(consultant_id):
    quarter = request.args.get('quarter', type=int)
    year = request.args.get('year', type=int)
    result = bonus_agent.get_bonus_breakdown(consultant_id, quarter, year)
    return jsonify(result)

@app.route('/api/recommendations/<consultant_id>/<plan_type>')
def get_recommendations_api(consultant_id, plan_type):
    result = bonus_agent.get_improvement_recommendations(consultant_id, plan_type)
    return jsonify({'recommendations': result})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=True)
