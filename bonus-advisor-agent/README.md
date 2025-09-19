# Bonus Advisor Agent 🤖

Un agente inteligente basado en Google Agent Development Kit con Gemini-2.5-flash para consultas sobre el sistema de bonos de consultores. Permite a los usuarios obtener información detallada sobre sus bonos, recomendaciones personalizadas y análisis de rendimiento.

## 🎯 Características Principales

- **Chat Inteligente**: Consultas en lenguaje natural usando Gemini-2.5-flash
- **Análisis de Bonos**: Desglose detallado de los 7 KPIs del sistema de bonos
- **Recomendaciones IA**: Sugerencias específicas por tipo de plan (Sales/Hybrid/Delivery)
- **Dashboard Interactivo**: Visualizaciones en tiempo real con métricas de rendimiento
- **Integración BigQuery**: Acceso directo a datos actualizados de bonos
- **API RESTful**: Endpoints para integración con otras aplicaciones

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌───────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Flask API       │    │   BigQuery      │
│   (Bootstrap)   │◄──►│   (Python)        │◄──►│   (Data)        │
└─────────────────┘    └───────────────────┘    └─────────────────┘
                                │
                       ┌───────────────────┐
                       │   Vertex AI       │
                       │   (Gemini-2.5)    │
                       └───────────────────┘
```

## 📋 Requisitos Previos

- **Google Cloud Project**: `jrodriguez-sandbox`
- **Python**: 3.11 or superior
- **APIs Habilitadas**:
  - Vertex AI API
  - BigQuery API
  - Cloud Run API
  - Cloud Build API

## 🚀 Instalación Rápida

### 1. Clonar y Configurar

```bash
git clone <your-repo-url>
cd bonus-advisor-agent

# Configurar permisos automáticamente
chmod +x setup-permissions.sh
./setup-permissions.sh
```

### 2. Instalar Dependencias

```bash
pip install -r requirements.txt
```

### 3. Configurar Variables de Entorno

El script `setup-permissions.sh` genera automáticamente el archivo `.env`. Verifica que contenga:

```bash
PROJECT_ID=jrodriguez-sandbox
REGION=us-central1
BIGQUERY_DATASET=hackathon_bonus_update
BIGQUERY_TABLE=quarterly_bonus_results
SECRET_KEY=<generated-key>
```

### 4. Ejecutar Localmente

```bash
python main.py
```

Accede a: http://localhost:8080

## ☁️ Despliegue en Cloud Run

### Opción 1: Despliegue Automático

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

### Opción 2: Comando Manual

```bash
gcloud run deploy bonus-advisor-agent \
    --source . \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --service-account bonus-agent-sa@jrodriguez-sandbox.iam.gserviceaccount.com \
    --memory 2Gi \
    --cpu 1
```

## 🎮 Uso del Agente

### Chat Interactivo

El agente puede responder preguntas como:

- _"¿Cuál es mi bono actual y cómo se calculó?"_
- _"¿Qué necesito para alcanzar el máximo bono?"_
- _"Explícame el TCV Individual"_
- _"¿Cómo me comparo con otros consultores?"_
- _"¿Cuáles son las métricas más importantes para mi plan?"_

### API Endpoints

| Endpoint                                           | Método | Descripción                      |
| -------------------------------------------------- | ------ | -------------------------------- |
| `/api/chat`                                        | POST   | Chat con el agente               |
| `/api/bonus/<consultant_id>`                       | GET    | Datos de bono del consultor      |
| `/api/breakdown/<consultant_id>`                   | GET    | Desglose detallado del bono      |
| `/api/recommendations/<consultant_id>/<plan_type>` | GET    | Recomendaciones personalizadas   |
| `/api/dashboard`                                   | GET    | Métricas generales del dashboard |

### Ejemplo de Uso API

```python
import requests

# Obtener bono actual
response = requests.get('https://your-app-url/api/bonus/CONS001?quarter=2&year=2025')
bonus_data = response.json()

# Chat con el agente
chat_response = requests.post('https://your-app-url/api/chat',
    json={
        'message': '¿Cuál es mi bono actual?',
        'consultant_id': 'CONS001'
    }
)
```

## 📊 Sistema de KPIs

El agente maneja 7 KPIs principales:

### 🏢 Company Performance

1. **Company Booking Target**: Meta trimestral de $600K
2. **Recurring Business**: Objetivo del 20% de negocios recurrentes

### 💰 Individual Performance

3. **Total Contract Value (TCV)**: Comisiones por deals cerrados
4. **Individual Utilization Value (IUV)**: Horas trabajadas en proyectos
5. **Efficiency Percentage**: % de horas dedicadas a proyectos facturables
6. **Timeline Adherence**: % de proyectos completados a tiempo

### 🌟 Global Performance

7. **Net Promoter Score (NPS)**: Satisfacción promedio del cliente

## 🧪 Testing

```bash
# Ejecutar todos los tests
pytest tests/ -v

# Tests específicos
pytest tests/test_agent.py -v
pytest tests/test_api.py -v

# Con coverage
pytest tests/ --cov=main --cov-report=html
```

## 🔧 Configuración Avanzada

### Variables de Entorno Adicionales

```bash
# Logging
LOG_LEVEL=INFO
GOOGLE_CLOUD_LOGGING=true

