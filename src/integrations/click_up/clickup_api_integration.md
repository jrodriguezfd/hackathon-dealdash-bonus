# Integración con ClickUp API

## Descripción
Esta integración permite extraer datos de seguimiento de tiempo de ClickUp y cargarlos en la tabla `consultant_report` de BigQuery para su posterior análisis.

## Configuración Requerida

### Credenciales
- **API Token**: Se requiere un token de acceso personal de ClickUp con permisos de lectura.
- **Team ID**: Identificador del equipo de ClickUp del cual se extraerán los datos.

### Variables de Entorno
```
CLICKUP_API_TOKEN=tu_token_de_api_aquí
CLICKUP_TEAM_ID=tu_team_id_aquí
```

## Uso (rápido)
```python
from clickup_api_integration import sync_clickup_weekly

# Ejecuta la sincronización semanal y carga en BigQuery
sync_clickup_weekly()
```

## Estructura de Datos

### Campos Mapeados a BigQuery
- `report_id`: ID único del reporte (formato: CLK_{timer_id})
- `consultant_id`: ID del consultor (mapeado desde el email)
- `project_id`: ID del proyecto (extraído de la tarea)
- `week_start_date`: Fecha de inicio de la semana laboral
- `hours`: Horas trabajadas (convertidas de milisegundos)
- `description`: Descripción de la actividad
- `created_at`: Fecha de creación del registro
- `updated_at`: Fecha de última actualización

## Requisitos
- Python 3.8+
- Bibliotecas: requests, pandas, google-cloud-bigquery
