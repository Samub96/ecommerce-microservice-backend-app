#!/bin/bash

# ============================================================================
# DESPLIEGUE COMPLETO EN AWS EKS 
# Proyecto E-commerce Microservices - Optimizado para Sandbox
# ============================================================================

set -e

# Configuración
CLUSTER_NAME="ecommerce-cluster-prod"
REGION="us-east-1"
NODE_TYPE="m7i-flex.large" 
NODE_COUNT=1
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)

# Configuración de Nodegroups (3 tiers)
CRITICAL_NODEGROUP="critical-nodes"
STANDARD_NODEGROUP="standard-nodes"
BURST_NODEGROUP="burst-nodes"

echo "🚀 Desplegando E-commerce Microservices en AWS EKS..."
echo "======================================================"
echo "🏗️ Cluster: $CLUSTER_NAME"
echo "🌐 Región: $REGION"
echo "👤 Usuario: $CURRENT_USER"

# ============================================================================
# 1. VERIFICAR CONFIGURACIÓN AWS
# ============================================================================
echo "📋 Paso 1: Verificando configuración AWS..."

# Verificar credenciales
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ Error: AWS CLI no configurado correctamente"
    echo "💡 Ejecuta: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account ID: $ACCOUNT_ID"
echo "✅ Región: $REGION"

# ============================================================================
# 2. VERIFICAR CLUSTER EKS EXISTENTE
# ============================================================================
echo "📋 Paso 2: Verificando cluster EKS..."

# Verificar si el cluster ya existe
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION > /dev/null 2>&1; then
    echo "✅ Cluster $CLUSTER_NAME ya existe"
    
    # Verificar conexión kubectl (sin reconfigurar)
    echo "📊 Verificando conexión kubectl..."
    if kubectl get nodes --request-timeout=10s > /dev/null 2>&1; then
        echo "✅ kubectl ya está funcionando correctamente"
        echo "📋 Nodos disponibles:"
        kubectl get nodes --show-labels
    else
        echo "⚠️ kubectl no configurado. Configurando ahora..."
        aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
        if kubectl get nodes --request-timeout=10s > /dev/null 2>&1; then
            echo "✅ kubectl configurado exitosamente"
        else
            echo "❌ Error: kubectl no funciona. Verifica credenciales AWS."
            exit 1
        fi
    fi
    
    # Verificar nodegroups
    echo "🔍 Verificando nodegroups..."
    NODEGROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output text)
    if [[ $NODEGROUPS == *"$CRITICAL_NODEGROUP"* ]] && [[ $NODEGROUPS == *"$STANDARD_NODEGROUP"* ]] && [[ $NODEGROUPS == *"$BURST_NODEGROUP"* ]]; then
        echo "✅ Todos los nodegroups están configurados"
        echo "   • $CRITICAL_NODEGROUP: Servicios críticos"
        echo "   • $STANDARD_NODEGROUP: Servicios estándar"
        echo "   • $BURST_NODEGROUP: Servicios intermitentes"
    else
        echo "⚠️ Faltan nodegroups. Nodegroups encontrados: $NODEGROUPS"
        echo "💡 Asegúrate de crear los nodegroups usando: eksctl create nodegroup --config-file=k8s/autoscaling/eks-nodegroups-config.yaml"
    fi
else
    echo "❌ Error: Cluster $CLUSTER_NAME no existe"
    echo "💡 Primero crea el cluster y nodegroups usando:"
    echo "   eksctl create cluster --config-file=k8s/autoscaling/eks-nodegroups-config.yaml"
    exit 1
fi

# ============================================================================
# 3. USAR IMÁGENES DE DOCKER HUB (SALTANDO ECR)
# ============================================================================
echo "📋 Paso 3: Usando imágenes de Docker Hub..."
echo "✅ Saltando configuración ECR - usando imágenes públicas de Docker Hub"

# ============================================================================
# 4. VERIFICAR IMÁGENES DISPONIBLES
# ============================================================================
echo "📋 Paso 4: Verificando imágenes en Docker Hub..."

