#!/bin/bash

# Script para desplegar toda la aplicación ecommerce en Kubernetes
# Ejecutar desde el directorio raíz del proyecto

set -e

echo "🚀 Iniciando despliegue de Ecommerce Microservices en Kubernetes..."

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
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
    print_error "kubectl no está instalado. Por favor instálalo primero."
    exit 1
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "No se puede conectar al cluster de Kubernetes."
    exit 1
fi

print_status "Kubectl conectado al cluster exitosamente"

# Paso 1: Crear namespaces
echo "📁 Creando namespaces..."
kubectl apply -f k8s/namespaces/namespaces.yaml
print_status "Namespaces creados"

# Paso 2: Crear secrets y configmaps
echo "🔐 Creando secrets y configmaps..."
kubectl apply -f k8s/secrets/secrets.yaml
kubectl apply -f k8s/configmaps/
print_status "Secrets y ConfigMaps creados"

# Paso 3: Crear almacenamiento persistente
echo "💾 Creando volúmenes persistentes..."
kubectl apply -f k8s/storage/persistent-volumes.yaml
print_status "Almacenamiento configurado"

# Paso 4: Desplegar servicios de infraestructura
echo "🏗️ Desplegando servicios de infraestructura..."

# Zipkin primero
kubectl apply -f k8s/deployments/zipkin-deployment.yaml
kubectl apply -f k8s/services/infrastructure-services.yaml

echo "⏳ Esperando que Zipkin esté listo..."
kubectl wait --for=condition=ready pod -l app=zipkin -n ecommerce-dev --timeout=300s
print_status "Zipkin está listo"

# Service Discovery
kubectl apply -f k8s/deployments/service-discovery-deployment.yaml

echo "⏳ Esperando que Service Discovery esté listo..."
kubectl wait --for=condition=ready pod -l app=service-discovery -n ecommerce-dev --timeout=300s
print_status "Service Discovery está listo"

# Cloud Config
kubectl apply -f k8s/deployments/cloud-config-deployment.yaml

echo "⏳ Esperando que Cloud Config esté listo..."
kubectl wait --for=condition=ready pod -l app=cloud-config -n ecommerce-dev --timeout=300s
print_status "Cloud Config está listo"

# Paso 5: Desplegar API Gateway
echo "🌐 Desplegando API Gateway..."
kubectl apply -f k8s/deployments/api-gateway-deployment.yaml
kubectl apply -f k8s/services/application-services.yaml

echo "⏳ Esperando que API Gateway esté listo..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n ecommerce-dev --timeout=300s
print_status "API Gateway está listo"

# Paso 6: Desplegar microservicios de negocio
echo "🏪 Desplegando microservicios de negocio..."
kubectl apply -f k8s/deployments/business-services-deployment.yaml
kubectl apply -f k8s/deployments/support-services-deployment.yaml
kubectl apply -f k8s/deployments/user-service-deployment.yaml
kubectl apply -f k8s/services/business-services.yaml

echo "⏳ Esperando que los microservicios estén listos..."
kubectl wait --for=condition=ready pod -l component=microservice -n ecommerce-dev --timeout=300s
print_status "Microservicios están listos"

# Paso 7: Configurar Ingress (opcional)
echo "🌍 Configurando Ingress..."
if kubectl get ingressclass nginx &> /dev/null; then
    kubectl apply -f k8s/ingress/ingress.yaml
    print_status "Ingress configurado"
else
    print_warning "Nginx Ingress Controller no encontrado. Saltando configuración de Ingress."
fi

# Paso 8: Configurar autoescalado
echo "📈 Configurando autoescalado..."
kubectl apply -f k8s/autoscaling/hpa.yaml
print_status "Autoescalado configurado"

echo ""
echo "🎉 ¡Despliegue completado exitosamente!"
echo ""
echo "📋 Información del despliegue:"
echo "Namespace: ecommerce-dev"
echo ""
echo "🔍 Comandos útiles:"
echo "  Ver todos los pods:     kubectl get pods -n ecommerce-dev"
echo "  Ver todos los servicios: kubectl get svc -n ecommerce-dev"
echo "  Ver logs del gateway:   kubectl logs -f deployment/api-gateway -n ecommerce-dev"
echo "  Port-forward gateway:   kubectl port-forward svc/api-gateway-service 8080:8080 -n ecommerce-dev"
echo "  Port-forward zipkin:    kubectl port-forward svc/zipkin-service 9411:9411 -n ecommerce-dev"
echo "  Port-forward eureka:    kubectl port-forward svc/service-discovery-service 8761:8761 -n ecommerce-dev"
echo ""

# Mostrar estado de los pods
echo "📊 Estado actual de los pods:"
kubectl get pods -n ecommerce-dev

echo ""
echo "✨ La aplicación debería estar accesible en:"
echo "  API Gateway: http://localhost:8080 (después de port-forward)"
echo "  Zipkin UI:   http://localhost:9411 (después de port-forward)"
echo "  Eureka UI:   http://localhost:8761 (después de port-forward)"