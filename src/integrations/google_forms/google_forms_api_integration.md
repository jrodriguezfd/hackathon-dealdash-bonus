# Integración con Google Forms API
@@
## Descripción
Esta integración permite extraer respuestas de encuestas de satisfacción de clientes de Google Forms y cargarlas en la tabla `customer_satisfaction` de BigQuery para su análisis posterior.

## Acceso y credenciales
- Archivo JSON de Service Account con permiso de lectura de respuestas de Forms.
- ID del formulario (`form_id`) compartido con la Service Account.

## Uso (rápido)
```python
from google_forms_api_integration import sync_google_forms_monthly

# Ejecuta la sincronización mensual y carga en BigQuery
sync_google_forms_monthly()
```

## Estructura de Datos en BigQuery

### Tabla: customer_satisfaction
- `response_id`: ID único de la respuesta
- `project_name`: Nombre del proyecto
- `client`: Nombre del cliente
- `rating`: Calificación (1-5)
## Requisitos
- Python 3.8+
- Bibliotecas: google-auth, google-api-python-client, pandas, google-cloud-bigquery