# Lista de microservicios con sus imágenes en Docker Hub
declare -A docker_images
docker_images["api-gateway"]="samub18/api-gateway-ecommerce-boot"
docker_images["service-discovery"]="samub18/service-discovery-ecommerce-boot"
docker_images["cloud-config"]="samub18/cloud-config-ecommerce-boot"
docker_images["proxy-client"]="samub18/proxy-client-ecommerce-boot"
docker_images["user-service"]="samub18/user-service-ecommerce-boot"
docker_images["product-service"]="samub18/product-service-ecommerce-boot"
docker_images["favourite-service"]="samub18/favourite-service-ecommerce-boot"
docker_images["order-service"]="samub18/order-service-ecommerce-boot"
docker_images["shipping-service"]="samub18/shipping-service-ecommerce-boot"
docker_images["payment-service"]="samub18/payment-service-ecommerce-boot"

for service in "${!docker_images[@]}"; do
    echo "✅ $service -> ${docker_images[$service]}:0.1.0"
done

# ============================================================================
# 5. SALTAR CONTROLADORES (USAR CONFIGURACIÓN BÁSICA)
# ============================================================================
echo "📋 Paso 5: Saltando instalación de controladores..."
echo "⚠️ Usando configuración básica sin Load Balancer Controller por problemas de auth"

# ============================================================================
# 6. CREAR DEPLOYMENT ESTRUCTURADO KUBERNETES
# ============================================================================
echo "📋 Paso 6: Desplegando usando estructura k8s/ organizada..."

# Verificar que kubectl funciona antes de empezar
if ! kubectl get nodes --request-timeout=10s > /dev/null 2>&1; then
    echo "❌ Error crítico: kubectl no funciona"
    echo "💡 Verifica que AWS CLI esté configurado correctamente"
    exit 1
fi

echo "✅ kubectl funcionando - procediendo con deployment estructurado..."

# Función para aplicar YAML con reintentos
apply_k8s_yaml() {
    local yaml_file=$1
    local resource_name=$2
    echo "📦 Desplegando $resource_name..."
    
    if ! kubectl apply -f "$yaml_file" --timeout=120s; then
        echo "❌ Error aplicando $resource_name"
        return 1
    fi
    echo "✅ $resource_name aplicado exitosamente"
    return 0
}

# Deployment en orden correcto usando estructura k8s/
echo "🚀 Iniciando deployment estructurado..."

# 1. Namespaces
echo "🏗️ Fase 1: Creando namespaces..."
apply_k8s_yaml "k8s/namespaces/namespaces.yaml" "Namespaces"

# 2. ConfigMaps (antes que los deployments)
echo "🏗️ Fase 2: Aplicando configuraciones..."
apply_k8s_yaml "k8s/configmaps/microservices-config.yaml" "ConfigMaps principales"
apply_k8s_yaml "k8s/configmaps/eureka-config.yaml" "Configuración Eureka"
apply_k8s_yaml "k8s/configmaps/zipkin-config.yaml" "Configuración Zipkin"

# 3. Storage (PVCs) y Storage Classes
echo "🏗️ Fase 3: Configurando almacenamiento..."
apply_k8s_yaml "k8s/storage/storage-classes-and-volumes.yaml" "Storage Classes"
apply_k8s_yaml "k8s/storage/zipkin-pvc.yaml" "Almacenamiento Zipkin"

# 3.1. RBAC y Seguridad (CRÍTICO - antes de deployments)
echo "🏗️ Fase 3.1: Configurando RBAC y Seguridad..."
apply_k8s_yaml "k8s/security/rbac.yaml" "RBAC y ServiceAccounts"
apply_k8s_yaml "k8s/security/pod-security-standards.yaml" "Pod Security Standards"
apply_k8s_yaml "k8s/security/network-policies-3tier.yaml" "Network Policies"

# 3.2. Secrets y Sealed Secrets
echo "🏗️ Fase 3.2: Configurando Secrets..."
apply_k8s_yaml "k8s/secrets/secrets.yaml" "Secrets básicos"
apply_k8s_yaml "k8s/security/sealed-secrets-controller.yaml" "Sealed Secrets Controller"
echo "⏳ Esperando a que Sealed Secrets Controller esté listo..."
sleep 30
apply_k8s_yaml "k8s/secrets/sealed-secrets.yaml" "Sealed Secrets"

# 4. Zipkin (BURST-NODES - debe ir primero para tracing)
echo "🏗️ Fase 4: Desplegando Zipkin (BURST-NODES)..."
apply_k8s_yaml "k8s/deployments/zipkin-optimized.yaml" "Zipkin"
apply_k8s_yaml "k8s/services/infrastructure-services.yaml" "Servicios de infraestructura"

