#!/bin/bash

# Script para configurar permisos del Bonus Advisor Agent
# VERSIÓN CORREGIDA
set -e

PROJECT_ID="jrodriguez-sandbox"
SERVICE_ACCOUNT_NAME="bonus-agent-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
REGION="us-central1"

echo "🚀 Configurando permisos para Bonus Advisor Agent..."
echo "📋 Proyecto: ${PROJECT_ID}"
echo "🔐 Service Account: ${SERVICE_ACCOUNT_EMAIL}"

# Verificar que gcloud esté configurado correctamente
echo "🔍 Verificando configuración de gcloud..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "❌ Error: No hay cuenta activa en gcloud"
    echo "Ejecuta: gcloud auth login"
    exit 1
fi

CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo "⚠️  Configurando proyecto correcto..."
    gcloud config set project $PROJECT_ID
fi

echo "✅ Proyecto configurado: $(gcloud config get-value project)"

# Habilitar APIs necesarias
echo "🔌 Habilitando APIs necesarias..."
gcloud services enable cloudbuild.googleapis.com --quiet
gcloud services enable run.googleapis.com --quiet
gcloud services enable aiplatform.googleapis.com --quiet
gcloud services enable bigquery.googleapis.com --quiet
gcloud services enable logging.googleapis.com --quiet
gcloud services enable iam.googleapis.com --quiet
echo "✅ APIs habilitadas"

# Crear service account (FORZAR CREACIÓN)
echo "👤 Creando service account..."
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL >/dev/null 2>&1; then
    echo "⚠️  Service account ya existe: $SERVICE_ACCOUNT_EMAIL"
    read -p "¿Deseas recrearlo? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Eliminando service account existente..."
        gcloud iam service-accounts delete $SERVICE_ACCOUNT_EMAIL --quiet
        echo "➕ Creando service account nuevo..."
        gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
            --description="Service account for Bonus Advisor Agent" \
            --display-name="Bonus Agent SA" \
            --quiet
    fi
else
    echo "➕ Creando service account..."
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --description="Service account for Bonus Advisor Agent" \
        --display-name="Bonus Agent SA" \
        --quiet
fi

echo "✅ Service account listo: $SERVICE_ACCOUNT_EMAIL"

# Verificar que el service account fue creado
echo "🔍 Verificando service account..."
if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL >/dev/null 2>&1; then
    echo "❌ Error: Service account no se pudo crear"
    exit 1
fi

# Asignar roles necesarios
echo "🔑 Asignando roles..."

ROLES=(
    "roles/bigquery.dataViewer"
    "roles/bigquery.jobUser"
    "roles/aiplatform.user"
    "roles/run.invoker"
    "roles/logging.logWriter"
    "roles/monitoring.metricWriter"
)

for role in "${ROLES[@]}"; do
    echo "   Asignando rol: $role"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role" \
        --quiet
    
    # Verificar que el rol se asignó
    if gcloud projects get-iam-policy $PROJECT_ID \
        --flatten="bindings[].members" \
        --format='table(bindings.role)' \
        --filter="bindings.members:$SERVICE_ACCOUNT_EMAIL AND bindings.role:$role" | grep -q "$role"; then
        echo "   ✅ Rol asignado: $role"
    else
        echo "   ⚠️  Rol puede tardar en propagarse: $role"
    fi
done

echo "✅ Todos los roles asignados"

# Crear clave de service account (FORZAR CREACIÓN)
KEY_FILE="config/service-account-key.json"
echo "🔐 Generando clave de service account..."

# Crear directorio si no existe
mkdir -p config

# Eliminar clave existente si hay una
if [ -f "$KEY_FILE" ]; then
    echo "⚠️  Eliminando clave existente..."
    rm -f "$KEY_FILE"
fi

# Generar nueva clave
echo "🔑 Creando nueva clave..."
if gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SERVICE_ACCOUNT_EMAIL \
    --quiet; then
    echo "✅ Clave generada exitosamente: $KEY_FILE"
else
    echo "❌ Error al generar la clave"
    exit 1
fi

# Verificar que el archivo se creó
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Error: Archivo de clave no se creó"
    exit 1
fi

