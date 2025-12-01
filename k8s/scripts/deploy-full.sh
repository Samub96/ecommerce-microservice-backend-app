#!/bin/bash

# Script completo para desplegar toda la infraestructura de ecommerce en Kubernetes
# Incluye servicios base, seguridad, monitoreo y logging

set -e

echo "🚀 Iniciando despliegue COMPLETO de Ecommerce Microservices en Kubernetes..."

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Verificar prerrequisitos
echo "🔍 Verificando prerrequisitos..."
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl no está instalado. Por favor instálalo primero."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "No se puede conectar al cluster de Kubernetes."
    exit 1
fi

print_status "Prerrequisitos verificados"

# Paso 1: Crear namespaces
echo "📁 Creando namespaces..."
kubectl apply -f k8s/namespaces/namespaces.yaml
print_status "Namespaces creados"

# Paso 2: Configurar seguridad
echo "🔒 Configurando seguridad (RBAC, Network Policies, Pod Security)..."
kubectl apply -f k8s/security/rbac.yaml
kubectl apply -f k8s/security/pod-security.yaml
kubectl apply -f k8s/security/network-policies.yaml
print_status "Configuraciones de seguridad aplicadas"

# Paso 3: Crear secrets y configmaps
echo "🔐 Creando secrets y configmaps..."
kubectl apply -f k8s/secrets/secrets.yaml
kubectl apply -f k8s/configmaps/
kubectl apply -f k8s/monitoring/prometheus-config.yaml
kubectl apply -f k8s/monitoring/grafana-config.yaml
kubectl apply -f k8s/logging/fluent-bit-config.yaml
print_status "Secrets y ConfigMaps creados"

# Paso 4: Crear almacenamiento persistente
echo "💾 Creando volúmenes persistentes..."
kubectl apply -f k8s/storage/persistent-volumes.yaml
print_status "Almacenamiento configurado"

# Paso 5: Desplegar servicios de infraestructura base
echo "🏗️ Desplegando servicios de infraestructura base..."

# Zipkin primero
kubectl apply -f k8s/deployments/zipkin-optimized.yaml
kubectl apply -f k8s/services/infrastructure-services.yaml

echo "⏳ Esperando que Zipkin esté listo..."
kubectl wait --for=condition=ready pod -l app=zipkin -n ecommerce-dev --timeout=300s
print_status "Zipkin está listo"

# Service Discovery
kubectl apply -f k8s/deployments/service-discovery-optimized.yaml

echo "⏳ Esperando que Service Discovery esté listo..."
kubectl wait --for=condition=ready pod -l app=service-discovery -n ecommerce-dev --timeout=300s
print_status "Service Discovery está listo"

# Cloud Config
kubectl apply -f k8s/deployments/cloud-config-optimized.yaml

echo "⏳ Esperando que Cloud Config esté listo..."
kubectl wait --for=condition=ready pod -l app=cloud-config -n ecommerce-dev --timeout=300s
print_status "Cloud Config está listo"

# Paso 6: Desplegar stack de logging (ELK)
echo "📋 Desplegando stack de logging (Elasticsearch + Kibana + Fluent Bit)..."
kubectl apply -f k8s/logging/elk-stack.yaml

echo "⏳ Esperando que Elasticsearch esté listo..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n ecommerce-dev --timeout=300s
print_status "Elasticsearch está listo"

echo "⏳ Esperando que Kibana esté listo..."
kubectl wait --for=condition=ready pod -l app=kibana -n ecommerce-dev --timeout=300s
print_status "Kibana está listo"

print_status "Stack de logging desplegado"

# Paso 7: Desplegar monitoreo (Prometheus + Grafana)
echo "📊 Desplegando stack de monitoreo (Prometheus + Grafana)..."
kubectl apply -f k8s/monitoring/prometheus-grafana.yaml

echo "⏳ Esperando que Prometheus esté listo..."
kubectl wait --for=condition=ready pod -l app=prometheus -n ecommerce-dev --timeout=300s
print_status "Prometheus está listo"

echo "⏳ Esperando que Grafana esté listo..."
kubectl wait --for=condition=ready pod -l app=grafana -n ecommerce-dev --timeout=300s
print_status "Grafana está listo"

print_status "Stack de monitoreo desplegado"

# Paso 8: Desplegar API Gateway
echo "🌐 Desplegando API Gateway..."
kubectl apply -f k8s/deployments/api-gateway-optimized.yaml
kubectl apply -f k8s/services/application-services.yaml

echo "⏳ Esperando que API Gateway esté listo..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n ecommerce-dev --timeout=300s
print_status "API Gateway está listo"

# Paso 9: Desplegar microservicios de negocio
echo "🏪 Desplegando microservicios de negocio..."
kubectl apply -f k8s/deployments/business-services-optimized.yaml
kubectl apply -f k8s/deployments/support-services-optimized.yaml
kubectl apply -f k8s/deployments/user-service-optimized.yaml

