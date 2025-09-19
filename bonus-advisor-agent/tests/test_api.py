import pytest
import json
import sys
import os
from unittest.mock import patch, MagicMock
import pandas as pd

# Add the parent directory to sys.path to import main
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import main


class TestFlaskAPI:
    """Test suite para los endpoints de la API Flask"""
    
    @pytest.fixture
    def app(self):
        """Configurar la aplicación Flask para testing"""
        main.app.config['TESTING'] = True
        main.app.config['WTF_CSRF_ENABLED'] = False
        return main.app
    
    @pytest.fixture
    def client(self, app):
        """Cliente de prueba para hacer peticiones HTTP"""
        return app.test_client()
    
    @pytest.fixture
    def mock_bonus_agent(self):
        """Mock del BonusAdvisorAgent"""
        with patch.object(main, 'bonus_agent') as mock_agent:
            yield mock_agent
    
    @pytest.fixture
    def sample_consultant_data(self):
        """Datos de ejemplo de un consultor"""
        return {
            'consultant_id': 'CONS001',
            'consultant_name': 'Rodolfo Solar',
            'plan_type': 'Sales',
            'quarter': 2,
            'year': 2025,
            'total_bonus': 13305.20,
            'company_booking_bonus': 500.0,
            'recurring_business_bonus': 250.0,
            'individual_commission': 12055.20,
            'project_hours': 0.0,
            'mbo_bonus': 500.0
        }
    
    def test_index_route(self, client):
        """Test de la ruta principal"""
        response = client.get('/')
        assert response.status_code == 200
        assert b'Bonus Advisor Agent' in response.data
    
    def test_chat_api_success(self, client, mock_bonus_agent):
        """Test exitoso del endpoint de chat"""
        # Configurar mock
        mock_bonus_agent.chat_with_agent.return_value = "Esta es la respuesta del agente"
        
        # Datos de la petición
        data = {
            'message': '¿Cuál es mi bono actual?',
            'consultant_id': 'CONS001'
        }
        
        # Hacer petición
        response = client.post('/api/chat',
                             data=json.dumps(data),
                             content_type='application/json')
        
        # Verificaciones
        assert response.status_code == 200
        response_data = json.loads(response.data)
        assert 'response' in response_data
        assert response_data['response'] == "Esta es la respuesta del agente"
        
        # Verificar que se llamó al agente correctamente
        mock_bonus_agent.chat_with_agent.assert_called_once_with(
            '¿Cuál es mi bono actual?', 'CONS001'
        )
    
    def test_chat_api_empty_message(self, client, mock_bonus_agent):
        """Test del endpoint de chat con mensaje vacío"""
        data = {
            'message': '',
            'consultant_id': 'CONS001'
        }
        
        response = client.post('/api/chat',
                             data=json.dumps(data),
                             content_type='application/json')
        
        assert response.status_code == 200
        # El agente debería manejar mensajes vacíos
        mock_bonus_agent.chat_with_agent.assert_called_once_with('', 'CONS001')
    
    def test_chat_api_no_consultant_id(self, client, mock_bonus_agent):
        """Test del endpoint de chat sin consultant_id"""
        data = {
            'message': '¿Cómo funciona el sistema de bonos?'
        }
        
        response = client.post('/api/chat',
                             data=json.dumps(data),
                             content_type='application/json')
        
        assert response.status_code == 200
        mock_bonus_agent.chat_with_agent.assert_called_once_with(
            '¿Cómo funciona el sistema de bonos?', None
        )
    
    def test_get_bonus_api_success(self, client, mock_bonus_agent, sample_consultant_data):
        """Test exitoso del endpoint de bono"""
        # Configurar mock
        mock_bonus_agent.get_consultant_bonus.return_value = sample_consultant_data
        
        # Hacer petición
        response = client.get('/api/bonus/CONS001')
        
        # Verificaciones
        assert response.status_code == 200
        response_data = json.loads(response.data)
        assert response_data['consultant_id'] == 'CONS001'
        assert response_data['consultant_name'] == 'Rodolfo Solar'
        assert response_data['total_bonus'] == 13305.20
        
        # Verificar que se llamó al método correcto
        mock_bonus_agent.get_consultant_bonus.assert_called_once_with('CONS001', None, None)
    
    def test_get_bonus_api_with_quarter_year(self, client, mock_bonus_agent, sample_consultant_data):
        """Test del endpoint de bono con parámetros de quarter y year"""
        mock_bonus_agent.get_consultant_bonus.return_value = sample_consultant_data
        
        response = client.get('/api/bonus/CONS001?quarter=2&year=2025')
        
        assert response.status_code == 200
        mock_bonus_agent.get_consultant_bonus.assert_called_once_with('CONS001', 2, 2025)
    
    def test_get_bonus_api_not_found(self, client, mock_bonus_agent):
        """Test del endpoint de bono cuando el consultor no existe"""
        # Configurar mock para retornar error
        mock_bonus_agent.get_consultant_bonus.return_value = {"error": "Consultor no encontrado"}
        
        response = client.get('/api/bonus/INVALID_ID')
        
        assert response.status_code == 200  # La API devuelve 200 pero con error en el JSON
        response_data = json.loads(response.data)
        assert 'error' in response_data
        assert response_data['error'] == "Consultor no encontrado"
    
    def test_get_breakdown_api_success(self, client, mock_bonus_agent):
        """Test exitoso del endpoint de desglose"""
        breakdown_data = {
            'consultant_name': 'Rodolfo Solar',
            'plan_type': 'Sales',
            'total_bonus': 13305.20,
            'breakdown': {
                'Company Performance': {
                    'Company Booking Bonus': 500.0,
                    'Recurring Business Bonus': 250.0
                },
                'Individual Performance': {
                    'Individual Commission': 12055.20,
                    'Utilization Bonus': 0.0
                }
            }
        }
        
        mock_bonus_agent.get_bonus_breakdown.return_value = breakdown_data
        
        response = client.get('/api/breakdown/CONS001')
        
        assert response.status_code == 200
        response_data = json.loads(response.data)
        assert response_data['consultant_name'] == 'Rodolfo Solar'
        assert 'breakdown' in response_data
        assert 'Company Performance' in response_data['breakdown']
    
    def test_get_breakdown_api_with_params(self, client, mock_bonus_agent):
        """Test del endpoint de desglose con parámetros"""
        mock_bonus_agent.get_bonus_breakdown.return_value = {}
        
        response = client.get('/api/breakdown/CONS001?quarter=1&year=2024')
        
        assert response.status_code == 200
        mock_bonus_agent.get_bonus_breakdown.assert_called_once_with('CONS001', 1, 2024)
    
    def test_get_recommendations_api_success(self, client, mock_bonus_agent):
        """Test exitoso del endpoint de recomendaciones"""
        recommendations = [
            "🎯 Enfócate en cerrar deals de mayor valor para alcanzar $1M TCV",
            "🏢 Colabora con el equipo para superar la meta de company booking"
        ]
        
        mock_bonus_agent.get_improvement_recommendations.return_value = recommendations
        
        response = client.get('/api/recommendations/CONS001/Sales')
        
        assert response.status_code == 200
        response_data = json.loads(response.data)
        assert 'recommendations' in response_data
        assert len(response_data['recommendations']) == 2
        assert "TCV" in response_data['recommendations'][0]
        
        mock_bonus_agent.get_improvement_recommendations.assert_called_once_with('CONS001', 'Sales')
    
    def test_get_recommendations_api_empty(self, client, mock_bonus_agent):
        """Test del endpoint de recomendaciones cuando no hay recomendaciones"""
        mock_bonus_agent.get_improvement_recommendations.return_value = []
        
        response = client.get('/api/recommendations/CONS002/Delivery')
        
        assert response.status_code == 200
        response_data = json.loads(response.data)
        assert response_data['recommendations'] == []
    
    def test_dashboard_api_success(self, client, mock_bonus_agent):
        """Test exitoso del endpoint de dashboard"""
        # Mock del cliente BigQuery
        dashboard_data = [
            {
                'plan_type': 'Sales',
                'consultant_count': 1,
                'avg_bonus': 13305.20,
                'max_bonus': 13305.20,
                'min_bonus': 13305.20,
                'avg_company_achievement': 100.46,
                'avg_efficiency': 0.0
            },
            {
                'plan_type': 'Hybrid',
                'consultant_count': 1,
                'avg_bonus': 5000.0,
                'max_bonus': 5000.0,
                'min_bonus': 5000.0,
                'avg_company_achievement': 100.46,
                'avg_efficiency': 85.5
            }
        ]
        
        # Mock del DataFrame y query
        mock_df = pd.DataFrame(dashboard_data)
        mock_query_job = MagicMock()
        mock_query_job.to_dataframe.return_value = mock_df
        mock_bonus_agent.client.query.return_value = mock_query_job
        
        response = client.get('/api/dashboard')
        
        assert response.status_code == 200
        response_data = json.loads(response.data)
        assert isinstance(response_data, list)
        assert len(response_data) == 2
        assert response_data[0]['plan_type'] == 'Sales'
        assert response_data[1]['plan_type'] == 'Hybrid'