echo "✅ Clave verificada: $(ls -la $KEY_FILE)"

# Verificar permisos en BigQuery
echo "🔍 Verificando acceso a BigQuery..."
DATASET="hackathon_bonus_update"
TABLE="quarterly_bonus_results"

# Usar la clave recién creada para la verificación
export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"

if bq ls $PROJECT_ID:$DATASET >/dev/null 2>&1; then
    echo "✅ Acceso a dataset verificado: $DATASET"
    
    if bq show $PROJECT_ID:$DATASET.$TABLE >/dev/null 2>&1; then
        echo "✅ Acceso a tabla verificado: $TABLE"
    else
        echo "⚠️  Tabla no encontrada: $TABLE"
        echo "   Verifica que existe: $PROJECT_ID.$DATASET.$TABLE"
    fi
else
    echo "⚠️  No se puede acceder al dataset: $DATASET"
    echo "   Los permisos pueden tardar unos minutos en propagarse"
fi

# Generar SECRET_KEY para Flask
echo "🔐 Generando SECRET_KEY..."
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))' 2>/dev/null || openssl rand -base64 32)

# Configurar variables de entorno
echo "📝 Generando archivo .env..."
ENV_FILE=".env"

cat > $ENV_FILE << EOF
# Configuración del proyecto
PROJECT_ID=$PROJECT_ID
REGION=$REGION

# BigQuery
BIGQUERY_DATASET=$DATASET
BIGQUERY_TABLE=$TABLE

# Vertex AI
VERTEX_AI_LOCATION=$REGION
GEMINI_MODEL=gemini-2.0-flash-exp

# Credenciales (para desarrollo local)
GOOGLE_APPLICATION_CREDENTIALS=$KEY_FILE

# Flask
FLASK_ENV=production
SECRET_KEY=$SECRET_KEY

# Logging
LOG_LEVEL=INFO
EOF

echo "✅ Archivo .env creado"

# Configurar .gitignore si no existe
GITIGNORE_FILE=".gitignore"
if [ ! -f "$GITIGNORE_FILE" ]; then
    echo "📝 Creando .gitignore..."
    cat > $GITIGNORE_FILE << 'EOF'
# Environment files
.env
.env.*

# Google Cloud credentials
config/service-account-key.json
*.json

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Testing
.pytest_cache/
.coverage
htmlcov/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
    echo "✅ .gitignore creado"
fi

# Resumen final con verificaciones
echo ""
echo "🎉 ¡Configuración completada!"
echo ""
echo "📋 Verificación final:"

# Verificar service account
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL >/dev/null 2>&1; then
    echo "   ✅ Service account: $SERVICE_ACCOUNT_EMAIL"
else
    echo "   ❌ Service account: FALLO"
fi

# Verificar clave
if [ -f "$KEY_FILE" ]; then
    echo "   ✅ Clave de servicio: $KEY_FILE ($(stat -c%s "$KEY_FILE") bytes)"
else
    echo "   ❌ Clave de servicio: NO ENCONTRADA"
fi

# Verificar .env
if [ -f "$ENV_FILE" ]; then
    echo "   ✅ Variables de entorno: $ENV_FILE"
else
    echo "   ❌ Variables de entorno: NO ENCONTRADAS"
fi

echo ""
echo "🚀 Próximos pasos:"
echo "   1. Verificar archivos generados:"
echo "      ls -la config/service-account-key.json"
echo "      ls -la .env"
echo "   2. Instalar dependencias: pip install -r requirements.txt"
echo "   3. Probar localmente: python main.py"
echo "   4. Desplegar: ./scripts/deploy.sh"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - El archivo config/service-account-key.json contiene credenciales sensibles"
echo "   - Nunca lo subas a un repositorio público"
echo "   - Ya está incluido en .gitignore"

# Test final opcional
read -p "¿Deseas probar la autenticación ahora? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧪 Probando autenticación..."
    if gcloud auth activate-service-account --key-file="$KEY_FILE" --quiet; then
        echo "✅ Autenticación exitosa"
        # Volver a la cuenta original
        gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 | xargs gcloud config set account
    else
        echo "❌ Error en autenticación"
    fi
fi