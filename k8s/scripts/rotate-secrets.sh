# Script para rotar secretos automáticamente
#!/bin/bash

# Script de rotación de secretos para ecommerce microservices
# Ejecutar como CronJob cada semana

set -e

echo "🔄 Iniciando rotación de secretos..."

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Función para generar password seguro
generate_password() {
    openssl rand -base64 32
}

# Función para generar JWT secret
generate_jwt_secret() {
    openssl rand -hex 64
}

# Verificar herramientas necesarias
check_tools() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está disponible"
        exit 1
    fi
    
    if ! command -v kubeseal &> /dev/null; then
        print_error "kubeseal no está disponible"
        exit 1
    fi
    
    print_status "Herramientas verificadas"
}

# Rotar secretos de base de datos
rotate_database_secrets() {
    echo "🗄️  Rotando secretos de base de datos..."
    
    NEW_MYSQL_PASSWORD=$(generate_password)
    NEW_MYSQL_ROOT_PASSWORD=$(generate_password)
    
    # Crear nuevo sealed secret para MySQL
    kubectl create secret generic database-secrets-new \
        --from-literal=mysql-password="$NEW_MYSQL_PASSWORD" \
        --from-literal=mysql-root-password="$NEW_MYSQL_ROOT_PASSWORD" \
        --dry-run=client -o yaml | \
    kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller \
        --format yaml --name database-sealed-secrets --namespace ecommerce-dev > /tmp/database-sealed-new.yaml
    
    # Aplicar el nuevo secret
    kubectl apply -f /tmp/database-sealed-new.yaml
    
    # Verificar que se creó correctamente
    if kubectl get secret database-sealed-secrets -n ecommerce-dev &> /dev/null; then
        print_status "Secretos de base de datos rotados exitosamente"
        
        # Reiniciar pods que usan estos secretos (esto activará rolling update)
        kubectl rollout restart deployment/user-service -n ecommerce-dev
        kubectl rollout restart deployment/product-service -n ecommerce-dev
        kubectl rollout restart deployment/order-service -n ecommerce-dev
        
        print_status "Pods reiniciados para aplicar nuevos secretos"
    else
        print_error "Error al rotar secretos de base de datos"
        return 1
    fi
    
    # Limpiar archivos temporales
    rm -f /tmp/database-sealed-new.yaml
}

# Rotar secretos JWT
rotate_jwt_secrets() {
    echo "🔑 Rotando secretos JWT..."
    
    NEW_JWT_SECRET=$(generate_jwt_secret)
    NEW_JWT_SIGNING_KEY=$(generate_jwt_secret)
    
    # Crear nuevo sealed secret para JWT
    kubectl create secret generic jwt-secrets-new \
        --from-literal=jwt-secret="$NEW_JWT_SECRET" \
        --from-literal=jwt-signing-key="$NEW_JWT_SIGNING_KEY" \
        --dry-run=client -o yaml | \
    kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller \
        --format yaml --name jwt-sealed-secrets --namespace ecommerce-dev > /tmp/jwt-sealed-new.yaml
    
    # Aplicar el nuevo secret
    kubectl apply -f /tmp/jwt-sealed-new.yaml
    
    if kubectl get secret jwt-sealed-secrets -n ecommerce-dev &> /dev/null; then
        print_status "Secretos JWT rotados exitosamente"
        
        # Reiniciar servicios que usan JWT
        kubectl rollout restart deployment/api-gateway -n ecommerce-dev
        kubectl rollout restart deployment/user-service -n ecommerce-dev
        
        print_status "Servicios de autenticación reiniciados"
    else
        print_error "Error al rotar secretos JWT"
        return 1
    fi
    
    rm -f /tmp/jwt-sealed-new.yaml
}

# Rotar certificados TLS
rotate_tls_certificates() {
    echo "🔒 Rotando certificados TLS..."
    
    # Forzar renovación de certificados Let's Encrypt
    kubectl delete certificate api-gateway-tls -n ecommerce-dev --ignore-not-found=true
    kubectl delete certificate admin-services-tls -n ecommerce-dev --ignore-not-found=true
    
    # Los certificados se recrearán automáticamente por cert-manager
    sleep 10
    
    # Verificar que los nuevos certificados están listos
    echo "⏳ Esperando que los certificados estén listos..."
    kubectl wait --for=condition=Ready certificate/api-gateway-tls -n ecommerce-dev --timeout=300s
    kubectl wait --for=condition=Ready certificate/admin-services-tls -n ecommerce-dev --timeout=300s
    
    print_status "Certificados TLS renovados exitosamente"
}

# Función principal
main() {
    echo "🚀 Rotación de secretos para Ecommerce Microservices"
    echo "Fecha: $(date)"
    echo "Namespace: ecommerce-dev"
    echo "---"
    
    check_tools
    
    # Ejecutar rotaciones
    rotate_jwt_secrets
    sleep 30  # Esperar para que los pods se estabilicen
    
    rotate_database_secrets
    sleep 30
    
    rotate_tls_certificates
    
    echo "---"
    print_status "✨ Rotación de secretos completada exitosamente!"
    
    # Generar reporte
    echo "📊 Reporte de rotación:"
    echo "- JWT Secrets: ✅ Rotados"
    echo "- Database Secrets: ✅ Rotados"
    echo "- TLS Certificates: ✅ Renovados"
    echo "- Deployments actualizados: $(kubectl get deployments -n ecommerce-dev -o name | wc -l)"
    echo "- Fecha completada: $(date)"
}

# Ejecutar función principal
main "$@"