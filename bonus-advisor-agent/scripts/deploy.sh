#!/bin/bash
set -e

echo "🚀 Iniciando despliegue del Bonus Advisor Agent..."

# Verificar que estamos en el proyecto correcto
CURRENT_PROJECT=$(gcloud config get-value project)
if [ "$CURRENT_PROJECT" != "jrodriguez-sandbox" ]; then
    echo "❌ Error: Proyecto actual es $CURRENT_PROJECT, debe ser jrodriguez-sandbox"
    exit 1
fi

echo "✅ Proyecto verificado: $CURRENT_PROJECT"

# Construir y desplegar
echo "🔨 Construyendo aplicación..."
gcloud run deploy bonus-advisor-agent \
    --source . \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --service-account bonus-agent-sa@jrodriguez-sandbox.iam.gserviceaccount.com \
    --memory 2Gi \
    --cpu 1 \
    --min-instances 1 \
    --max-instances 10 \
    --port 8080 \
    --set-env-vars PROJECT_ID=jrodriguez-sandbox,REGION=us-central1

echo "🎉 ¡Despliegue completado!"
echo "🌐 URL: https://bonus-advisor-agent-[HASH]-uc.a.run.app"