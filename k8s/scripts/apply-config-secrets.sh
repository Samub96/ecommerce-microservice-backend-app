#!/bin/bash

# ============================================================================
# APLICAR CONFIGURACIONES Y SECRETOS - ECOMMERCE MICROSERVICES
# ============================================================================
# Este script despliega todas las configuraciones y secretos necesarios
# para el sistema de microservicios ecommerce

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "${BLUE}🚀 APLICANDO CONFIGURACIONES Y SECRETOS${NC}"
echo "============================================="

# Verificar conectividad kubectl
echo "🔍 Verificando conectividad con el cluster..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "No se puede conectar al cluster de Kubernetes."
    exit 1
fi
print_status "Conectado al cluster Kubernetes"

# Paso 1: Aplicar namespaces
echo ""
echo "📁 Aplicando namespaces..."
kubectl apply -f k8s/namespaces/namespaces.yaml
print_status "Namespaces aplicados"

# Paso 2: Aplicar ConfigMaps
echo ""
echo "📋 Aplicando ConfigMaps..."
kubectl apply -f k8s/configmaps/microservices-config.yaml
kubectl apply -f k8s/configmaps/eureka-client-config.yaml
kubectl apply -f k8s/configmaps/eureka-config.yaml
kubectl apply -f k8s/configmaps/zipkin-config.yaml
print_status "ConfigMaps aplicados"

# Verificar ConfigMaps
echo ""
echo "🔍 Verificando ConfigMaps creados..."
kubectl get configmaps -n ecommerce-dev
print_status "ConfigMaps verificados"

# Paso 3: Instalar Sealed Secrets Controller (si no existe)
echo ""
echo "🔐 Verificando Sealed Secrets Controller..."
if ! kubectl get namespace sealed-secrets &> /dev/null; then
    echo "📦 Instalando Sealed Secrets Controller..."
    kubectl apply -f k8s/security/sealed-secrets-controller.yaml
    
    # Esperar a que el controller esté listo
    echo "⏳ Esperando que Sealed Secrets Controller esté listo..."
    kubectl wait --for=condition=ready pod -l name=sealed-secrets-controller -n sealed-secrets --timeout=300s
    print_status "Sealed Secrets Controller instalado"
else
    print_status "Sealed Secrets Controller ya existe"
fi

# Paso 4: Aplicar Secrets tradicionales
echo ""
echo "🔑 Aplicando Secrets tradicionales..."
kubectl apply -f k8s/secrets/secrets.yaml
print_status "Secrets tradicionales aplicados"

# Paso 5: Aplicar Sealed Secrets
echo ""
echo "🔒 Aplicando Sealed Secrets..."
kubectl apply -f k8s/secrets/sealed-secrets.yaml
print_status "Sealed Secrets aplicados"

# Verificar Secrets
echo ""
echo "🔍 Verificando Secrets creados..."
kubectl get secrets -n ecommerce-dev
print_status "Secrets verificados"

# Paso 6: Aplicar RBAC para configuraciones
echo ""
echo "🛡️  Aplicando RBAC para configuraciones..."
kubectl apply -f k8s/security/rbac.yaml
print_status "RBAC aplicado"

# Paso 7: Aplicar CronJob de rotación de secrets
echo ""
echo "🔄 Aplicando rotación automática de secrets..."
kubectl apply -f k8s/security/secret-rotation-cronjob.yaml
print_status "Rotación de secrets configurada"

# Verificar permisos RBAC
echo ""
echo "🔍 Verificando ServiceAccounts y RBAC..."
kubectl get serviceaccounts -n ecommerce-dev
kubectl get roles -n ecommerce-dev
kubectl get rolebindings -n ecommerce-dev
print_status "RBAC verificado"

# Paso 8: Verificar configuración completa
echo ""
echo "✅ VERIFICACIÓN FINAL"
echo "======================"

# Verificar ConfigMaps
CONFIG_MAPS=$(kubectl get configmaps -n ecommerce-dev --no-headers | wc -l)
echo "📋 ConfigMaps creados: $CONFIG_MAPS"

# Verificar Secrets
SECRETS=$(kubectl get secrets -n ecommerce-dev --no-headers | wc -l)
echo "🔐 Secrets creados: $SECRETS"

# Verificar Sealed Secrets
SEALED_SECRETS=$(kubectl get sealedsecrets -n ecommerce-dev --no-headers 2>/dev/null | wc -l)
echo "🔒 Sealed Secrets creados: $SEALED_SECRETS"

# Verificar ServiceAccounts
SERVICE_ACCOUNTS=$(kubectl get serviceaccounts -n ecommerce-dev --no-headers | wc -l)
echo "👤 Service Accounts: $SERVICE_ACCOUNTS"

# Verificar CronJob de rotación
CRONJOBS=$(kubectl get cronjobs -n ecommerce-dev --no-headers | wc -l)
echo "⏰ CronJobs de rotación: $CRONJOBS"

echo ""
print_status "CONFIGURACIONES Y SECRETOS APLICADOS EXITOSAMENTE!"
echo ""
print_info "Próximos pasos:"
echo "  1. Aplicar deployments: ./k8s/scripts/deploy-full.sh"
echo "  2. Verificar logs: kubectl logs -f deployment/api-gateway -n ecommerce-dev"
echo "  3. Verificar secrets: kubectl get sealedsecrets -n ecommerce-dev"
echo ""

# Información adicional sobre Sealed Secrets
echo "📝 INFORMACIÓN SOBRE SEALED SECRETS:"
echo "• Para crear nuevos secrets:"
echo "  echo -n 'mi-password' | kubeseal --raw --name=mi-secret --namespace=ecommerce-dev"
echo "• Para ver status de rotación:"
echo "  kubectl describe cronjob secret-rotation-job -n ecommerce-dev"
echo "• Para rotar manualmente:"
echo "  kubectl create job --from=cronjob/secret-rotation-job manual-rotation -n ecommerce-dev"