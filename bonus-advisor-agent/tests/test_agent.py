import pytest
import unittest.mock as mock
from unittest.mock import patch, MagicMock
import pandas as pd
import json
import sys
import os

# Add the parent directory to sys.path to import main
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import BonusAdvisorAgent


class TestBonusAdvisorAgent:
    """Test suite para el Bonus Advisor Agent"""
    
    @pytest.fixture
    def mock_bigquery_client(self):
        """Mock del cliente de BigQuery"""
        with patch('main.bigquery.Client') as mock_client:
            yield mock_client.return_value
    
    @pytest.fixture
    def bonus_agent(self, mock_bigquery_client):
        """Instancia del agente con mocks"""
        with patch('main.vertexai.init'), \
             patch('main.GenerativeModel'):
            agent = BonusAdvisorAgent()
            agent.client = mock_bigquery_client
            return agent
    
    @pytest.fixture
    def sample_consultant_data(self):
        """Datos de ejemplo de un consultor"""
        return {
            'consultant_id': 'CONS001',
            'consultant_name': 'Rodolfo Solar',
            'plan_type': 'Sales',
            'quarter': 2,
            'year': 2025,
            'company_booking_total': 602760.0,
            'company_target_achievement_pct': 100.46,
            'company_booking_bonus': 500.0,
            'recurring_business_pct': 22.5,
            'recurring_business_bonus': 250.0,
            'individual_tcv': 602760.0,
            'individual_commission': 12055.20,
            'project_hours': 0.0,
            'total_quarter_hours': 520.0,
            'project_hours_percentage': 0.0,
            'utilization_bonus': 0.0,
            'efficiency_bonus': 0.0,
            'timeline_adherence_percentage': 0.0,
            'timeline_bonus': 0.0,
            'customer_satisfaction_score': 4.0,
            'customer_satisfaction_bonus': 0.0,
            'mbo_completed': True,
            'mbo_bonus': 500.0,
            'total_bonus': 13305.20,
            'calculation_date': '2025-07-01T10:00:00Z'
        }
    
    def test_get_consultant_bonus_success(self, bonus_agent, mock_bigquery_client, sample_consultant_data):
        """Test exitoso de obtención de bono de consultor"""
        # Configurar mock
        mock_query_job = MagicMock()
        mock_df = pd.DataFrame([sample_consultant_data])
        mock_query_job.to_dataframe.return_value = mock_df
        mock_bigquery_client.query.return_value = mock_query_job
        
        # Ejecutar test
        result = bonus_agent.get_consultant_bonus('CONS001', 2, 2025)
        
        # Verificaciones
        assert result['consultant_id'] == 'CONS001'
        assert result['consultant_name'] == 'Rodolfo Solar'
        assert result['total_bonus'] == 13305.20
        assert result['plan_type'] == 'Sales'
        
        # Verificar que se hizo la query correcta
        mock_bigquery_client.query.assert_called_once()
        call_args = mock_bigquery_client.query.call_args
        assert 'consultant_id = @consultant_id' in call_args[0][0]
    
    def test_get_consultant_bonus_not_found(self, bonus_agent, mock_bigquery_client):
        """Test cuando no se encuentra el consultor"""
        # Configurar mock para retornar DataFrame vacío
        mock_query_job = MagicMock()
        mock_query_job.to_dataframe.return_value = pd.DataFrame()
        mock_bigquery_client.query.return_value = mock_query_job
        
        # Ejecutar test
        result = bonus_agent.get_consultant_bonus('INVALID_ID')
        
        # Verificaciones
        assert 'error' in result
        assert result['error'] == 'Consultor no encontrado'
    
    def test_get_bonus_breakdown_success(self, bonus_agent, mock_bigquery_client, sample_consultant_data):
        """Test de desglose de bonos"""
        # Configurar mock
        mock_query_job = MagicMock()
        mock_df = pd.DataFrame([sample_consultant_data])
        mock_query_job.to_dataframe.return_value = mock_df
        mock_bigquery_client.query.return_value = mock_query_job
        
        # Ejecutar test
        result = bonus_agent.get_bonus_breakdown('CONS001', 2, 2025)
        
        # Verificaciones
        assert 'breakdown' in result
        assert 'Company Performance' in result['breakdown']
        assert 'Individual Performance' in result['breakdown']
        assert 'Global Performance' in result['breakdown']
        
        # Verificar valores específicos
        company_perf = result['breakdown']['Company Performance']
        assert company_perf['Company Booking Bonus'] == 500.0
        assert company_perf['Recurring Business Bonus'] == 250.0
        
        individual_perf = result['breakdown']['Individual Performance']
        assert individual_perf['Individual Commission'] == 12055.20
        
        assert result['total_bonus'] == 13305.20
        assert result['consultant_name'] == 'Rodolfo Solar'
    
    def test_get_improvement_recommendations_sales(self, bonus_agent, mock_bigquery_client, sample_consultant_data):
        """Test de recomendaciones para plan Sales"""
        # Modificar datos para generar recomendaciones específicas
        low_tcv_data = sample_consultant_data.copy()
        low_tcv_data['individual_tcv'] = 50000.0
        low_tcv_data['company_booking_bonus'] = 250.0
        
        # Configurar mock
        mock_query_job = MagicMock()
        mock_df = pd.DataFrame([low_tcv_data])
        mock_query_job.to_dataframe.return_value = mock_df
        mock_bigquery_client.query.return_value = mock_query_job
        
        # Ejecutar test
        result = bonus_agent.get_improvement_recommendations('CONS001', 'Sales')
        
        # Verificaciones
        assert isinstance(result, list)
        assert len(result) > 0
        
        # Verificar que incluye recomendaciones específicas para Sales
        recommendations_text = ' '.join(result)
        assert 'TCV' in recommendations_text or '$1M' in recommendations_text
    
    def test_get_improvement_recommendations_hybrid(self, bonus_agent, mock_bigquery_client, sample_consultant_data):
        """Test de recomendaciones para plan Hybrid"""
        # Modificar datos para consultor Hybrid con bajo rendimiento
        hybrid_data = sample_consultant_data.copy()
        hybrid_data.update({
            'plan_type': 'Hybrid',
            'project_hours': 150.0,  # Bajo
            'efficiency_bonus': 0.0,  # Sin bonus de efficiency
            'timeline_bonus': 0.0,   # Sin bonus de timeline
            'individual_commission': 0.0  # Hybrid no tiene comisión
        })
        
        # Configurar mock
        mock_query_job = MagicMock()
        mock_df = pd.DataFrame([hybrid_data])
        mock_query_job.to_dataframe.return_value = mock_df
        mock_bigquery_client.query.return_value = mock_query_job
        
        # Ejecutar test
        result = bonus_agent.get_improvement_recommendations('CONS001', 'Hybrid')
        
        # Verificaciones
        assert isinstance(result, list)
        recommendations_text = ' '.join(result)
        assert 'horas' in recommendations_text.lower() or 'efficiency' in recommendations_text.lower()
    
    def test_get_improvement_recommendations_delivery(self, bonus_agent, mock_bigquery_client, sample_consultant_data):
        """Test de recomendaciones para plan Delivery"""
        # Modificar datos para consultor Delivery
        delivery_data = sample_consultant_data.copy()
        delivery_data.update({
            'plan_type': 'Delivery',
            'project_hours': 300.0,  # Bajo para Delivery
            'efficiency_bonus': 0.0,
            'individual_tcv': 0.0,  # Delivery no participa en deals
            'individual_commission': 0.0
        })
        
        # Configurar mock
        mock_query_job = MagicMock()
        mock_df = pd.DataFrame([delivery_data])
        mock_query_job.to_dataframe.return_value = mock_df
        mock_bigquery_client.query.return_value = mock_query_job
        
        # Ejecutar test
        result = bonus_agent.get_improvement_recommendations('CONS001', 'Delivery')
        
        # Verificaciones
        assert isinstance(result, list)
        recommendations_text = ' '.join(result)
        assert '450' in recommendations_text or 'horas' in recommendations_text.lower()
    
    def test_compare_performance_success(self, bonus_agent, mock_bigquery_client, sample_consultant_data):
        """Test de comparación de performance"""
        # Mock para datos del consultor
        mock_query_job_consultant = MagicMock()
        mock_df_consultant = pd.DataFrame([sample_consultant_data])
        mock_query_job_consultant.to_dataframe.return_value = mock_df_consultant
        
        # Mock para datos promedio
        mock_query_job_avg = MagicMock()
        avg_data = {
            'avg_total_bonus': 10000.0,
            'avg_project_hours': 200.0,
            'avg_individual_tcv': 400000.0,
            'total_consultants': 3
        }
        mock_df_avg = pd.DataFrame([avg_data])
        mock_query_job_avg.to_dataframe.return_value = mock_df_avg
        
        # Configurar mock para retornar diferentes resultados en llamadas secuenciales
        mock_bigquery_client.query.side_effect = [mock_query_job_consultant, mock_query_job_avg]
        
        # Ejecutar test
        result = bonus_agent.compare_performance('CONS001', 2, 2025)
        
        # Verificaciones
        assert 'consultant' in result
        assert 'plan_average' in result
        assert 'performance_vs_average' in result
        
        # Verificar estructura de datos
        assert result['consultant']['name'] == 'Rodolfo Solar'
        assert result['consultant']['total_bonus'] == 13305.20
        assert result['plan_average']['total_bonus'] == 10000.0
        
        # Verificar cálculo de performance vs average
        performance = result['performance_vs_average']
        assert performance['is_above_average'] == True
        assert performance['bonus_percentage'] > 100  # Está por encima del promedio
    
    def test_explain_kpi_definition_valid(self, bonus_agent):
        """Test de explicación de KPI válido"""
        result = bonus_agent.explain_kpi_definition('company_booking_target')
        
        # Verificaciones
        assert 'name' in result
        assert 'description' in result
        assert 'formula' in result
        assert 'target' in result
        assert result['name'] == 'Company Booking Target'
        assert '$600,000' in result['target']
    
    def test_explain_kpi_definition_invalid(self, bonus_agent):
        """Test de explicación de KPI inválido"""
        result = bonus_agent.explain_kpi_definition('invalid_kpi')
        
        # Verificaciones
        assert 'error' in result
        assert 'no encontrado' in result['error']
    
    @patch('main.GenerativeModel')
    def test_chat_with_agent_success(self, mock_model_class, bonus_agent):
        """Test de chat con el agente"""
        # Configurar mock del modelo
        mock_model = MagicMock()
        mock_response = MagicMock()
        mock_response.text = "Esta es la respuesta del agente sobre tu bono actual."
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model
        
        # Actualizar la instancia del modelo en bonus_agent
        bonus_agent.model = mock_model
        
        # Ejecutar test
        result = bonus_agent.chat_with_agent("¿Cuál es mi bono actual?", "CONS001")
        
        # Verificaciones
        assert isinstance(result, str)
        assert "respuesta del agente" in result
        mock_model.generate_content.assert_called_once()
    
    @patch('main.GenerativeModel')
    def test_chat_with_agent_error(self, mock_model_class, bonus_agent):
        """Test de manejo de errores en chat"""
        # Configurar mock para lanzar excepción
        mock_model = MagicMock()
        mock_model.generate_content.side_effect = Exception("Error de conexión")
        mock_model_class.return_value = mock_model
        bonus_agent.model = mock_model
        
        # Ejecutar test
        result = bonus_agent.chat_with_agent("Test message", "CONS001")
        
        # Verificaciones
        assert "Error al procesar la consulta" in result
        assert "Error de conexión" in result


