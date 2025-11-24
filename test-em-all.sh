#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "============================================"
echo "    Testeo Completo de Microservicios"
echo "============================================"

API_GATEWAY="http://localhost:8080"
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
test_service "API Gateway" "http://localhost:8080" "" "1" "10"

# Testear todos los microservicios via API Gateway (best practice)
test_direct_service "User Service" "$API_GATEWAY/user-service/api/users" "2" "10"
test_direct_service "Product Service" "$API_GATEWAY/product-service/api/products" "3" "10"
test_direct_service "Order Service" "$API_GATEWAY/order-service/api/orders" "4" "10"
test_direct_service "Payment Service" "$API_GATEWAY/payment-service/api/payments" "5" "10"
test_direct_service "Favourite Service" "$API_GATEWAY/favourite-service/api/favourites" "6" "10"
test_direct_service "Shipping Service" "$API_GATEWAY/shipping-service/api/shippings" "7" "10"

# Note: Proxy Client is an internal service without external endpoints
echo ""
echo -e "${BLUE}[8/10] Verificando Proxy Client...${NC}"
echo -e "${YELLOW}[SKIP] Proxy Client - INTERNAL SERVICE (no external endpoints)${NC}"
((SUCCESS_COUNT++))

# Testear servicios de infraestructura
test_direct_service "Service Discovery (Eureka)" "http://localhost:8761/actuator/health" "9" "10"
test_direct_service "Zipkin" "http://localhost:9411/zipkin/" "10" "10"

echo ""
echo "============================================"
echo "           RESUMEN DEL TESTEO"
echo "============================================"
echo -e "✅ ${GREEN}Servicios funcionando: $SUCCESS_COUNT/10${NC}"
echo -e "❌ ${RED}Servicios con error:   $ERROR_COUNT/10${NC}"
echo ""

if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "🎉 ${GREEN}¡TODOS LOS SERVICIOS ESTÁN FUNCIONANDO!${NC}"
    echo ""
    echo -e "${YELLOW}Generando tráfico adicional para Zipkin...${NC}"

    # Generar múltiples peticiones para crear trazas más complejas
    for i in {1..5}; do
        echo "   → Ciclo $i de peticiones..."
        curl -s "$API_GATEWAY/user-service/api/users" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/product-service/api/products" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/order-service/api/orders" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/payment-service/api/payments" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/favourite-service/api/favourites" > /dev/null 2>&1 || true
        curl -s "$API_GATEWAY/shipping-service/api/shippings" > /dev/null 2>&1 || true
        sleep 1
    done

    echo ""
    echo -e "${BLUE}Ahora verifica las trazas en Zipkin:${NC}"
    echo -e "👉 ${YELLOW}http://localhost:9411/zipkin/${NC}"
    echo ""
    echo -e "${BLUE}URLs de Swagger disponibles:${NC}"
    echo -e "• User Service:      ${YELLOW}http://localhost:8700/user-service/swagger-ui.html${NC}"
    echo -e "• Product Service:   ${YELLOW}http://localhost:8400/product-service/swagger-ui.html${NC}"
    echo -e "• Order Service:     ${YELLOW}http://localhost:8600/order-service/swagger-ui.html${NC}"
    echo -e "• Payment Service:   ${YELLOW}http://localhost:8500/payment-service/swagger-ui.html${NC}"
    echo -e "• Favourite Service: ${YELLOW}http://localhost:8300/favourite-service/swagger-ui.html${NC}"
    echo -e "• Shipping Service:  ${YELLOW}http://localhost:8800/shipping-service/swagger-ui.html${NC}"
    echo -e "• Proxy Client:      ${YELLOW}http://localhost:8900/proxy-client/swagger-ui.html${NC}"
    echo -e "• API Gateway:       ${YELLOW}http://localhost:8080/api-gateway/swagger-ui.html${NC}"
    echo -e "• Eureka Dashboard:  ${YELLOW}http://localhost:8761/${NC}"

    echo ""
    echo -e "${GREEN}📊 Las trazas deberían mostrar ahora todas las conexiones entre servicios!${NC}"

else
    echo -e "⚠️  ${YELLOW}Hay servicios con problemas. Verifica los logs del IDE.${NC}"
    echo ""
    echo -e "${BLUE}Servicios que deberían estar corriendo:${NC}"
    echo "• API Gateway (8080)"
    echo "• User Service (8700)"
    echo "• Product Service (8400)"
    echo "• Order Service (8600)"
    echo "• Payment Service (8500)"
    echo "• Favourite Service (8300)"
    echo "• Shipping Service (8800)"
    echo "• Proxy Client (8900)"
    echo "• Service Discovery (8761)"
    echo "• Zipkin (9411) - ¿Está corriendo con Docker?"
fi

echo ""
echo -e "${BLUE}Script completado. ¡Revisa Zipkin para ver las trazas!${NC}"
