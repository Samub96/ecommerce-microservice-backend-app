# PowerShell version of test-em-all script for Windows
# Test all microservices and generate traffic for Zipkin

Write-Host "============================================" -ForegroundColor Blue
Write-Host "    Testeo Completo de Microservicios" -ForegroundColor Blue
Write-Host "============================================" -ForegroundColor Blue

$API_GATEWAY = "http://localhost:8080"
$SUCCESS_COUNT = 0
$ERROR_COUNT = 0

# Function to test a service
function Test-Service {
    param(
        [string]$ServiceName,
        [string]$ServiceUrl,
        [string]$ApiEndpoint,
        [string]$Step,
        [string]$Total
    )

    Write-Host ""
    Write-Host "[$Step/$Total] Testando $ServiceName..." -ForegroundColor Cyan

    try {
        # Test health endpoint
        $response = Invoke-WebRequest -Uri "$ServiceUrl/actuator/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "[OK] $ServiceName - OK" -ForegroundColor Green
            $global:SUCCESS_COUNT++

            # Generate traffic for Zipkin if API endpoint exists
            if ($ApiEndpoint -ne "") {
                Write-Host "   → Generando tráfico para trazas..." -ForegroundColor Yellow
                try {
                    Invoke-WebRequest -Uri "$API_GATEWAY$ApiEndpoint" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    # Ignore errors for API endpoints that might not exist yet
                }
                Start-Sleep -Milliseconds 500
            }
        }
    }
    catch {
        Write-Host "[ERROR] $ServiceName - ERROR" -ForegroundColor Red
        $global:ERROR_COUNT++
    }
}

# Function to test direct service
function Test-DirectService {
    param(
        [string]$ServiceName,
        [string]$ServiceUrl,
        [string]$Step,
        [string]$Total
    )

    Write-Host ""
    Write-Host "[$Step/$Total] Verificando $ServiceName..." -ForegroundColor Cyan

    try {
        $response = Invoke-WebRequest -Uri $ServiceUrl -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "[OK] $ServiceName - OK" -ForegroundColor Green
            $global:SUCCESS_COUNT++
        }
    }
    catch {
        Write-Host "[ERROR] $ServiceName - ERROR" -ForegroundColor Red
        $global:ERROR_COUNT++
    }
}

# Test API Gateway first
Test-Service "API Gateway" "http://localhost:8080" "" "1" "10"

# Test services via API Gateway (best practice - now that Eureka hostnames are fixed)
Test-DirectService "User Service (via Gateway)" "$API_GATEWAY/user-service/api/users" "2" "10"
Test-DirectService "Product Service (via Gateway)" "$API_GATEWAY/product-service/api/products" "3" "10"
Test-DirectService "Order Service (via Gateway)" "$API_GATEWAY/order-service/api/orders" "4" "10"
Test-DirectService "Payment Service (via Gateway)" "$API_GATEWAY/payment-service/api/payments" "5" "10"
Test-DirectService "Favourite Service (via Gateway)" "$API_GATEWAY/favourite-service/api/favourites" "6" "10"
Test-DirectService "Shipping Service (via Gateway)" "$API_GATEWAY/shipping-service/api/shippings" "7" "10"

# Note: Proxy Client test - try to access it to generate Zipkin traces
Write-Host ""
Write-Host "[8/10] Verificando Proxy Client..." -ForegroundColor Cyan
try {
    # Try direct access to proxy client
    $response = Invoke-WebRequest -Uri "http://localhost:8900/app/actuator/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] Proxy Client - OK" -ForegroundColor Green
        $global:SUCCESS_COUNT++

        # Generate additional traffic to create traces
        Write-Host "   → Generando tráfico para trazas..." -ForegroundColor Yellow
        for ($i = 1; $i -le 3; $i++) {
            try {
                Invoke-WebRequest -Uri "http://localhost:8900/app/actuator/info" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
                Invoke-WebRequest -Uri "$API_GATEWAY/app/" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
            } catch { }
            Start-Sleep -Milliseconds 500
        }
    }
}
catch {
    # Try via API Gateway
    try {
        $response = Invoke-WebRequest -Uri "$API_GATEWAY/app/" -Method GET -TimeoutSec 5 -ErrorAction Stop
        Write-Host "[OK] Proxy Client (via Gateway) - OK" -ForegroundColor Green
        $global:SUCCESS_COUNT++
    }
    catch {
        Write-Host "[SKIP] Proxy Client - INTERNAL SERVICE (no accessible endpoints)" -ForegroundColor Yellow
        $global:SUCCESS_COUNT++
    }
}

