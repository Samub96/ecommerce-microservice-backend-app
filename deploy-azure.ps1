# ============================================================================
# SCRIPT DE DESPLIEGUE EN AZURE AKS
# ============================================================================

param(
    [string]$resourceGroup = "rg-ecommerce-microservices",
    [string]$clusterName = "aks-ecommerce-cluster",
    [string]$location = "East US",
    [string]$subscriptionId = "",
    [string]$acrName = "ecommerceacr$(Get-Random)"
)

Write-Host "🚀 Iniciando despliegue de microservicios en Azure AKS..." -ForegroundColor Green

# ============================================================================
# 1. LOGIN Y CONFIGURACIÓN INICIAL
# ============================================================================
Write-Host "📋 Paso 1: Configuración inicial..." -ForegroundColor Yellow

# Login a Azure (si no está logueado)
$context = az account show 2>$null
if (-not $context) {
    Write-Host "🔐 Necesitas hacer login a Azure..."
    az login
}

# Seleccionar suscripción si se proporciona
if ($subscriptionId) {
    Write-Host "🔄 Configurando suscripción: $subscriptionId"
    az account set --subscription $subscriptionId
}

# Verificar suscripción actual
$currentSub = az account show --query name -o tsv
Write-Host "✅ Suscripción activa: $currentSub" -ForegroundColor Green

# ============================================================================
# 2. CREAR GRUPO DE RECURSOS
# ============================================================================
Write-Host "📋 Paso 2: Creando grupo de recursos..." -ForegroundColor Yellow

$rgExists = az group exists --name $resourceGroup
if ($rgExists -eq "false") {
    Write-Host "📦 Creando grupo de recursos: $resourceGroup en $location"
    az group create --name $resourceGroup --location $location
    Write-Host "✅ Grupo de recursos creado" -ForegroundColor Green
} else {
    Write-Host "✅ Grupo de recursos ya existe" -ForegroundColor Green
}

# ============================================================================
# 3. CREAR AZURE CONTAINER REGISTRY
# ============================================================================
Write-Host "📋 Paso 3: Configurando Azure Container Registry..." -ForegroundColor Yellow

$acrExists = az acr show --name $acrName --resource-group $resourceGroup 2>$null
if (-not $acrExists) {
    Write-Host "📦 Creando Azure Container Registry: $acrName"
    az acr create --resource-group $resourceGroup --name $acrName --sku Basic --admin-enabled true
    Write-Host "✅ ACR creado" -ForegroundColor Green
} else {
    Write-Host "✅ ACR ya existe" -ForegroundColor Green
}

# Obtener credenciales del ACR
$acrLoginServer = az acr show --name $acrName --resource-group $resourceGroup --query loginServer -o tsv
$acrUsername = az acr credential show --name $acrName --query username -o tsv
$acrPassword = az acr credential show --name $acrName --query passwords[0].value -o tsv

Write-Host "📝 ACR Login Server: $acrLoginServer" -ForegroundColor Cyan

# ============================================================================
# 4. CREAR CLÚSTER AKS
# ============================================================================
Write-Host "📋 Paso 4: Creando clúster AKS..." -ForegroundColor Yellow

$aksExists = az aks show --resource-group $resourceGroup --name $clusterName 2>$null
if (-not $aksExists) {
    Write-Host "🏗️ Creando clúster AKS: $clusterName"
    Write-Host "⏰ Esto puede tomar 10-15 minutos..." -ForegroundColor Cyan
    
    az aks create `
        --resource-group $resourceGroup `
        --name $clusterName `
        --location $location `
        --node-count 3 `
        --node-vm-size Standard_D2s_v3 `
        --enable-addons monitoring `
        --network-plugin azure `
        --network-policy calico `
        --enable-cluster-autoscaler `
        --min-count 2 `
        --max-count 5 `
        --zones 1 2 3 `
        --attach-acr $acrName `
        --enable-managed-identity `
        --generate-ssh-keys
        
    Write-Host "✅ Clúster AKS creado" -ForegroundColor Green
} else {
    Write-Host "✅ Clúster AKS ya existe" -ForegroundColor Green
    
    # Adjuntar ACR al clúster existente
    az aks update --resource-group $resourceGroup --name $clusterName --attach-acr $acrName
}

# ============================================================================
# 5. CONECTAR A AKS
# ============================================================================
Write-Host "📋 Paso 5: Conectando a AKS..." -ForegroundColor Yellow

# Obtener credenciales del clúster
az aks get-credentials --resource-group $resourceGroup --name $clusterName --overwrite-existing

# Verificar conexión
$nodes = kubectl get nodes --no-headers 2>$null
if ($nodes) {
    Write-Host "✅ Conexión establecida con AKS" -ForegroundColor Green
    Write-Host "📊 Nodos disponibles:"
    kubectl get nodes
} else {
    Write-Host "❌ Error conectando a AKS" -ForegroundColor Red
    exit 1
}

# ============================================================================
# 6. CONFIGURAR INGRESS CONTROLLER (NGINX)
# ============================================================================
Write-Host "📋 Paso 6: Configurando Ingress Controller..." -ForegroundColor Yellow

# Verificar si NGINX Ingress ya está instalado
$ingressExists = kubectl get namespace ingress-nginx 2>$null
if (-not $ingressExists) {
    Write-Host "🌐 Instalando NGINX Ingress Controller..."
    
    # Instalar NGINX Ingress específico para Azure
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    # Esperar a que esté listo
    Write-Host "⏰ Esperando a que Ingress Controller esté listo..." -ForegroundColor Cyan
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
    
    Write-Host "✅ NGINX Ingress Controller configurado" -ForegroundColor Green
} else {
    Write-Host "✅ NGINX Ingress Controller ya existe" -ForegroundColor Green
}

# ============================================================================
# 7. CONSTRUIR Y SUBIR IMÁGENES A ACR
# ============================================================================
Write-Host "📋 Paso 7: Construyendo y subiendo imágenes..." -ForegroundColor Yellow

# Login a ACR
az acr login --name $acrName

# Lista de microservicios
$microservices = @(
    "api-gateway",
    "service-discovery", 
    "cloud-config",
    "proxy-client",
    "user-service",
    "product-service",
    "favourite-service",
    "order-service",
    "shipping-service",
    "payment-service"
)

foreach ($service in $microservices) {
    Write-Host "🔨 Construyendo $service..." -ForegroundColor Cyan
    
    if (Test-Path "$service\Dockerfile") {
        # Construir imagen
        docker build -t "$acrLoginServer/$service`:latest" "$service"
        
        # Subir a ACR
        docker push "$acrLoginServer/$service`:latest"
        
        Write-Host "✅ $service subido a ACR" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Dockerfile no encontrado para $service" -ForegroundColor Yellow
    }
}

