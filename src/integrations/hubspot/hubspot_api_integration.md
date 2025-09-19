# Integración con HubSpot API

## Descripción
Esta integración permite extraer información de deals cerrados de HubSpot y cargarlos en la tabla `deals_report` de BigQuery para su análisis y generación de reportes.

## Configuración Requerida

### Credenciales
- **Access Token**: Token de acceso de API de HubSpot con los siguientes permisos:
  - `crm.objects.deals.read`
  - `crm.objects.companies.read`
  - `crm.objects.contacts.read`

### Variables de Entorno
```
HUBSPOT_ACCESS_TOKEN=tu_token_de_acceso_aquí
```

## Uso (rápido)
```python
from hubspot_api_integration import sync_hubspot_quarterly

# Ejecuta la sincronización trimestral y carga en BigQuery
sync_hubspot_quarterly()
```

## Estructura de Datos

### Campos Mapeados a BigQuery
- `deal_id`: ID único del deal en HubSpot
- `deal_name`: Nombre del deal
- `amount`: Monto del deal (en la moneda especificada)
- `currency_code`: Código de moneda (ej: USD, EUR)
- `close_date`: Fecha de cierre del deal
- `create_date`: Fecha de creación del deal
- `deal_stage`: Etapa del deal (siempre 'closedwon')
- `probability`: Probabilidad de cierre (1 para cerrados ganados)
- `owner_id`: ID del propietario del deal
- `company_id`: ID de la compañía asociada (si existe)
- `source`: Fuente de análisis (ej: ORGANIC_SEARCH)
- `created_at`: Fecha de creación del registro
- `updated_at`: Fecha de última actualización

## Requisitos
- Python 3.8+
- Bibliotecas: requests, pandas, google-cloud-bigquery