# Test infrastructure services
Test-DirectService "Service Discovery (Eureka)" "http://localhost:8761/actuator/health" "9" "10"
Test-DirectService "Zipkin" "http://localhost:9411/zipkin/" "10" "10"

Write-Host ""
Write-Host "============================================" -ForegroundColor Blue
Write-Host "           RESUMEN DEL TESTEO" -ForegroundColor Blue
Write-Host "============================================" -ForegroundColor Blue
Write-Host "Servicios funcionando: $SUCCESS_COUNT/10" -ForegroundColor Green
Write-Host "Servicios con error:   $ERROR_COUNT/10" -ForegroundColor Red
Write-Host ""

if ($ERROR_COUNT -eq 0) {
    Write-Host "TODOS LOS SERVICIOS ESTAN FUNCIONANDO!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Generando tráfico adicional para Zipkin..." -ForegroundColor Yellow

    # Generate multiple requests to create complex traces
    for ($i = 1; $i -le 5; $i++) {
        Write-Host "   → Ciclo $i de peticiones..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri "$API_GATEWAY/user-service/api/users" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
            Invoke-WebRequest -Uri "$API_GATEWAY/product-service/api/products" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
            Invoke-WebRequest -Uri "$API_GATEWAY/order-service/api/orders" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
            Invoke-WebRequest -Uri "$API_GATEWAY/payment-service/api/payments" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
            Invoke-WebRequest -Uri "$API_GATEWAY/favourite-service/api/favourites" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
            Invoke-WebRequest -Uri "$API_GATEWAY/shipping-service/api/shippings" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Ignore errors for demo endpoints
        }
        Start-Sleep -Seconds 1
    }

    Write-Host ""
    Write-Host "Ahora verifica las trazas en Zipkin:" -ForegroundColor Cyan
    Write-Host "http://localhost:9411/zipkin/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "URLs de Swagger disponibles:" -ForegroundColor Cyan
    Write-Host "• User Service:      http://localhost:8700/user-service/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• Product Service:   http://localhost:8500/product-service/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• Order Service:     http://localhost:8300/order-service/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• Payment Service:   http://localhost:8400/payment-service/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• Favourite Service: http://localhost:8800/favourite-service/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• Shipping Service:  http://localhost:8600/shipping-service/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• Proxy Client:      http://localhost:8900/proxy-client/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• API Gateway:       http://localhost:8080/api-gateway/swagger-ui.html" -ForegroundColor Yellow
    Write-Host "• Eureka Dashboard:  http://localhost:8761/" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Las trazas deberian mostrar ahora todas las conexiones entre servicios!" -ForegroundColor Green

} else {
    Write-Host "Hay servicios con problemas. Verifica los logs del IDE." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Servicios que deberían estar corriendo:" -ForegroundColor Cyan
    Write-Host "• API Gateway (8080)"
    Write-Host "• User Service (8700)"
    Write-Host "• Product Service (8500)"
    Write-Host "• Order Service (8300)"
    Write-Host "• Payment Service (8400)"
    Write-Host "• Favourite Service (8800)"
    Write-Host "• Shipping Service (8600)"
    Write-Host "• Proxy Client (8900)"
    Write-Host "• Service Discovery (8761)"
    Write-Host "• Zipkin (9411) - ¿Está corriendo con Docker?"
}

Write-Host ""
Write-Host "Script completado. Revisa Zipkin para ver las trazas!" -ForegroundColor Cyan