# ============================================================================
# 8. ACTUALIZAR CONFIGURACIONES DE HELM
# ============================================================================
Write-Host "📋 Paso 8: Actualizando configuraciones..." -ForegroundColor Yellow

# Actualizar values.yaml con ACR
$valuesFile = "helm\ecommerce-microservices\values.yaml"
if (Test-Path $valuesFile) {
    $content = Get-Content $valuesFile -Raw
    $content = $content -replace 'registry: ".*"', "registry: `"$acrLoginServer`""
    Set-Content $valuesFile $content
    Write-Host "✅ values.yaml actualizado con ACR" -ForegroundColor Green
}

# ============================================================================
# 9. DESPLEGAR CON HELM
# ============================================================================
Write-Host "📋 Paso 9: Desplegando con Helm..." -ForegroundColor Yellow

# Crear namespace
kubectl create namespace ecommerce-production --dry-run=client -o yaml | kubectl apply -f -

# Verificar que Helm está instalado
$helmVersion = helm version --short 2>$null
if (-not $helmVersion) {
    Write-Host "❌ Helm no está instalado. Por favor instala Helm primero." -ForegroundColor Red
    exit 1
}

# Desplegar con Helm
Write-Host "🚀 Desplegando aplicación..." -ForegroundColor Cyan
helm upgrade --install ecommerce-app helm\ecommerce-microservices\ `
    --namespace ecommerce-production `
    --set global.registry=$acrLoginServer `
    --set global.environment=production `
    --create-namespace `
    --wait `
    --timeout=10m

# ============================================================================
# 10. VERIFICAR DESPLIEGUE
# ============================================================================
Write-Host "📋 Paso 10: Verificando despliegue..." -ForegroundColor Yellow

# Verificar pods
Write-Host "📊 Estado de los pods:"
kubectl get pods -n ecommerce-production

# Verificar servicios
Write-Host "🌐 Servicios disponibles:"
kubectl get services -n ecommerce-production

# Obtener IP del Load Balancer
Write-Host "🔍 Obteniendo IP pública..." -ForegroundColor Cyan
$loadBalancerIP = kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

if ($loadBalancerIP) {
    Write-Host "✅ IP pública del Load Balancer: $loadBalancerIP" -ForegroundColor Green
    Write-Host "🌐 Puedes acceder a la aplicación en: http://$loadBalancerIP" -ForegroundColor Cyan
} else {
    Write-Host "⏰ Load Balancer aún configurándose, espera unos minutos..." -ForegroundColor Yellow
}

# ============================================================================
# INFORMACIÓN FINAL
# ============================================================================
Write-Host ""
Write-Host "🎉 DESPLIEGUE COMPLETADO!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host "🏗️ Clúster AKS: $clusterName" -ForegroundColor Cyan
Write-Host "📦 Container Registry: $acrLoginServer" -ForegroundColor Cyan
Write-Host "🌐 Namespace: ecommerce-production" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Comandos útiles:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -n ecommerce-production"
Write-Host "  kubectl get services -n ecommerce-production"
Write-Host "  kubectl logs -f deployment/api-gateway -n ecommerce-production"
Write-Host "  helm status ecommerce-app -n ecommerce-production"
Write-Host ""
Write-Host "🔧 Para monitoreo:"
Write-Host "  kubectl port-forward svc/prometheus-server 9090:80 -n monitoring"
Write-Host "  kubectl port-forward svc/grafana 3000:80 -n monitoring"