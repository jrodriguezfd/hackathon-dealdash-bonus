import requests
from datetime import datetime, timedelta
import pandas as pd

class HubSpotIntegration:
    def __init__(self, access_token):
        self.access_token = access_token
        self.base_url = "https://api.hubapi.com/crm/v3"
        self.headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        }
    
    def get_closed_deals(self, start_date=None, end_date=None):
        """Obtener deals cerrados ganados"""
        url = f"{self.base_url}/objects/deals"
        
        params = {
            'properties': [
                'dealname', 'amount', 'closedate', 'dealstage',
                'hubspot_owner_id', 'deal_currency_code', 'createdate',
                'hs_deal_stage_probability', 'hs_analytics_source'
            ],
            'limit': 100
        }
        
        all_deals = []
        after_cursor = None
        
        while True:
            if after_cursor:
                params['after'] = after_cursor
                
            response = requests.get(url, headers=self.headers, params=params)
            data = response.json()
            
            # Filtrar solo deals cerrados ganados
            for deal in data['results']:
                if deal['properties']['dealstage'] == 'closedwon':
                    close_date = datetime.fromisoformat(
                        deal['properties']['closedate'].replace('Z', '+00:00')
                    )
                    
                    # Filtrar por fecha si se especifica
                    if start_date and close_date < start_date:
                        continue
                    if end_date and close_date > end_date:
                        continue
                        
                    all_deals.append(deal)
            
            # Pagination
            if 'paging' in data and 'next' in data['paging']:
                after_cursor = data['paging']['next']['after']
            else:
                break
        
        return all_deals
    
    def get_deal_collaborators(self, deal_id):
        """Obtener colaboradores de un deal específico"""
        # Esta información puede venir de custom properties o associations
        # Implementar según estructura específica de HubSpot
        url = f"{self.base_url}/objects/deals/{deal_id}"
        
        params = {
            'properties': ['hubspot_owner_id', 'deal_collaborators'],  # Custom property
            'associations': ['contacts']
        }
        
        response = requests.get(url, headers=self.headers, params=params)
        return response.json()
    
    def process_deals(self, deals):
        """Procesar deals para formato BigQuery"""
        processed_data = []
        
        for deal in deals:
            props = deal['properties']
            
            # Deal básico (owner)
            base_deal = {
                'deal_id': deal['id'],
                'consultant_id': self.map_owner_to_consultant(props['hubspot_owner_id']),
                'quarter': self.get_quarter_from_date(props['closedate']),
                'year': datetime.fromisoformat(props['closedate'].replace('Z', '+00:00')).year,
                'deal_name': props['dealname'],
                'deal_amount': float(props['amount']) if props['amount'] else 0,
                'close_date': datetime.fromisoformat(props['closedate'].replace('Z', '+00:00')).date(),
                'participation_type': 'Owner',
                'is_recurring_business': self.determine_if_recurring(props),
                'client_name': self.get_client_name(deal),
                'channel': self.map_source_to_channel(props.get('hs_analytics_source', '')),
                'deal_type': 'PS'  # Defaultear a PS, ajustar según negocio
            }
            processed_data.append(base_deal)
            
            # Agregar colaboradores si existen
            collaborators = self.get_deal_collaborators(deal['id'])
            for collab_id in self.extract_collaborators(collaborators):
                collab_deal = base_deal.copy()
                collab_deal['consultant_id'] = collab_id
                collab_deal['participation_type'] = 'Collaborator'
                processed_data.append(collab_deal)
        
        return processed_data
    
    def map_owner_to_consultant(self, hubspot_owner_id):
        """Mapear HubSpot owner ID a consultant_id"""
        mapping = {
            'rod_solar_id': 'CONS001',
            'jesus_id': 'CONS002',
            'anthony_id': 'CONS003',
            # Agregar más mappings
        }
        return mapping.get(hubspot_owner_id, 'UNKNOWN')
    
    def determine_if_recurring(self, properties):
        """Determinar si es negocio recurrente"""
        # Lógica para determinar recurring business
        # Puede basarse en:
        # - Tipo de deal
        # - Cliente existente
        # - Custom properties
        deal_name = properties.get('dealname', '').lower()
        recurring_keywords = ['renewal', 'subscription', 'recurring', 'maintenance']
        
        return any(keyword in deal_name for keyword in recurring_keywords)
    
    def get_client_name(self, deal):
        """Extraer nombre del cliente"""
        # Lógica para obtener cliente desde associations o properties
        # Implementar según estructura de HubSpot
        return "Client Name"  # Placeholder
    
    def upload_to_bigquery(self, processed_data):
        """Subir deals a BigQuery"""
        client = bigquery.Client()
        table_id = "jrodriguez-sandbox.hackathon_bonus_update.deals_report"
        
        df = pd.DataFrame(processed_data)
        
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_TRUNCATE",  # Reemplazar datos
            schema_update_options=[bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION]
        )
        
        job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
        job.result()
        
        print(f"Loaded {len(processed_data)} deals to BigQuery")

# Uso del integrador
def sync_hubspot_quarterly():
    """Función para ejecutar trimestralmente"""
    integrator = HubSpotIntegration('your_access_token')
    
    # Obtener deals del quarter actual
    now = datetime.now()
    quarter_start = datetime(now.year, ((now.month - 1) // 3) * 3 + 1, 1)
    
    deals = integrator.get_closed_deals(start_date=quarter_start)
    processed_data = integrator.process_deals(deals)
    integrator.upload_to_bigquery(processed_data)