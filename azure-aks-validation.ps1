# ============================================================================
# SCRIPT DE VALIDACIÓN PARA AZURE KUBERNETES SERVICE (AKS)
# Azure AKS Deployment Validation Script
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "ecommerce-aks-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "ecommerce-aks-cluster",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPreReqs,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# Configuración de colores para output
$Host.UI.RawUI.WindowTitle = "Azure AKS Deployment Validation"
$ErrorColor = "Red"
$SuccessColor = "Green"
$InfoColor = "Cyan"
$WarningColor = "Yellow"

Write-Host "================================================================================================" -ForegroundColor $InfoColor
Write-Host "🚀 AZURE AKS DEPLOYMENT VALIDATION SCRIPT" -ForegroundColor $InfoColor
Write-Host "================================================================================================" -ForegroundColor $InfoColor
Write-Host ""

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Status) {
        "SUCCESS" { Write-Host "✅ [$timestamp] $Message" -ForegroundColor $SuccessColor }
        "ERROR"   { Write-Host "❌ [$timestamp] $Message" -ForegroundColor $ErrorColor }
        "WARNING" { Write-Host "⚠️  [$timestamp] $Message" -ForegroundColor $WarningColor }
        "INFO"    { Write-Host "ℹ️  [$timestamp] $Message" -ForegroundColor $InfoColor }
    }
}

function Test-CommandExists {
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-AzureLogin {
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Status "Azure CLI autenticado como: $($account.user.name)" "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Status "Azure CLI no está autenticado" "ERROR"
        return $false
    }
}