# Vertex AI
GEMINI_MODEL=gemini-2.0-flash-exp
VERTEX_AI_LOCATION=us-central1

# Flask
FLASK_ENV=production
FLASK_DEBUG=false
```

### Personalización del Agente

Edita `main.py` para:

- Agregar nuevos KPIs en `kpi_definitions`
- Modificar lógica de recomendaciones
- Añadir nuevas funciones del agente
- Personalizar respuestas del chat

## 📈 Monitoreo

### Logs en Cloud Run

```bash
# Ver logs en tiempo real
gcloud run services logs tail bonus-advisor-agent --region us-central1

# Logs por fecha
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=bonus-advisor-agent" --limit=50
```

### Métricas

- **Latencia**: Tiempo de respuesta de las consultas
- **Errores**: Rate de errores en APIs
- **Uso**: Número de consultas por consultor
- **Performance**: Tiempo de respuesta de BigQuery

## 🔒 Seguridad

### Permisos Mínimos

El service account tiene solo los permisos necesarios:

- `bigquery.dataViewer`: Leer datos de bonos
- `bigquery.jobUser`: Ejecutar queries
- `aiplatform.user`: Usar Vertex AI
- `run.invoker`: Acceso a Cloud Run

### Datos Sensibles

- ✅ Variables de entorno para configuración
- ✅ Service account key no se incluye en el código
- ✅ HTTPS obligatorio en producción
- ✅ Logs no contienen información personal

## 🐛 Troubleshooting

### Errores Comunes

| Error                    | Solución                                           |
| ------------------------ | -------------------------------------------------- |
| `Permission denied`      | Ejecutar `./setup-permissions.sh`                  |
| `BigQuery access denied` | Verificar dataset y tabla existen                  |
| `Vertex AI not enabled`  | `gcloud services enable aiplatform.googleapis.com` |
| `Import error`           | `pip install -r requirements.txt`                  |

### Debug Local

```bash
export FLASK_DEBUG=true
export LOG_LEVEL=DEBUG
python main.py
```

## 🔄 CI/CD

### GitHub Actions (Opcional)

```yaml
# .github/workflows/deploy.yml
name: Deploy to Cloud Run
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: google-github-actions/setup-gcloud@v0
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          project_id: jrodriguez-sandbox
      - run: gcloud run deploy --source .
```

## 📚 Estructura del Proyecto

```
bonus-advisor-agent/
├── main.py                    # Aplicación principal
├── requirements.txt           # Dependencias Python
├── Dockerfile                # Configuración Docker
├── cloud-run.yaml            # Config Cloud Run
├── setup-permissions.sh      # Script de configuración
├── .env                      # Variables de entorno
├── .gitignore               # Archivos ignorados
├── README.md                # Este archivo
├── templates/
│   └── index.html           # Interfaz web
├── config/
│   └── service-account-key.json  # Credenciales (no en git)
├── tests/
│   ├── test_agent.py        # Tests del agente
│   └── test_api.py          # Tests de la API
└── scripts/
    └── deploy.sh            # Script de despliegue
```

## 🤝 Contribución

1. Fork el repositorio
2. Crear branch para feature: `git checkout -b feature/nueva-funcionalidad`
3. Hacer commit: `git commit -am 'Agregar nueva funcionalidad'`
4. Push al branch: `git push origin feature/nueva-funcionalidad`
5. Crear Pull Request

### Standards

- Usar Black para formateo: `black main.py tests/`
- Ejecutar tests antes de PR: `pytest tests/ -v`
- Documentar nuevas funciones
- Actualizar README si es necesario

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 🆘 Soporte

- **Issues**: Reportar bugs en GitHub Issues
- **Documentación**: Ver comentarios en el código
- **Email**: Para soporte interno del proyecto
- **Slack**: Canal #bonus-advisor-agent

## 🔮 Roadmap

### V1.1 (Próxima versión)

- [ ] Notificaciones por email/Slack
- [ ] Dashboard con más visualizaciones
- [ ] Exportar reportes a PDF
- [ ] Cache con Redis para mejor performance

### V1.2

- [ ] Integración con más fuentes de datos
- [ ] Machine Learning para predicciones
- [ ] API GraphQL
- [ ] Aplicación móvil

### V2.0

- [ ] Multi-tenant support
- [ ] Advanced analytics
- [ ] Custom KPI builder
- [ ] Workflow automation

## 📊 Datos de Ejemplo

El sistema incluye datos de ejemplo para los siguientes consultores:

| ID      | Nombre           | Plan     | Especialidad           |
| ------- | ---------------- | -------- | ---------------------- |
| CONS001 | Rodolfo Solar    | Sales    | Ventas y estrategia    |
| CONS002 | Anthony Alarcon  | Delivery | Implementación técnica |
| CONS003 | Julian Rodriguez | Hybrid   | Ventas y delivery      |

## 🎯 Métricas de Éxito

- **Adopción**: 100% de consultores usando el sistema
- **Satisfacción**: NPS > 8 en encuestas de usuario
- **Performance**: < 2s tiempo de respuesta promedio
- **Disponibilidad**: 99.9% uptime en producción

---

Desarrollado con ❤️ usando Google Agent Development Kit y Gemini-2.5-flash
