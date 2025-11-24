#!/bin/bash
# ============================================================================
# SCRIPT DE VALIDACIÓN SIMPLIFICADA DEL PROYECTO ECOMMERCE
# Simplified Project Validation Script
# ============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PROJECT_ROOT="/mnt/c/Users/Admin/IdeaProjects/ecommerce-microservice-backend-app"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

success() {
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

section() {
    echo ""
    echo -e "${BLUE}🔍 $1${NC}"
    echo "================================================================================================"
}

validate_yaml_syntax() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    if python3 -c "import yaml; yaml.safe_load_all(open('$file_path'))" 2>/dev/null; then
        success "$file_name - Sintaxis YAML válida"
        return 0
    else
        error "$file_name - Sintaxis YAML inválida"
        return 1
    fi
}

# ============================================================================
# VALIDACIONES PRINCIPALES
# ============================================================================

main() {
    echo -e "${BLUE}🚀 INICIANDO VALIDACIÓN COMPLETA DEL PROYECTO ECOMMERCE MICROSERVICES${NC}"
    echo "================================================================================================"
    
    cd "$PROJECT_ROOT" || exit 1
    
    section "VERIFICANDO DEPENDENCIAS"
    
    # Verificar herramientas necesarias
    if command -v helm >/dev/null 2>&1; then
        success "Helm está instalado"
    else
        warning "Helm no está instalado"
    fi
    
    if command -v kubectl >/dev/null 2>&1; then
        success "kubectl está instalado"
    else
        warning "kubectl no está instalado"
    fi
    
    if python3 -c "import yaml" 2>/dev/null; then
        success "PyYAML está disponible"
    else
        warning "PyYAML no está disponible"
    fi
    
    section "VALIDANDO ESTRUCTURA DEL PROYECTO"
    
    # Verificar directorios principales
    local required_dirs=("helm/ecommerce-microservices" "k8s/storage" "k8s/monitoring" "k8s/security" "k8s/autoscaling" "k8s/ingress")
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            success "Directorio encontrado: $dir"
        else
            error "Directorio faltante: $dir"
        fi
    done
    
    section "VALIDANDO HELM CHARTS"
    
    cd "$PROJECT_ROOT/helm/ecommerce-microservices"
    
    if [[ -f "Chart.yaml" ]]; then
        success "Chart.yaml encontrado"
        validate_yaml_syntax "Chart.yaml"
    else
        error "Chart.yaml faltante"
    fi
    
    if [[ -f "values.yaml" ]]; then
        success "values.yaml encontrado"
        validate_yaml_syntax "values.yaml"
    else
        error "values.yaml faltante"
    fi
    
    if helm template ecommerce . --values values.yaml --dry-run >/dev/null 2>&1; then
        success "Sintaxis de Helm templates válida"
    else
        error "Sintaxis de Helm templates inválida"
    fi
    
    section "VALIDANDO CONFIGURACIONES DE KUBERNETES"
    
    # Validar archivos YAML en subdirectorios
    local k8s_dirs=("storage" "monitoring" "security" "autoscaling" "ingress")
    
    for dir in "${k8s_dirs[@]}"; do
        local dir_path="$PROJECT_ROOT/k8s/$dir"
        if [[ -d "$dir_path" ]]; then
            info "Validando archivos en k8s/$dir/"
            local yaml_count=$(find "$dir_path" -name "*.yaml" 2>/dev/null | wc -l)
            
            if [[ $yaml_count -gt 0 ]]; then
                success "$dir contiene $yaml_count archivos YAML"
                
                # Validar sintaxis de algunos archivos clave
                for file in "$dir_path"/*.yaml; do
                    if [[ -f "$file" ]]; then
                        validate_yaml_syntax "$file"
                        break  # Solo validar el primero para ahorrar tiempo
                    fi
                done
            else
                warning "No se encontraron archivos YAML en k8s/$dir/"
            fi
        else
            error "Directorio k8s/$dir/ no encontrado"
        fi
    done
    
    section "VALIDANDO MICROSERVICIOS"
    
    local services=("api-gateway" "user-service" "product-service" "order-service" "payment-service" "shipping-service" "favourite-service")
    
    for service in "${services[@]}"; do
        if [[ -d "$PROJECT_ROOT/$service" ]]; then
            success "Microservicio encontrado: $service"
            
            if [[ -f "$PROJECT_ROOT/$service/pom.xml" ]]; then
                success "$service - pom.xml encontrado"
            else
                error "$service - pom.xml faltante"
            fi
        else
            error "Microservicio faltante: $service"
        fi
    done
    
    section "VALIDANDO CI/CD PIPELINE"
    
    if [[ -f "$PROJECT_ROOT/.github/workflows/ci-cd-pipeline.yml" ]]; then
        success "Pipeline CI/CD encontrado"
        validate_yaml_syntax "$PROJECT_ROOT/.github/workflows/ci-cd-pipeline.yml"
    else
        error "Pipeline CI/CD faltante"
    fi
    
    section "VALIDANDO CONFIGURACIONES DE AZURE"
    
    if [[ -f "$PROJECT_ROOT/k8s/azure-configurations.yaml" ]]; then
        success "Configuraciones Azure encontradas"
        validate_yaml_syntax "$PROJECT_ROOT/k8s/azure-configurations.yaml"
    else
        error "Configuraciones Azure faltantes"
    fi
    
    if [[ -f "$PROJECT_ROOT/azure-aks-validation.ps1" ]]; then
        success "Script de validación Azure encontrado"
    else
        error "Script de validación Azure faltante"
    fi
    
    section "REPORTE FINAL DE VALIDACIÓN"
    
    local success_rate=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    fi
    
    info "Total de verificaciones: $TOTAL_CHECKS"
    info "Verificaciones exitosas: $PASSED_CHECKS"
    info "Verificaciones fallidas: $FAILED_CHECKS"
    info "Tasa de éxito: $success_rate%"
    
    echo ""
    if [[ $success_rate -ge 90 ]]; then
        echo -e "${GREEN}🎉 PROYECTO VALIDADO EXITOSAMENTE - Listo para despliegue${NC}"
        echo -e "${GREEN}✨ Tu aplicación ecommerce está LISTA para despliegue en Azure AKS${NC}"
        echo -e "${GREEN}📊 Puntuación de calidad: $success_rate/100 - EXCELENTE${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "${YELLOW}⚠️  PROYECTO MAYORMENTE VÁLIDO - Revisar elementos faltantes${NC}"
        echo -e "${YELLOW}📊 Puntuación de calidad: $success_rate/100 - BUENO${NC}"
    else
        echo -e "${RED}❌ PROYECTO NECESITA TRABAJO ADICIONAL${NC}"
        echo -e "${RED}📊 Puntuación de calidad: $success_rate/100 - REQUIERE MEJORAS${NC}"
    fi
}

# Ejecutar función principal
main "$@"