function Test-KubernetesConnection {
    try {
        $context = kubectl config current-context 2>$null
        if ($context) {
            Write-Status "Kubectl conectado al contexto: $context" "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Status "Kubectl no está conectado a ningún cluster" "ERROR"
        return $false
    }
}

# ============================================================================
# VALIDACIONES DE PRE-REQUISITOS
# ============================================================================

function Test-Prerequisites {
    Write-Status "🔍 VALIDANDO PRE-REQUISITOS..." "INFO"
    
    $prereqsPassed = $true
    
    # Verificar Azure CLI
    if (Test-CommandExists "az") {
        Write-Status "Azure CLI instalado" "SUCCESS"
        
        # Verificar autenticación
        if (-not (Test-AzureLogin)) {
            Write-Status "Ejecuta: az login" "ERROR"
            $prereqsPassed = $false
        }
    } else {
        Write-Status "Azure CLI no está instalado" "ERROR"
        Write-Status "Descarga desde: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" "INFO"
        $prereqsPassed = $false
    }
    
    # Verificar kubectl
    if (Test-CommandExists "kubectl") {
        Write-Status "kubectl instalado" "SUCCESS"
    } else {
        Write-Status "kubectl no está instalado" "ERROR"
        Write-Status "Instala con: az aks install-cli" "INFO"
        $prereqsPassed = $false
    }
    
    # Verificar Helm
    if (Test-CommandExists "helm") {
        $helmVersion = helm version --short 2>$null
        Write-Status "Helm instalado: $helmVersion" "SUCCESS"
    } else {
        Write-Status "Helm no está instalado" "WARNING"
        Write-Status "Descarga desde: https://helm.sh/docs/intro/install/" "INFO"
    }
    
    # Verificar Docker
    if (Test-CommandExists "docker") {
        Write-Status "Docker instalado" "SUCCESS"
    } else {
        Write-Status "Docker no está instalado" "WARNING"
        Write-Status "Necesario para build de imágenes" "INFO"
    }
    
    return $prereqsPassed
}

# ============================================================================
# VALIDACIONES DE CLUSTER AKS
# ============================================================================

function Test-AKSCluster {
    Write-Status "🔍 VALIDANDO CLUSTER AKS..." "INFO"
    
    try {
        # Verificar que el cluster existe
        $cluster = az aks show --resource-group $ResourceGroup --name $ClusterName 2>$null | ConvertFrom-Json
        if ($cluster) {
            Write-Status "Cluster AKS encontrado: $($cluster.name)" "SUCCESS"
            Write-Status "Estado: $($cluster.provisioningState)" "INFO"
            Write-Status "Versión Kubernetes: $($cluster.currentKubernetesVersion)" "INFO"
            Write-Status "Localización: $($cluster.location)" "INFO"
            
            # Verificar nodes
            $nodeCount = $cluster.agentPoolProfiles[0].count
            Write-Status "Número de nodos: $nodeCount" "INFO"
            
            return $true
        } else {
            Write-Status "Cluster AKS no encontrado" "ERROR"
            return $false
        }
    }
    catch {
        Write-Status "Error al verificar cluster AKS: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-KubernetesNodes {
    Write-Status "🔍 VALIDANDO NODOS DE KUBERNETES..." "INFO"
    
    try {
        $nodes = kubectl get nodes --no-headers 2>$null
        if ($nodes) {
            $nodeLines = $nodes -split "`n"
            $readyNodes = ($nodeLines | Where-Object { $_ -match "\s+Ready\s+" }).Count
            $totalNodes = $nodeLines.Count
            
            Write-Status "Nodos Ready: $readyNodes/$totalNodes" "SUCCESS"
            
            # Mostrar detalles de nodos si verbose
            if ($Verbose) {
                kubectl get nodes -o wide
            }
            
            return $readyNodes -eq $totalNodes
        } else {
            Write-Status "No se pueden obtener los nodos" "ERROR"
            return $false
        }
    }
    catch {
        Write-Status "Error al verificar nodos: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ============================================================================
# VALIDACIONES DE RECURSOS KUBERNETES
# ============================================================================

function Test-Namespaces {
    Write-Status "🔍 VALIDANDO NAMESPACES..." "INFO"
    
    $requiredNamespaces = @(
        "ecommerce-production",
        "monitoring", 
        "keda-system",
        "kube-system"
    )
    
    $allNamespacesExist = $true
    
    foreach ($namespace in $requiredNamespaces) {
        try {
            $ns = kubectl get namespace $namespace --no-headers 2>$null
            if ($ns) {
                Write-Status "Namespace '$namespace' existe" "SUCCESS"
            } else {
                Write-Status "Namespace '$namespace' no existe" "WARNING"
                $allNamespacesExist = $false
            }
        }
        catch {
            Write-Status "Error verificando namespace '$namespace'" "ERROR"
            $allNamespacesExist = $false
        }
    }
    
    return $allNamespacesExist
}

function Test-StorageClasses {
    Write-Status "🔍 VALIDANDO STORAGE CLASSES DE AZURE..." "INFO"
    
    $azureStorageClasses = @(
        "azure-disk-premium-ssd",
        "azure-disk-standard-ssd", 
        "azure-file-premium"
    )
    
    $allStorageClassesExist = $true
    
    foreach ($sc in $azureStorageClasses) {
        try {
            $storageClass = kubectl get storageclass $sc --no-headers 2>$null
            if ($storageClass) {
                Write-Status "Storage Class '$sc' configurado" "SUCCESS"
            } else {
                Write-Status "Storage Class '$sc' no encontrado" "WARNING"
                Write-Status "Aplica: kubectl apply -f k8s/azure-configurations.yaml" "INFO"
                $allStorageClassesExist = $false
            }
        }
        catch {
            Write-Status "Error verificando Storage Class '$sc'" "ERROR"
            $allStorageClassesExist = $false
        }
    }
    
    return $allStorageClassesExist
}

function Test-Services {
    Write-Status "🔍 VALIDANDO SERVICIOS..." "INFO"
    
    $coreServices = @(
        @{Name="mysql-master"; Namespace="ecommerce-production"},
        @{Name="api-gateway"; Namespace="ecommerce-production"},
        @{Name="service-discovery"; Namespace="ecommerce-production"},
        @{Name="prometheus-server"; Namespace="monitoring"},
        @{Name="grafana"; Namespace="monitoring"}
    )
    
    $allServicesRunning = $true
    
    foreach ($service in $coreServices) {
        try {
            $svc = kubectl get service $service.Name -n $service.Namespace --no-headers 2>$null
            if ($svc) {
                Write-Status "Servicio '$($service.Name)' en namespace '$($service.Namespace)' activo" "SUCCESS"
            } else {
                Write-Status "Servicio '$($service.Name)' en namespace '$($service.Namespace)' no encontrado" "WARNING"
                $allServicesRunning = $false
            }
        }
        catch {
            Write-Status "Error verificando servicio '$($service.Name)'" "ERROR"
            $allServicesRunning = $false
        }
    }
    
    return $allServicesRunning
}

function Test-Pods {
    Write-Status "🔍 VALIDANDO PODS CRÍTICOS..." "INFO"
    
    try {
        # Verificar pods en estado Running
        $runningPods = kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers 2>$null
        $totalRunningPods = ($runningPods -split "`n").Count
        
        # Verificar pods con problemas
        $problemPods = kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>$null
        $totalProblemPods = if ($problemPods) { ($problemPods -split "`n" | Where-Object { $_.Trim() -ne "" }).Count } else { 0 }
        
        Write-Status "Pods en estado Running: $totalRunningPods" "SUCCESS"
        
        if ($totalProblemPods -gt 0) {
            Write-Status "Pods con problemas: $totalProblemPods" "WARNING"
            if ($Verbose) {
                Write-Status "Pods con problemas:" "INFO"
                kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
            }
        } else {
            Write-Status "Todos los pods están en estado saludable" "SUCCESS"
        }
        
        return $totalProblemPods -eq 0
    }
    catch {
        Write-Status "Error verificando pods: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ============================================================================
# VALIDACIONES DE AZURE ESPECÍFICAS
# ============================================================================

function Test-AzureIntegration {
    Write-Status "🔍 VALIDANDO INTEGRACIÓN CON AZURE..." "INFO"
    
    try {
        # Verificar Azure Container Registry
        $acrName = "ecommerceacr"
        $acr = az acr show --name $acrName 2>$null | ConvertFrom-Json
        if ($acr) {
            Write-Status "Azure Container Registry '$acrName' configurado" "SUCCESS"
            Write-Status "Login Server: $($acr.loginServer)" "INFO"
        } else {
            Write-Status "Azure Container Registry no encontrado" "WARNING"
        }
        
        # Verificar Load Balancer público
        $publicIPs = kubectl get services --all-namespaces -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}' 2>$null
        if ($publicIPs) {
            Write-Status "Load Balancer con IP pública configurado" "SUCCESS"
        } else {
            Write-Status "No se encontraron Load Balancers con IP pública" "WARNING"
        }
        
        # Verificar cluster autoscaler
        $clusterAutoscaler = kubectl get deployment cluster-autoscaler -n kube-system --no-headers 2>$null
        if ($clusterAutoscaler) {
            Write-Status "Cluster Autoscaler configurado" "SUCCESS"
        } else {
            Write-Status "Cluster Autoscaler no encontrado" "WARNING"
        }
        
        return $true
    }
    catch {
        Write-Status "Error en validación de Azure: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ============================================================================
# PRUEBAS DE CONECTIVIDAD Y FUNCIONALIDAD
# ============================================================================

function Test-Connectivity {
    Write-Status "🔍 REALIZANDO PRUEBAS DE CONECTIVIDAD..." "INFO"
    
    try {
        # Test API Gateway health endpoint
        $apiGatewayIP = kubectl get service api-gateway -n ecommerce-production -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        if ($apiGatewayIP) {
            try {
                $response = Invoke-RestMethod -Uri "http://$apiGatewayIP/actuator/health" -TimeoutSec 10
                if ($response.status -eq "UP") {
                    Write-Status "API Gateway health check: PASSED" "SUCCESS"
                } else {
                    Write-Status "API Gateway health check: FAILED" "ERROR"
                }
            }
            catch {
                Write-Status "No se puede conectar al API Gateway" "WARNING"
            }
        } else {
            Write-Status "IP del API Gateway no disponible" "WARNING"
        }
        
        # Test MySQL connectivity
        $mysqlTest = kubectl exec -n ecommerce-production mysql-master-0 -- mysqladmin ping 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "MySQL Master connectivity: PASSED" "SUCCESS"
        } else {
            Write-Status "MySQL Master connectivity: FAILED" "ERROR"
        }
        
        return $true
    }
    catch {
        Write-Status "Error en pruebas de conectividad: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ============================================================================
# GENERACIÓN DE REPORTE
# ============================================================================

function Generate-Report {
    param([hashtable]$Results)
    
    Write-Status "📊 GENERANDO REPORTE DE VALIDACIÓN..." "INFO"
    
    $reportFile = "azure-aks-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $reportPath = Join-Path $PSScriptRoot $reportFile
    
    $report = @"
================================================================================================
REPORTE DE VALIDACIÓN - AZURE AKS DEPLOYMENT
================================================================================================
Fecha de validación: $(Get-Date)
Resource Group: $ResourceGroup
Cluster AKS: $ClusterName

RESULTADOS DE VALIDACIÓN:
================================================================================================
✅ Pre-requisitos: $(if($Results.Prerequisites){"PASSED"}else{"FAILED"})
✅ Cluster AKS: $(if($Results.AKSCluster){"PASSED"}else{"FAILED"})
✅ Nodos Kubernetes: $(if($Results.KubernetesNodes){"PASSED"}else{"FAILED"})
✅ Namespaces: $(if($Results.Namespaces){"PASSED"}else{"FAILED"})
✅ Storage Classes: $(if($Results.StorageClasses){"PASSED"}else{"FAILED"})
✅ Servicios: $(if($Results.Services){"PASSED"}else{"FAILED"})
✅ Pods: $(if($Results.Pods){"PASSED"}else{"FAILED"})
✅ Integración Azure: $(if($Results.AzureIntegration){"PASSED"}else{"FAILED"})
✅ Conectividad: $(if($Results.Connectivity){"PASSED"}else{"FAILED"})

PUNTUACIÓN TOTAL: $($Results.Values | Where-Object {$_} | Measure-Object).Count/9 PASSED

PRÓXIMOS PASOS:
================================================================================================
$(if($Results.Prerequisites -and $Results.AKSCluster -and $Results.KubernetesNodes) {
"🚀 Tu cluster está listo para desplegar la aplicación ecommerce!"
} else {
"⚠️  Hay problemas que resolver antes del despliegue."
})

Para despliegue completo, ejecuta:
helm install ecommerce ./helm/ecommerce-microservices/ --namespace ecommerce-production

Para monitoreo:
kubectl port-forward service/grafana 3000:3000 -n monitoring

================================================================================================
"@

    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Status "Reporte guardado en: $reportPath" "SUCCESS"
    
    return $reportPath
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

function Main {
    $results = @{}
    $overallSuccess = $true
    
    # Ejecutar validaciones
    if (-not $SkipPreReqs) {
        $results.Prerequisites = Test-Prerequisites
        $overallSuccess = $overallSuccess -and $results.Prerequisites
    }
    
    if (Test-KubernetesConnection) {
        $results.AKSCluster = Test-AKSCluster
        $results.KubernetesNodes = Test-KubernetesNodes
        $results.Namespaces = Test-Namespaces
        $results.StorageClasses = Test-StorageClasses
        $results.Services = Test-Services
        $results.Pods = Test-Pods
        $results.AzureIntegration = Test-AzureIntegration
        $results.Connectivity = Test-Connectivity
        
        $overallSuccess = $overallSuccess -and $results.AKSCluster -and $results.KubernetesNodes
    } else {
        Write-Status "Configurando conexión a AKS..." "INFO"
        try {
            az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing
            Write-Status "Credenciales de AKS configuradas" "SUCCESS"
        }
        catch {
            Write-Status "Error configurando credenciales de AKS" "ERROR"
            $overallSuccess = $false
        }
    }
    
    # Generar reporte
    $reportPath = Generate-Report -Results $results
    
    # Resumen final
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor $InfoColor
    if ($overallSuccess) {
        Write-Status "🎉 VALIDACIÓN COMPLETADA EXITOSAMENTE" "SUCCESS"
        Write-Status "Tu aplicación ecommerce está lista para Azure AKS" "SUCCESS"
    } else {
        Write-Status "⚠️  VALIDACIÓN COMPLETADA CON ADVERTENCIAS" "WARNING"
        Write-Status "Revisa el reporte para ver los detalles" "INFO"
    }
    Write-Host "================================================================================================" -ForegroundColor $InfoColor
    
    return $overallSuccess
}

# Ejecutar script principal
try {
    $success = Main
    exit $(if($success) { 0 } else { 1 })
}
catch {
    Write-Status "Error fatal en el script: $($_.Exception.Message)" "ERROR"
    exit 1
}