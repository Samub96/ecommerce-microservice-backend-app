#!/bin/bash

# ============================================================================
# DESPLIEGUE RÁPIDO EN AZURE AKS (Linux/WSL)
# ============================================================================

set -e

# Configuración
RESOURCE_GROUP="rg-ecommerce-microservices"
CLUSTER_NAME="aks-ecommerce-cluster"
LOCATION="East US"
ACR_NAME="ecommerceacr$RANDOM"

echo "🚀 Desplegando e-commerce microservices en Azure AKS..."

# ============================================================================
# 1. CREAR RECURSOS BÁSICOS
# ============================================================================
echo "📋 Creando recursos básicos..."

# Crear grupo de recursos
az group create --name $RESOURCE_GROUP --location "$LOCATION"

# Crear ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

# ============================================================================
# 2. CREAR CLÚSTER AKS
# ============================================================================
echo "🏗️ Creando clúster AKS (esto puede tomar 10-15 minutos)..."

az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location "$LOCATION" \
    --node-count 3 \
    --node-vm-size Standard_D2s_v3 \
    --enable-addons monitoring \
    --network-plugin azure \
    --network-policy calico \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 5 \
    --attach-acr $ACR_NAME \
    --enable-managed-identity \
    --generate-ssh-keys

# ============================================================================
# 3. CONECTAR Y CONFIGURAR
# ============================================================================
echo "🔗 Conectando al clúster..."

# Obtener credenciales
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Verificar conexión
kubectl get nodes

# Instalar NGINX Ingress
echo "🌐 Instalando NGINX Ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Esperar a que esté listo
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# ============================================================================
# 4. CONSTRUIR Y SUBIR IMÁGENES
# ============================================================================
echo "🔨 Construyendo imágenes..."

# Login a ACR
az acr login --name $ACR_NAME
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)

# Construir imágenes base (microservicios principales)
services=("api-gateway" "service-discovery" "cloud-config" "user-service" "product-service" "order-service")

for service in "${services[@]}"; do
    if [ -f "$service/Dockerfile" ]; then
        echo "🔨 Construyendo $service..."
        docker build -t "$ACR_LOGIN_SERVER/$service:latest" "$service/"
        docker push "$ACR_LOGIN_SERVER/$service:latest"
    fi
done

# ============================================================================
# 5. DESPLEGAR CON HELM
# ============================================================================
echo "🚀 Desplegando con Helm..."

# Crear namespace
kubectl create namespace ecommerce-production --dry-run=client -o yaml | kubectl apply -f -

# Actualizar values.yaml
sed -i "s|registry: \".*\"|registry: \"$ACR_LOGIN_SERVER\"|g" helm/ecommerce-microservices/values.yaml

# Desplegar
helm upgrade --install ecommerce-app helm/ecommerce-microservices/ \
    --namespace ecommerce-production \
    --set global.registry=$ACR_LOGIN_SERVER \
    --set global.environment=production \
    --create-namespace \
    --wait \
    --timeout=10m

# ============================================================================
# 6. VERIFICAR ESTADO
# ============================================================================
echo "📊 Verificando estado del despliegue..."

echo "Pods:"
kubectl get pods -n ecommerce-production

echo "Servicios:"
kubectl get services -n ecommerce-production

echo "Ingress:"
kubectl get ingress -n ecommerce-production

# Obtener IP pública
echo "🔍 Obteniendo IP pública..."
kubectl get service -n ingress-nginx ingress-nginx-controller

echo ""
echo "🎉 ¡Despliegue completado!"
echo "📋 Información del clúster:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Cluster: $CLUSTER_NAME"
echo "  ACR: $ACR_LOGIN_SERVER"
echo ""
echo "🔧 Comandos útiles:"
echo "  kubectl get all -n ecommerce-production"
echo "  kubectl logs -f deployment/api-gateway -n ecommerce-production"
echo "  helm status ecommerce-app -n ecommerce-production"