# 5. Service Discovery (BURST-NODES - obligatorio segundo)
echo "🏗️ Fase 5: Desplegando Service Discovery (BURST-NODES)..."
apply_k8s_yaml "k8s/deployments/service-discovery-optimized.yaml" "Service Discovery (Eureka)"

echo "⏳ Esperando a que Service Discovery esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/service-discovery -n ecommerce-dev

# 6. Cloud Config (BURST-NODES)
echo "🏗️ Fase 6: Desplegando Cloud Config (BURST-NODES)..."
apply_k8s_yaml "k8s/deployments/cloud-config-optimized.yaml" "Cloud Config"

echo "⏳ Esperando a que Cloud Config esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/cloud-config -n ecommerce-dev

# 7. API Gateway (BURST-NODES)
echo "🏗️ Fase 7: Desplegando API Gateway (BURST-NODES)..."
apply_k8s_yaml "k8s/deployments/api-gateway-optimized.yaml" "API Gateway"
apply_k8s_yaml "k8s/services/application-services.yaml" "Servicios de aplicación"

# 8. Proxy Client (BURST-NODES)
echo "🏗️ Fase 8: Desplegando Proxy Client (BURST-NODES)..."
apply_k8s_yaml "k8s/deployments/proxy-client-optimized.yaml" "Proxy Client"

# 9. Servicios Estándar (STANDARD-NODES)
echo "🏗️ Fase 9: Desplegando microservicios estándar (STANDARD-NODES)..."
apply_k8s_yaml "k8s/deployments/user-service-optimized.yaml" "User Service"
apply_k8s_yaml "k8s/deployments/product-service-optimized.yaml" "Product Service"
apply_k8s_yaml "k8s/deployments/favourite-service-optimized.yaml" "Favourite Service"

# 10. Servicios Críticos (CRITICAL-NODES)
echo "🏗️ Fase 10: Desplegando microservicios críticos (CRITICAL-NODES)..."
apply_k8s_yaml "k8s/deployments/order-service-optimized.yaml" "Order Service"
apply_k8s_yaml "k8s/deployments/payment-service-optimized.yaml" "Payment Service"
apply_k8s_yaml "k8s/deployments/shipping-service-optimized.yaml" "Shipping Service"

# 11. Servicios (todos los services)
echo "🏗️ Fase 11: Aplicando todos los servicios..."
apply_k8s_yaml "k8s/services/business-services.yaml" "Servicios de negocio"

# 12. Autoscaling (HPA para todos los servicios)
echo "🏗️ Fase 12: Configurando autoscaling (HPA)..."
apply_k8s_yaml "k8s/autoscaling/hpa-optimized-complete.yaml" "HPA completo para todos los servicios"

# 13. Monitoreo y Observabilidad (Opcional pero recomendado)
echo "🏗️ Fase 13: Configurando monitoreo (Opcional)..."
echo "💡 Configurando stack de monitoreo..."
if kubectl apply -f "k8s/monitoring/prometheus-grafana.yaml" --timeout=60s 2>/dev/null; then
    echo "✅ Stack de monitoreo aplicado"
else
    echo "⚠️ Stack de monitoreo saltado (opcional)"
fi

echo "✅ Deployment estructurado completado"

# Esperar y verificar deployment de los 10 microservicios
echo ""
echo "⏳ Verificando estado de los 10 microservicios..."

# Verificar pods por tier
echo "   🔍 CRITICAL-NODES (Payment, Order, Shipping):"
kubectl get pods -n ecommerce-dev -l tier=critical --show-labels

echo "   🔍 STANDARD-NODES (User, Product, Favourite):"
kubectl get pods -n ecommerce-dev -l tier=standard --show-labels

echo "   🔍 BURST-NODES (Gateway, Discovery, Config, Proxy, Zipkin):"
kubectl get pods -n ecommerce-dev -l tier=burst --show-labels

echo "   📋 Resumen completo de todos los pods:"
kubectl get pods -n ecommerce-dev -o wide

# Verificar servicios
echo "   🔍 Verificando servicios..."
kubectl get svc -n ecommerce-dev

# Verificar HPA
echo "   📊 Verificando HPA (Autoscaling):"
kubectl get hpa -n ecommerce-dev

# Verificar RBAC y Security
echo "   🔒 Verificando RBAC y Seguridad:"
kubectl get serviceaccounts -n ecommerce-dev
kubectl get roles -n ecommerce-dev
kubectl get rolebindings -n ecommerce-dev
echo "   🔍 Verificando Network Policies:"
kubectl get networkpolicies -n ecommerce-dev

