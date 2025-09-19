import requests
import pandas as pd
from datetime import datetime, timedelta
from google.cloud import bigquery

class ClickUpIntegration:
    def __init__(self, api_token, team_id):
        self.api_token = api_token
        self.team_id = team_id
        self.base_url = "https://api.clickup.com/api/v2"
        self.headers = {
            'Authorization': api_token,
            'Content-Type': 'application/json'
        }
    
    def get_time_entries(self, start_date, end_date, assignee=None):
        """Obtener time entries de ClickUp"""
        url = f"{self.base_url}/team/{self.team_id}/time_entries"
        
        params = {
            'start_date': int(start_date.timestamp() * 1000),
            'end_date': int(end_date.timestamp() * 1000),
            'include_task_tags': 'true',
            'include_location_names': 'true'
        }
        
        if assignee:
            params['assignee'] = assignee
            
        response = requests.get(url, headers=self.headers, params=params)
        return response.json()
    
    def process_time_entries(self, time_entries):
        """Procesar entries para formato BigQuery"""
        processed_data = []
        
        for entry in time_entries['data']:
            # Convertir milliseconds a horas
            hours = int(entry['time']) / (1000 * 60 * 60)
            
            # Obtener fechas de la semana
            start_date = datetime.fromtimestamp(int(entry['start']) / 1000)
            week_start = start_date - timedelta(days=start_date.weekday())
            week_end = week_start + timedelta(days=4)  # Viernes
            
            processed_entry = {
                'report_id': f"CLK_{entry['id']}",
                'consultant_id': self.map_user_to_consultant(entry['user']['email']),
                'project_id': self.map_task_to_project(entry['task']),
                'week_start_date': week_start.date(),
                'week_end_date': week_end.date(),
                'logged_hours': hours,
                'quarter': self.get_quarter(start_date),
                'year': start_date.year,
                'week_number': start_date.isocalendar()[1]
            }
            processed_data.append(processed_entry)
        
        return processed_data
    
    def map_user_to_consultant(self, email):
        """Mapear email de ClickUp a consultant_id"""
        mapping = {
            'anthony@company.com': 'CONS002',
            'julian@company.com': 'CONS003',
            # Agregar más mappings según necesidad
        }
        return mapping.get(email, 'UNKNOWN')
    
    def map_task_to_project(self, task):
        """Mapear task de ClickUp a project_id"""
        # Lógica para mapear tasks a proyectos
        # Puede usar tags, nombres de proyecto, etc.
        project_mapping = {
            'Atlantic City': 'PROJ001',
            'Etafashion': 'PROJ002',
            'Chinalco': 'PROJ003',
            # Agregar más mappings
        }
        
        for keyword, project_id in project_mapping.items():
            if keyword.lower() in task.get('name', '').lower():
                return project_id
        
        return 'PROJ_UNKNOWN'
    
    def get_quarter(self, date):
        """Obtener quarter de una fecha"""
        return (date.month - 1) // 3 + 1
    
    def upload_to_bigquery(self, processed_data):
        """Subir datos a BigQuery"""
        client = bigquery.Client()
        table_id = "jrodriguez-sandbox.hackathon_bonus_update.consultant_report"
        
        df = pd.DataFrame(processed_data)
        
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_APPEND",  # Agregar datos
            schema_update_options=[bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION]
        )
        
        job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
        job.result()
        
        print(f"Loaded {len(processed_data)} time entries to BigQuery")

# Uso del integrador
def sync_clickup_weekly():
    """Función para ejecutar semanalmente"""
    integrator = ClickUpIntegration('pk_YOUR_TOKEN', 'your_team_id')
    
    # Obtener datos de la semana pasada
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    
    time_entries = integrator.get_time_entries(start_date, end_date)
    processed_data = integrator.process_time_entries(time_entries)
    integrator.upload_to_bigquery(processed_data)