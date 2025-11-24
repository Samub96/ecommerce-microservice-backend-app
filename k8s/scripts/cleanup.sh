#!/bin/bash

# Script para limpiar completamente el despliegue de ecommerce

set -e

echo "🧹 Iniciando limpieza completa del despliegue de ecommerce..."

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Verificar que kubectl esté instalado
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl no está instalado."
    exit 1
fi

print_warning "Esta acción eliminará TODOS los recursos de ecommerce en Kubernetes"
read -p "¿Estás seguro? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operación cancelada."
    exit 0
fi

echo "🗑️ Eliminando recursos de Kubernetes..."

# Eliminar HPAs
echo "📉 Eliminando autoescaladores..."
kubectl delete -f k8s/autoscaling/hpa.yaml --ignore-not-found=true
kubectl delete hpa --all -n ecommerce-dev 2>/dev/null || true

# Eliminar Ingress
echo "🌍 Eliminando ingress..."
kubectl delete -f k8s/ingress/ingress.yaml --ignore-not-found=true
kubectl delete ingress --all -n ecommerce-dev 2>/dev/null || true

# Eliminar Services
echo "🔌 Eliminando servicios..."
kubectl delete -f k8s/services/ --ignore-not-found=true
kubectl delete services --all -n ecommerce-dev 2>/dev/null || true

# Eliminar Deployments
echo "🏗️ Eliminando deployments..."
kubectl delete -f k8s/deployments/ --ignore-not-found=true
kubectl delete deployments --all -n ecommerce-dev 2>/dev/null || true
kubectl delete daemonsets --all -n ecommerce-dev 2>/dev/null || true
kubectl delete statefulsets --all -n ecommerce-dev 2>/dev/null || true

# Eliminar monitoreo y logging
echo "📊 Eliminando stack de monitoreo y logging..."
kubectl delete -f k8s/monitoring/ --ignore-not-found=true
kubectl delete -f k8s/logging/ --ignore-not-found=true

# Eliminar seguridad
echo "🔒 Eliminando configuraciones de seguridad..."
kubectl delete -f k8s/security/ --ignore-not-found=true
kubectl delete networkpolicy --all -n ecommerce-dev 2>/dev/null || true
kubectl delete roles --all -n ecommerce-dev 2>/dev/null || true
kubectl delete rolebindings --all -n ecommerce-dev 2>/dev/null || true
kubectl delete serviceaccounts --all -n ecommerce-dev 2>/dev/null || true

# Eliminar Storage
echo "💾 Eliminando almacenamiento..."
kubectl delete -f k8s/storage/persistent-volumes.yaml --ignore-not-found=true
kubectl delete pvc --all -n ecommerce-dev 2>/dev/null || true

# Eliminar ConfigMaps y Secrets
echo "🔐 Eliminando configmaps y secrets..."
kubectl delete -f k8s/configmaps/ --ignore-not-found=true
kubectl delete -f k8s/secrets/secrets.yaml --ignore-not-found=true
kubectl delete configmaps --all -n ecommerce-dev 2>/dev/null || true
kubectl delete secrets --all -n ecommerce-dev 2>/dev/null || true

# Eliminar Namespaces (esto eliminará todo lo que quede)
echo "📁 Eliminando namespaces..."
kubectl delete -f k8s/namespaces/namespaces.yaml --ignore-not-found=true
kubectl delete namespace ecommerce-dev 2>/dev/null || true
kubectl delete namespace ecommerce-prod 2>/dev/null || true

# Eliminar PVs (cluster level)
echo "🗄️ Eliminando Persistent Volumes..."
kubectl delete pv ecommerce-logs-pv ecommerce-metrics-pv ecommerce-elasticsearch-pv 2>/dev/null || true

echo ""
echo "🎉 Limpieza completa finalizada!"
echo ""
print_warning "Los siguientes recursos han sido eliminados:"
echo "• Todos los deployments, services y pods"
echo "• Stack de monitoreo (Prometheus, Grafana)"
echo "• Stack de logging (ELK + Fluent Bit)"
echo "• Configuraciones (ConfigMaps y Secrets)"  
echo "• Almacenamiento persistente (PVs y PVCs)"
echo "• Políticas de seguridad (RBAC, Network Policies)"
echo "• Autoescalado (HPAs)"
echo "• Namespaces ecommerce-dev y ecommerce-prod"

echo ""
echo "🔍 Verificando limpieza..."
echo "Pods restantes en ecommerce-dev:"
kubectl get pods -n ecommerce-dev 2>/dev/null || echo "Namespace ecommerce-dev no existe (correcto)"

echo ""
print_status "El cluster está completamente limpio y listo para un nuevo despliegue"