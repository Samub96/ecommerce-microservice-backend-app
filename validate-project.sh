#!/bin/bash
# ============================================================================
# SCRIPT DE VALIDACIÓN COMPLETA DEL PROYECTO ECOMMERCE
# Complete Project Validation Script
# ============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PROJECT_ROOT="/mnt/c/Users/Admin/IdeaProjects/ecommerce-microservice-backend-app"
VALIDATION_LOG="/tmp/validation-report-$(date +%Y%m%d-%H%M%S).log"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

log() {
    echo -e "$1" | tee -a "$VALIDATION_LOG"
}

success() {
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
    log "${GREEN}✅ $1${NC}"
}

error() {
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
    log "${RED}❌ $1${NC}"
}

warning() {
    log "${YELLOW}⚠️  $1${NC}"
}

info() {
    log "${BLUE}ℹ️  $1${NC}"
}

section() {
    log ""
    log "${BLUE}================================================================================================${NC}"
    log "${BLUE}🔍 $1${NC}"
    log "${BLUE}================================================================================================${NC}"
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

validate_project_structure() {
    section "VALIDANDO ESTRUCTURA DEL PROYECTO"
    
    local required_dirs=(
        "helm/ecommerce-microservices"
        "k8s/storage"
        "k8s/monitoring" 
        "k8s/security"
        "k8s/autoscaling"
        "k8s/ingress"
        ".github/workflows"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            success "Directorio encontrado: $dir"
        else
            error "Directorio faltante: $dir"
        fi
    done
}

validate_helm_charts() {
    section "VALIDANDO HELM CHARTS"
    
    cd "$PROJECT_ROOT/helm/ecommerce-microservices"
    
    # Verificar archivos requeridos
    local helm_files=("Chart.yaml" "values.yaml" "values-azure-production.yaml")
    for file in "${helm_files[@]}"; do
        if [[ -f "$file" ]]; then
            success "Archivo Helm encontrado: $file"
            validate_yaml_syntax "$file"
        else
            error "Archivo Helm faltante: $file"
        fi
    done
    
    # Validar templates
    if [[ -d "templates" ]]; then
        success "Directorio templates encontrado"
        local template_count=$(find templates -name "*.yaml" -o -name "*.tpl" | wc -l)
        info "Encontrados $template_count archivos de template"
        
        # Validar sintaxis de Helm
        if helm template ecommerce . --values values.yaml --dry-run >/dev/null 2>&1; then
            success "Sintaxis de Helm templates válida"
        else
            error "Sintaxis de Helm templates inválida"
        fi
    else
        error "Directorio templates faltante"
    fi
}

validate_kubernetes_configs() {
    section "VALIDANDO CONFIGURACIONES DE KUBERNETES"
    
    # Validar archivos YAML en subdirectorios
    local k8s_dirs=("storage" "monitoring" "security" "autoscaling" "ingress")
    
    for dir in "${k8s_dirs[@]}"; do
        local dir_path="$PROJECT_ROOT/k8s/$dir"
        if [[ -d "$dir_path" ]]; then
            info "Validando archivos en k8s/$dir/"
            local yaml_files=$(find "$dir_path" -name "*.yaml" 2>/dev/null || true)
            
            if [[ -n "$yaml_files" ]]; then
                while IFS= read -r file; do
                    validate_yaml_syntax "$file"
                done <<< "$yaml_files"
            else
                warning "No se encontraron archivos YAML en k8s/$dir/"
            fi
        else
            warning "Directorio k8s/$dir/ no encontrado"
        fi
    done
}

validate_microservices() {
    section "VALIDANDO MICROSERVICIOS"
    
    local services=("api-gateway" "user-service" "product-service" "order-service" "payment-service" "shipping-service" "favourite-service" "service-discovery" "cloud-config" "proxy-client")
    
    for service in "${services[@]}"; do
        if [[ -d "$PROJECT_ROOT/$service" ]]; then
            success "Microservicio encontrado: $service"
            
            # Verificar archivos clave
            if [[ -f "$PROJECT_ROOT/$service/pom.xml" ]]; then
                success "$service - pom.xml encontrado"
            else
                error "$service - pom.xml faltante"
            fi
            
            if [[ -d "$PROJECT_ROOT/$service/src/main/java" ]]; then
                success "$service - código fuente encontrado"
            else
                warning "$service - código fuente no encontrado"
            fi
            
            if [[ -f "$PROJECT_ROOT/$service/Dockerfile" ]]; then
                success "$service - Dockerfile encontrado"
            else
                warning "$service - Dockerfile no encontrado"
            fi
        else
            error "Microservicio faltante: $service"
        fi
    done
}

validate_ci_cd() {
    section "VALIDANDO CI/CD PIPELINE"
    
    local workflow_file="$PROJECT_ROOT/.github/workflows/ci-cd-pipeline.yml"
    if [[ -f "$workflow_file" ]]; then
        success "Pipeline CI/CD encontrado"
        validate_yaml_syntax "$workflow_file"
        
        # Verificar elementos clave del pipeline
        if grep -q "SAST" "$workflow_file"; then
            success "SAST configurado en pipeline"
        else
            warning "SAST no configurado en pipeline"
        fi
        
        if grep -q "DAST" "$workflow_file"; then
            success "DAST configurado en pipeline"
        else
            warning "DAST no configurado en pipeline"
        fi
        
        if grep -q "canary" "$workflow_file"; then
            success "Canary deployment configurado"
        else
            warning "Canary deployment no configurado"
        fi
    else
        error "Pipeline CI/CD faltante"
    fi
}

validate_documentation() {
    section "VALIDANDO DOCUMENTACIÓN"
    
    local docs=("README.md" "AZURE-DEPLOYMENT-GUIDE.md")
    
    for doc in "${docs[@]}"; do
        if [[ -f "$PROJECT_ROOT/$doc" ]]; then
            success "Documentación encontrada: $doc"
            local word_count=$(wc -w < "$PROJECT_ROOT/$doc")
            info "$doc contiene $word_count palabras"
        else
            warning "Documentación faltante: $doc"
        fi
    done
}

validate_azure_configurations() {
    section "VALIDANDO CONFIGURACIONES DE AZURE"
    
    local azure_files=(
        "k8s/azure-configurations.yaml"
        "azure-aks-validation.ps1"
        "helm/ecommerce-microservices/values-azure-production.yaml"
    )
    
    for file in "${azure_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            success "Configuración Azure encontrada: $file"
            if [[ "$file" == *.yaml ]]; then
                validate_yaml_syntax "$PROJECT_ROOT/$file"
            fi
        else
            error "Configuración Azure faltante: $file"
        fi
    done
}

check_dependencies() {
    section "VERIFICANDO DEPENDENCIAS"
    
    # Verificar herramientas necesarias
    local tools=("helm" "kubectl" "python3")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            success "$tool está instalado"
            local version=$($tool --version 2>/dev/null || echo "versión no disponible")
            info "$tool version: $version"
        else
            warning "$tool no está instalado"
        fi
    done
    
    # Verificar módulos de Python
    if python3 -c "import yaml" 2>/dev/null; then
        success "PyYAML está disponible"
    else
        warning "PyYAML no está disponible"
    fi
}

generate_final_report() {
    section "REPORTE FINAL DE VALIDACIÓN"
    
    local success_rate=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    fi
    
    info "Total de verificaciones: $TOTAL_CHECKS"
    success "Verificaciones exitosas: $PASSED_CHECKS"
    error "Verificaciones fallidas: $FAILED_CHECKS"
    info "Tasa de éxito: $success_rate%"
    
    log ""
    if [[ $success_rate -ge 90 ]]; then
        success "🎉 PROYECTO VALIDADO EXITOSAMENTE - Listo para despliegue"
        log "${GREEN}================================================================================================${NC}"
        log "${GREEN}✨ Tu aplicación ecommerce está LISTA para despliegue en Azure AKS${NC}"
        log "${GREEN}📊 Puntuación de calidad: $success_rate/100 - EXCELENTE${NC}"
        log "${GREEN}🚀 Puedes proceder con confianza al despliegue en producción${NC}"
        log "${GREEN}================================================================================================${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        warning "⚠️  PROYECTO MAYORMENTE VÁLIDO - Revisar elementos faltantes"
        log "${YELLOW}================================================================================================${NC}"
        log "${YELLOW}📊 Puntuación de calidad: $success_rate/100 - BUENO${NC}"
        log "${YELLOW}🔧 Algunos elementos necesitan atención antes del despliegue${NC}"
        log "${YELLOW}================================================================================================${NC}"
    else
        error "❌ PROYECTO NECESITA TRABAJO ADICIONAL"
        log "${RED}================================================================================================${NC}"
        log "${RED}📊 Puntuación de calidad: $success_rate/100 - REQUIERE MEJORAS${NC}"
        log "${RED}🚨 Varios elementos críticos deben ser corregidos antes del despliegue${NC}"
        log "${RED}================================================================================================${NC}"
    fi
    
    log ""
    info "Reporte completo guardado en: $VALIDATION_LOG"
    
    return $((success_rate < 75))
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    log "${BLUE}================================================================================================${NC}"
    log "${BLUE}🚀 INICIANDO VALIDACIÓN COMPLETA DEL PROYECTO ECOMMERCE MICROSERVICES${NC}"
    log "${BLUE}$(date)${NC}"
    log "${BLUE}================================================================================================${NC}"
    
    # Cambiar al directorio del proyecto
    cd "$PROJECT_ROOT" || {
        error "No se puede acceder al directorio del proyecto: $PROJECT_ROOT"
        exit 1
    }
    
    # Ejecutar todas las validaciones
    check_dependencies
    validate_project_structure
    validate_microservices
    validate_helm_charts
    validate_kubernetes_configs
    validate_ci_cd
    validate_azure_configurations
    validate_documentation
    
    # Generar reporte final
    generate_final_report
}

# Ejecutar script principal
main "$@"