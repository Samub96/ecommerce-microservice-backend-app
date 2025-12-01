#!/bin/bash
# 🔍 SCRIPT DE VALIDACIÓN DE SERVICIOS
# Valida que los servicios estén configurados correctamente después de la limpieza

echo "🔍 VALIDACIÓN DE SERVICIOS KUBERNETES"
echo "======================================"
echo "📅 $(date)"
echo ""

# Función para verificar conectividad
check_service() {
    local service_name=$1
    local port=$2
    echo "🔎 Verificando $service_name..."
    
    # Verificar que el servicio existe
    if kubectl get service $service_name -n ecommerce-dev &>/dev/null; then
        echo "  ✅ Servicio existe"
        
        # Verificar endpoints
        endpoints=$(kubectl get endpoints $service_name -n ecommerce-dev -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "$endpoints" ]; then
            echo "  ✅ Endpoints disponibles: $endpoints"
        else
            echo "  ❌ Sin endpoints disponibles"
        fi
        
        # Verificar puerto configurado
        configured_port=$(kubectl get service $service_name -n ecommerce-dev -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
        target_port=$(kubectl get service $service_name -n ecommerce-dev -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
        echo "  📊 Puerto servicio: $configured_port → Puerto aplicación: $target_port"
        
    else
        echo "  ❌ Servicio no encontrado"
    fi
    echo ""
}

# VALIDAR SERVICIOS PRINCIPALES
echo "🚀 VALIDANDO SERVICIOS DE APLICACIÓN..."
echo "-------------------------------------"

check_service "user-service-service" "8700"
check_service "product-service-service" "8400" 
check_service "favourite-service-service" "8300"
check_service "order-service-service" "8600"
check_service "payment-service-service" "8500"
check_service "shipping-service-service" "8800"
check_service "proxy-client-service" "8900"

echo "🏗️ VALIDANDO SERVICIOS DE INFRAESTRUCTURA..."
echo "-------------------------------------------"

check_service "api-gateway-service" "8080"
check_service "service-discovery-service" "8761"
check_service "cloud-config-service" "9296"
check_service "zipkin-service" "9411"

# VERIFICAR DUPLICADOS (no deberían existir)
echo "🔍 VERIFICANDO DUPLICADOS (no deberían existir)..."
echo "-----------------------------------------------"

duplicates=("favourite-service" "product-service" "user-service" "order-service" "payment-service" "shipping-service")

for dup in "${duplicates[@]}"; do
    if kubectl get service $dup -n ecommerce-dev &>/dev/null; then
        echo "❌ DUPLICADO ENCONTRADO: $dup (debería eliminarse)"
    else
        echo "✅ Sin duplicado: $dup"
    fi
done

echo ""
echo "📊 RESUMEN DEL CLUSTER:"
echo "======================"
kubectl get services -n ecommerce-dev

echo ""
echo "🎯 PRUEBA DE CONECTIVIDAD DESDE API GATEWAY:"
echo "==========================================="

# Intentar hacer una llamada a través del API Gateway si está disponible
api_gateway_url=$(kubectl get service api-gateway-service -n ecommerce-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$api_gateway_url" ]; then
    echo "🌐 API Gateway URL: $api_gateway_url:8080"
    echo "🔗 Probar endpoints:"
    echo "   - http://$api_gateway_url:8080/user-service/health"
    echo "   - http://$api_gateway_url:8080/product-service/health"
    echo "   - http://$api_gateway_url:8080/payment-service/health"
else
    echo "⚠️  API Gateway LoadBalancer no disponible o no configurado"
fi

echo ""
echo "✅ VALIDACIÓN COMPLETADA"
echo "📋 Revisar los resultados arriba para identificar problemas restantes"