#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "============================================"
echo "    Testeo Completo de Microservicios AWS EKS"
echo "============================================"

API_GATEWAY="http://a2ee0d6f0b4e243c0abb249a271c9520-871411626.us-east-1.elb.amazonaws.com:8080"
EUREKA_URL="http://af8819d9c3e344624ba9826b37a9cbfd-710075248.us-east-1.elb.amazonaws.com:8761"
ZIPKIN_URL="http://a2676c2c17f0742a98d38a2df7be6acb-2049846578.us-east-1.elb.amazonaws.com:9411"
GRAFANA_URL="http://aa0f8e9cd5b1f437db57a9d462b99da6-1353816899.us-east-1.elb.amazonaws.com:3000"
PROMETHEUS_URL="http://aefaf518a91fa4d749e5b6fc10ba21b3-1737145771.us-east-1.elb.amazonaws.com:9090"
SUCCESS_COUNT=0
ERROR_COUNT=0

# Función para testear un servicio
test_service() {
    local service_name="$1"
    local service_url="$2"
    local api_endpoint="$3"
    local step="$4"
    local total="$5"

    echo ""
    echo -e "${BLUE}[$step/$total] Testando $service_name...${NC}"

    # Test health endpoint
    if curl -s "$service_url/actuator/health" > /dev/null 2>&1; then
        echo -e "✅ ${GREEN}$service_name - OK${NC}"
        ((SUCCESS_COUNT++))

        # Generar tráfico para Zipkin si tiene API endpoint
        if [ ! -z "$api_endpoint" ]; then
            echo "   → Generando tráfico para trazas..."
            curl -s "$API_GATEWAY$api_endpoint" > /dev/null 2>&1 || true
            sleep 0.5
        fi
    else
        echo -e "❌ ${RED}$service_name - ERROR${NC}"
        ((ERROR_COUNT++))
    fi
}

# Función para testear endpoint directo
test_direct_service() {
    local service_name="$1"
    local service_url="$2"
    local step="$3"
    local total="$4"

    echo ""
    echo -e "${BLUE}[$step/$total] Verificando $service_name...${NC}"

    if curl -s "$service_url" > /dev/null 2>&1; then
        echo -e "✅ ${GREEN}$service_name - OK${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "❌ ${RED}$service_name - ERROR${NC}"
        ((ERROR_COUNT++))
    fi
}

# Testear API Gateway primero
test_service "API Gateway" "$API_GATEWAY" "" "1" "12"

# Testear todos los microservicios via PROXY-CLIENT (arquitectura proxy-client centric)
test_direct_service "User Service" "$API_GATEWAY/app/api/users" "2" "12"
test_direct_service "Product Service" "$API_GATEWAY/app/api/products" "3" "12"
test_direct_service "Order Service" "$API_GATEWAY/app/api/orders" "4" "12"
test_direct_service "Payment Service" "$API_GATEWAY/app/api/payments" "5" "12"
test_direct_service "Favourite Service" "$API_GATEWAY/app/api/favourites" "6" "12"
test_direct_service "Shipping Service" "$API_GATEWAY/app/api/shippings" "7" "12"

# Test Proxy Client via API Gateway (proxy-client centric architecture)
echo ""
echo -e "${BLUE}[8/12] Verificando Proxy Client...${NC}"

# Test proxy-client by making calls through /app/ path
if curl -s "$API_GATEWAY/app/api/users" > /dev/null 2>&1; then
    # Generate traffic through proxy-client using /app/ routes
    echo "   → Activating proxy-client traffic..."
    curl -s "$API_GATEWAY/app/api/users" > /dev/null 2>&1 || true
    curl -s "$API_GATEWAY/app/api/products" > /dev/null 2>&1 || true
    curl -s "$API_GATEWAY/app/api/orders" > /dev/null 2>&1 || true
    sleep 1
    echo -e "✅ ${GREEN}Proxy Client - TRAFFIC GENERATED${NC}"
    ((SUCCESS_COUNT++))