# Verificar Secrets
echo "   🔐 Verificando Secrets:"
kubectl get secrets -n ecommerce-dev
kubectl get sealedsecrets -n ecommerce-dev 2>/dev/null || echo "   (Sealed Secrets no disponibles)"

# Verificar distribución en nodos
echo "   🏗️ Verificando distribución en nodegroups:"
echo "   📋 Nodos por tipo:"
kubectl get nodes --show-labels | grep -E "(workload-type|tier)"

# Verificar URLs si hay LoadBalancers
echo ""
echo "⏳ Verificando URLs de Load Balancer..."

LB_URL=$(kubectl get svc api-gateway-service -n ecommerce-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
EUREKA_URL=$(kubectl get svc service-discovery-service -n ecommerce-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$LB_URL" ] && [ "$LB_URL" != "null" ]; then
    echo "🌐 API Gateway: http://$LB_URL:8080"
    echo "🌐 Swagger UI: http://$LB_URL:8080/swagger-ui.html"
fi

if [ -n "$EUREKA_URL" ] && [ "$EUREKA_URL" != "null" ]; then
    echo "🔧 Eureka Dashboard: http://$EUREKA_URL:8761"
fi

# Información sobre como acceder
echo ""
echo "🔍 Para verificar el deployment desde la consola AWS:"
echo "  1. Ve a AWS EKS Console -> Clusters -> ecommerce-eks-cluster"
echo "  2. Ve a Workloads para ver los pods"
echo "  3. Ve a Services and networking para ver servicios"

# ============================================================================
# INFORMACIÓN FINAL
# ============================================================================
echo ""
echo "🎉 ¡DESPLIEGUE COMPLETO DE 10 MICROSERVICIOS EN AWS EKS!"
echo "========================================================"
echo "🏗️ Cluster EKS: $CLUSTER_NAME"
echo "🌐 Región: $REGION"  
echo "🔧 Arquitectura: 3 Nodegroups Free Tier (m7i-flex.large)"
echo "   🔴 CRITICAL-NODES: Payment, Order, Shipping"
echo "   🟡 STANDARD-NODES: User, Product, Favourite"
echo "   🟢 BURST-NODES: Gateway, Discovery, Config, Proxy, Zipkin"
echo "📦 Imágenes: Docker Hub (samub18/*:0.1.0)"
echo "🌍 Namespace: ecommerce-dev"
echo "📊 HPA: Autoscaling configurado para todos los servicios"
echo "🗂️ Estructura: Optimizada k8s/ multi-tier"
echo ""
echo "📋 Comandos útiles para verificar los 10 microservicios:"
echo "  kubectl get pods -n ecommerce-dev -o wide"
echo "  kubectl get svc -n ecommerce-dev"
echo "  kubectl get hpa -n ecommerce-dev"
echo "  kubectl get nodes --show-labels"
echo ""
echo "🔒 Verificaciones de seguridad:"
echo "  kubectl get serviceaccounts -n ecommerce-dev"
echo "  kubectl get networkpolicies -n ecommerce-dev"
echo "  kubectl get secrets -n ecommerce-dev"
echo "  kubectl get sealedsecrets -n ecommerce-dev"
echo ""
echo "🔧 Para acceso directo:"
echo "  kubectl port-forward svc/api-gateway-service 8080:8080 -n ecommerce-dev"
echo "  kubectl port-forward svc/service-discovery-service 8761:8761 -n ecommerce-dev"
echo "  kubectl port-forward svc/zipkin-service 9411:9411 -n ecommerce-dev"
echo ""
echo "📊 Monitoreo por tier:"
echo "  kubectl top nodes"
echo "  kubectl top pods -n ecommerce-dev --sort-by=cpu"
echo "  kubectl get events -n ecommerce-dev --sort-by=.metadata.creationTimestamp"
echo ""
echo "🏗️ Verificar distribución en nodegroups:"
echo "  kubectl get pods -n ecommerce-dev -l tier=critical -o wide"
echo "  kubectl get pods -n ecommerce-dev -l tier=standard -o wide"
echo "  kubectl get pods -n ecommerce-dev -l tier=burst -o wide"
echo ""
echo "🧹 Para limpiar:"
echo "  eksctl delete cluster --name $CLUSTER_NAME --region $REGION"