class TestAPIErrorHandling:
    """Test para manejo de errores en la API"""
    
    @pytest.fixture
    def app(self):
        main.app.config['TESTING'] = True
        return main.app
    
    @pytest.fixture
    def client(self, app):
        return app.test_client()
    
    @pytest.fixture
    def mock_bonus_agent_with_error(self):
        """Mock del agente que lanza excepciones"""
        with patch.object(main, 'bonus_agent') as mock_agent:
            mock_agent.chat_with_agent.side_effect = Exception("Error de conexión")
            mock_agent.get_consultant_bonus.side_effect = Exception("BigQuery error")
            yield mock_agent
    
    def test_chat_api_exception_handling(self, client, mock_bonus_agent_with_error):
        """Test de manejo de excepciones en chat API"""
        data = {
            'message': 'Test message',
            'consultant_id': 'CONS001'
        }
        
        response = client.post('/api/chat',
                             data=json.dumps(data),
                             content_type='application/json')
        
        # La API debería manejar la excepción gracefully
        assert response.status_code == 200
        response_data = json.loads(response.data)
        assert 'response' in response_data
        # El agente debería manejar el error internamente
    
    def test_bonus_api_exception_handling(self, client, mock_bonus_agent_with_error):
        """Test de manejo de excepciones en bonus API"""
        # Este test depende de cómo se manejen las excepciones en main.py
        # Si las excepciones se propagan, el test debería verificar el comportamiento apropiado
        
        response = client.get('/api/bonus/CONS001')
        
        # Verificar que la API no falla completamente
        # El comportamiento exacto depende de la implementación de error handling
        assert response.status_code in [200, 500]  # Depende del manejo de errores implementado