# Crear services faltantes
kubectl apply -f k8s/services/business-services.yaml

echo "⏳ Esperando que los microservicios estén listos..."
kubectl wait --for=condition=ready pod -l component=microservice -n ecommerce-dev --timeout=300s
print_status "Microservicios están listos"

# Paso 10: Configurar Ingress (opcional)
echo "🌍 Configurando Ingress..."
if kubectl get ingressclass nginx &> /dev/null; then
    kubectl apply -f k8s/ingress/ingress.yaml
    print_status "Ingress configurado"
else
    print_warning "Nginx Ingress Controller no encontrado. Saltando configuración de Ingress."
fi

# Paso 11: Configurar autoescalado
echo "📈 Configurando autoescalado..."
kubectl apply -f k8s/autoscaling/hpa-optimized-complete.yaml
print_status "Autoescalado configurado"

echo ""
echo "🎉 ¡Despliegue COMPLETO exitoso!"
echo ""
print_info "=========================================="
print_info "📋 RESUMEN DE SERVICIOS DESPLEGADOS"
print_info "=========================================="
echo ""
echo "🏗️  INFRAESTRUCTURA BASE:"
echo "   • Zipkin (Tracing distribuido)"
echo "   • Eureka Server (Service Discovery)"  
echo "   • Cloud Config (Configuración centralizada)"
echo ""
echo "🏪 MICROSERVICIOS DE NEGOCIO:"
echo "   • API Gateway"
echo "   • User Service"
echo "   • Product Service"
echo "   • Order Service" 
echo "   • Payment Service"
echo "   • Shipping Service"
echo "   • Favourite Service"
echo "   • Proxy Client"
echo ""
echo "📊 MONITOREO Y OBSERVABILIDAD:"
echo "   • Prometheus (Métricas)"
echo "   • Grafana (Dashboards)"
echo "   • Elasticsearch (Logs storage)"
echo "   • Kibana (Log analysis)"
echo "   • Fluent Bit (Log collector)"
echo ""
echo "🔒 SEGURIDAD:"
echo "   • RBAC configurado"
echo "   • Network Policies aplicadas"
echo "   • Pod Security Standards"
echo "   • Service Accounts específicos"
echo ""
echo "📈 ESCALABILIDAD:"
echo "   • Horizontal Pod Autoscalers"
echo "   • Resource limits configurados"
echo "   • Health checks implementados"
echo ""
print_info "=========================================="
print_info "🔗 ACCESO A SERVICIOS"
print_info "=========================================="
echo ""
echo "Para acceder a los servicios, usa port-forward:"
echo ""
echo "📱 APLICACIÓN:"
echo "   kubectl port-forward svc/api-gateway-service 8080:8080 -n ecommerce-dev"
echo "   → API Gateway: http://localhost:8080"
echo ""
echo "📊 MONITOREO:"
echo "   kubectl port-forward svc/grafana-service 3000:3000 -n ecommerce-dev"
echo "   → Grafana: http://localhost:3000 (admin/admin123)"
echo ""
echo "   kubectl port-forward svc/prometheus-service 9090:9090 -n ecommerce-dev"
echo "   → Prometheus: http://localhost:9090"
echo ""
echo "📋 LOGGING:"
echo "   kubectl port-forward svc/kibana-service 5601:5601 -n ecommerce-dev"
echo "   → Kibana: http://localhost:5601"
echo ""
echo "🔍 TRACING:"
echo "   kubectl port-forward svc/zipkin-service 9411:9411 -n ecommerce-dev"
echo "   → Zipkin: http://localhost:9411"
echo ""
echo "🎯 SERVICE DISCOVERY:"
echo "   kubectl port-forward svc/service-discovery-service 8761:8761 -n ecommerce-dev"
echo "   → Eureka: http://localhost:8761"
echo ""
print_info "=========================================="
print_info "🔍 COMANDOS ÚTILES"
print_info "=========================================="
echo ""
echo "Ver todos los pods:      kubectl get pods -n ecommerce-dev"
echo "Ver todos los servicios: kubectl get svc -n ecommerce-dev"
echo "Ver logs del gateway:    kubectl logs -f deployment/api-gateway -n ecommerce-dev"
echo "Ver HPA status:          kubectl get hpa -n ecommerce-dev"
echo "Ver network policies:    kubectl get networkpolicy -n ecommerce-dev"
echo ""

# Mostrar estado actual
echo "📊 Estado actual de los pods:"
kubectl get pods -n ecommerce-dev -o wide

echo ""
echo "🌐 Estado de los servicios:"
kubectl get svc -n ecommerce-dev

echo ""
print_status "¡Tu plataforma de ecommerce con observabilidad completa está lista!"
print_warning "Recuerda configurar DNS local o usar port-forward para acceder a los servicios"