else
    echo -e "❌ ${RED}Proxy Client - ERROR${NC}"
    ((ERROR_COUNT++))
fi

# Testear servicios de infraestructura
test_direct_service "Service Discovery (Eureka)" "$EUREKA_URL/actuator/health" "9" "12"
test_direct_service "Zipkin" "$ZIPKIN_URL/zipkin/" "10" "12"
test_direct_service "Grafana" "$GRAFANA_URL/login" "11" "12"
test_direct_service "Prometheus" "$PROMETHEUS_URL/-/healthy" "12" "12"

echo "============================================"
echo "           RESUMEN DEL TESTEO"
echo "============================================"
echo -e "✅ ${GREEN}Servicios funcionando: $SUCCESS_COUNT/12${NC}"
echo -e "❌ ${RED}Servicios con error:   $ERROR_COUNT/12${NC}"
echo ""

if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "🎉 ${GREEN}¡TODOS LOS SERVICIOS ESTÁN FUNCIONANDO!${NC}"
    echo ""
    echo -e "${YELLOW}Generando tráfico adicional para Zipkin...${NC}"

    # Generar múltiples peticiones para crear trazas más complejas via PROXY-CLIENT
    for i in {1..5}; do
        echo "   → Ciclo $i de peticiones via proxy-client..."
        curl -s "$API_GATEWAY/app/api/users" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/app/api/products" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/app/api/orders" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/app/api/payments" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/app/api/favourites" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/app/api/shippings" > /dev/null 2>&1 || true
        sleep 1
    done

    echo ""
    echo -e "${YELLOW}Generando tráfico adicional para activar Proxy Client...${NC}"
    
    # Generar peticiones concurrentes para activar comunicación inter-servicios via proxy-client
    for i in {1..10}; do
        echo "   → Activating proxy-client trace $i..."
        # Llamadas simultáneas que activan comunicación interna via proxy-client
        curl -s "$API_GATEWAY/app/api/users" > /dev/null 2>&1 &
        curl -s "$API_GATEWAY/app/api/products" > /dev/null 2>&1 &
        curl -s "$API_GATEWAY/app/api/orders" > /dev/null 2>&1 &
        curl -s "$API_GATEWAY/app/api/payments" > /dev/null 2>&1 &
        wait  # Esperar a que terminen las llamadas concurrentes
        sleep 0.5
    done

    echo ""
    echo -e "${BLUE}Ahora verifica las trazas en Zipkin:${NC}"
    echo -e "👉 ${YELLOW}$ZIPKIN_URL/zipkin/${NC}"
    echo ""
    echo -e "${BLUE}URLs AWS EKS disponibles:${NC}"
    echo -e "• API Gateway:       ${YELLOW}$API_GATEWAY${NC}"
    echo -e "• Eureka Dashboard:  ${YELLOW}$EUREKA_URL${NC}"
    echo -e "• Zipkin Tracing:    ${YELLOW}$ZIPKIN_URL${NC}"
    echo -e "• Grafana Dashboards: ${YELLOW}$GRAFANA_URL${NC}"
    echo -e "• Prometheus Metrics: ${YELLOW}$PROMETHEUS_URL${NC}"

    echo ""
    echo -e "${GREEN}📊 Las trazas deberían mostrar ahora todas las conexiones entre servicios!${NC}"

else
    echo -e "⚠️  ${YELLOW}Hay servicios con problemas. Verifica los logs de Kubernetes.${NC}"
    echo ""
    echo -e "${BLUE}Comandos para debugging:${NC}"
    echo "• kubectl get pods -n ecommerce-dev"
    echo "• kubectl logs <pod-name> -n ecommerce-dev"
    echo "• kubectl describe pod <pod-name> -n ecommerce-dev"
fi

echo ""
echo -e "${BLUE}Script completado. ¡Revisa Zipkin para ver las trazas distribuidas!${NC}"