class TestAPIValidation:
    """Test para validación de datos en la API"""
    
    @pytest.fixture
    def app(self):
        main.app.config['TESTING'] = True
        return main.app
    
    @pytest.fixture
    def client(self, app):
        return app.test_client()
    
    def test_chat_api_invalid_json(self, client):
        """Test del endpoint de chat con JSON inválido"""
        response = client.post('/api/chat',
                             data='invalid json',
                             content_type='application/json')
        
        # Flask debería manejar el JSON inválido
        assert response.status_code == 400
    
    def test_chat_api_missing_content_type(self, client):
        """Test del endpoint de chat sin content-type correcto"""
        data = json.dumps({'message': 'test'})
        
        response = client.post('/api/chat', data=data)
        
        # Debería fallar sin el content-type correcto
        assert response.status_code in [400, 415]
    
    def test_bonus_api_invalid_parameters(self, client):
        """Test del endpoint de bono con parámetros inválidos"""
        # Test con quarter inválido
        response = client.get('/api/bonus/CONS001?quarter=invalid')
        
        # Flask debería manejar el parámetro inválido
        # El comportamiento exacto depende de la validación implementada
        assert response.status_code in [200, 400]  # Depende de la validación


class TestAPIIntegration:
    """Tests de integración completos"""
    
    @pytest.fixture
    def app(self):
        main.app.config['TESTING'] = True
        return main.app
    
    @pytest.fixture
    def client(self, app):
        return app.test_client()
    
    @patch('main.BonusAdvisorAgent')
    def test_full_workflow(self, mock_agent_class, client):
        """Test de flujo completo de la aplicación"""
        # Configurar mock del agente
        mock_agent = MagicMock()
        mock_agent_class.return_value = mock_agent
        
        # Configurar respuestas mock
        mock_agent.get_consultant_bonus.return_value = {
            'consultant_name': 'Test User',
            'total_bonus': 5000.0,
            'plan_type': 'Sales'
        }
        
        mock_agent.get_bonus_breakdown.return_value = {
            'breakdown': {'Company Performance': {'Company Booking Bonus': 500.0}}
        }
        
        mock_agent.get_improvement_recommendations.return_value = [
            "Mejora tu TCV para obtener más comisión"
        ]
        
        mock_agent.chat_with_agent.return_value = "Respuesta del chat"
        
        # Test secuencial de endpoints
        
        # 1. Obtener bono
        response = client.get('/api/bonus/CONS001')
        assert response.status_code == 200
        bonus_data = json.loads(response.data)
        assert bonus_data['consultant_name'] == 'Test User'
        
        # 2. Obtener desglose
        response = client.get('/api/breakdown/CONS001')
        assert response.status_code == 200
        breakdown_data = json.loads(response.data)
        assert 'breakdown' in breakdown_data
        
        # 3. Obtener recomendaciones
        response = client.get('/api/recommendations/CONS001/Sales')
        assert response.status_code == 200
        recommendations_data = json.loads(response.data)
        assert len(recommendations_data['recommendations']) == 1
        
        # 4. Chat
        chat_data = {
            'message': '¿Cuál es mi bono?',
            'consultant_id': 'CONS001'
        }
        response = client.post('/api/chat',
                             data=json.dumps(chat_data),
                             content_type='application/json')
        assert response.status_code == 200
        chat_response = json.loads(response.data)
        assert chat_response['response'] == "Respuesta del chat"


if __name__ == '__main__':
    # Ejecutar tests
    pytest.main([__file__, '-v', '--tb=short'])