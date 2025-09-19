from google.oauth2 import service_account
from googleapiclient.discovery import build
import pandas as pd
from datetime import datetime

class GoogleFormsIntegration:
    def __init__(self, service_account_path, form_id):
        self.form_id = form_id
        self.credentials = service_account.Credentials.from_service_account_file(
            service_account_path,
            scopes=['https://www.googleapis.com/auth/forms.responses.readonly']
        )
        self.service = build('forms', 'v1', credentials=self.credentials)
    
    def get_form_responses(self):
        """Obtener todas las respuestas del formulario"""
        try:
            # Obtener form metadata para mapear questions
            form = self.service.forms().get(formId=self.form_id).execute()
            question_mapping = self.create_question_mapping(form)
            
            # Obtener responses
            responses = self.service.forms().responses().list(formId=self.form_id).execute()
            
            return responses.get('responses', []), question_mapping
        
        except Exception as e:
            print(f"Error obteniendo respuestas: {e}")
            return [], {}
    
    def create_question_mapping(self, form):
        """Crear mapping de question IDs a nombres"""
        mapping = {}
        
        for item in form.get('items', []):
            if 'questionItem' in item:
                question_id = item['questionItem']['question']['questionId']
                title = item['title']
                mapping[question_id] = title
        
        return mapping
    
    def process_responses(self, responses, question_mapping):
        """Procesar respuestas para formato BigQuery"""
        processed_data = []
        
        for response in responses:
            try:
                # Extraer respuestas
                answers = response.get('answers', {})
                submit_time = datetime.fromisoformat(
                    response['lastSubmittedTime'].replace('Z', '+00:00')
                )
                
                # Mapear respuestas a campos conocidos
                processed_response = {
                    'satisfaction_id': f"SAT_{response['responseId']}",
                    'project_id': self.map_project_name_to_id(
                        self.get_answer_value(answers, 'Nombre del Proyecto', question_mapping)
                    ),
                    'client_name': self.get_answer_value(answers, 'Cliente', question_mapping),
                    'project_name': self.get_answer_value(answers, 'Nombre del Proyecto', question_mapping),
                    'satisfaction_stars': int(self.get_answer_value(
                        answers, 'Calificación General', question_mapping, default='0'
                    )),
                    'survey_date': submit_time.date(),
                    'quarter': self.get_quarter(submit_time),
                    'year': submit_time.year
                }
                
                processed_data.append(processed_response)
                
            except Exception as e:
                print(f"Error procesando respuesta {response.get('responseId', 'unknown')}: {e}")
                continue
        
        return processed_data
    
    def get_answer_value(self, answers, question_title, question_mapping, default=''):
        """Obtener valor de respuesta por título de pregunta"""
        # Encontrar question_id por título
        question_id = None
        for qid, title in question_mapping.items():
            if question_title.lower() in title.lower():
                question_id = qid
                break
        
        if not question_id or question_id not in answers:
            return default
        
        # Extraer valor según tipo de respuesta
        answer = answers[question_id]
        
        if 'textAnswers' in answer:
            return answer['textAnswers']['answers'][0]['value']
        elif 'scaleAnswer' in answer:
            return str(answer['scaleAnswer']['answer'])
        elif 'choiceAnswers' in answer:
            return answer['choiceAnswers']['answers'][0]['value']
        
        return default
    
    def map_project_name_to_id(self, project_name):
        """Mapear nombre de proyecto a project_id"""
        mapping = {
            'Atlantic City ML': 'PROJ001',
            'Etafashion Price Engine': 'PROJ002',
            'Chinalco Data Governance': 'PROJ003',
            # Agregar más mappings
        }
        
        for key, project_id in mapping.items():
            if key.lower() in project_name.lower():
                return project_id
        
        return 'PROJ_UNKNOWN'
    
    def get_quarter(self, date):
        """Obtener quarter de una fecha"""
        return (date.month - 1) // 3 + 1
    
    def upload_to_bigquery(self, processed_data):
        """Subir satisfaction data a BigQuery"""
        client = bigquery.Client()
        table_id = "jrodriguez-sandbox.hackathon_bonus_update.customer_satisfaction"
        
        df = pd.DataFrame(processed_data)
        
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_TRUNCATE",  # Reemplazar datos
            schema_update_options=[bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION]
        )
        
        job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
        job.result()
        
        print(f"Loaded {len(processed_data)} satisfaction responses to BigQuery")

# Uso del integrador
def sync_google_forms_monthly():
    """Función para ejecutar mensualmente"""
    integrator = GoogleFormsIntegration(
        'path/to/service-account.json',
        'your_form_id'
    )
    
    responses, question_mapping = integrator.get_form_responses()
    processed_data = integrator.process_responses(responses, question_mapping)
    integrator.upload_to_bigquery(processed_data)