class TestKPIDefinitions:
    """Test específicos para las definiciones de KPIs"""
    
    @pytest.fixture
    def bonus_agent(self):
        """Instancia simple del agente para probar definiciones"""
        with patch('main.bigquery.Client'), \
             patch('main.vertexai.init'), \
             patch('main.GenerativeModel'):
            return BonusAdvisorAgent()
    
    def test_all_kpi_definitions_exist(self, bonus_agent):
        """Verificar que todas las definiciones de KPI están completas"""
        expected_kpis = [
            'company_booking_target',
            'recurring_business', 
            'individual_tcv'
        ]
        
        for kpi in expected_kpis:
            definition = bonus_agent.kpi_definitions.get(kpi)
            assert definition is not None, f"KPI {kpi} no está definido"
            assert 'name' in definition
            assert 'description' in definition
            assert 'formula' in definition
    
    def test_kpi_formulas_are_valid_sql(self, bonus_agent):
        """Verificar que las fórmulas SQL son válidas"""
        for kpi_name, definition in bonus_agent.kpi_definitions.items():
            formula = definition.get('formula', '')
            
            # Verificaciones básicas de SQL
            assert 'SUM(' in formula.upper() or 'AVG(' in formula.upper() or 'COUNT(' in formula.upper(), \
                f"Fórmula de {kpi_name} no contiene funciones SQL válidas"
            
            if 'company_booking' in kpi_name:
                assert 'deal_amount' in formula.lower(), \
                    f"Fórmula de booking debe incluir deal_amount"


# Tests de integración mock
class TestIntegration:
    """Tests de integración con mocks"""
    
    @pytest.fixture
    def app_client(self):
        """Cliente de prueba para Flask app"""
        import main
        main.app.config['TESTING'] = True
        with main.app.test_client() as client:
            yield client
    
    @patch('main.BonusAdvisorAgent')
    def test_api_bonus_endpoint(self, mock_agent_class, app_client):
        """Test del endpoint de API para bonos"""
        # Configurar mock
        mock_agent = MagicMock()
        mock_agent.get_consultant_bonus.return_value = {
            'consultant_name': 'Test User',
            'total_bonus': 5000.0
        }
        mock_agent_class.return_value = mock_agent
        
        # Hacer petición
        response = app_client.get('/api/bonus/CONS001?quarter=2&year=2025')
        
        # Verificaciones
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['consultant_name'] == 'Test User'
        assert data['total_bonus'] == 5000.0


if __name__ == '__main__':
    # Ejecutar tests
    pytest.main([__file__, '-v', '--tb=short'])