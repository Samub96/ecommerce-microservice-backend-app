#!/bin/bash
# ============================================================================
# AWS CREDENTIALS SETUP - SECURE CONFIGURATION
# ============================================================================

set -e

echo "🔧 Configurando credenciales AWS de forma segura..."

# Función para configurar credenciales desde variables de entorno
setup_env_credentials() {
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "✅ Usando credenciales desde variables de entorno"
        
        # Configurar AWS CLI
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
        aws configure set region "${AWS_DEFAULT_REGION:-us-east-1}"
        
        if [ -n "$AWS_SESSION_TOKEN" ]; then
            aws configure set aws_session_token "$AWS_SESSION_TOKEN"
            echo "✅ Session token configurado (credenciales temporales)"
        fi
        
        return 0
    fi
    return 1
}

# Función para configurar credenciales desde archivo
setup_file_credentials() {
    if [ -f "aws-credentials.txt" ]; then
        echo "📄 Configurando desde aws-credentials.txt..."
        
        # Leer credenciales del archivo
        export AWS_SHARED_CREDENTIALS_FILE=$(pwd)/aws-credentials.txt
        export AWS_PROFILE=default
        
        echo "✅ Credenciales cargadas desde archivo"
        return 0
    fi
    return 1
}

# Función para configuración interactiva
setup_interactive() {
    echo "🔧 Configuración interactiva de AWS..."
    echo "Por favor ingresa tus credenciales AWS:"
    
    read -p "AWS Access Key ID: " access_key
    read -s -p "AWS Secret Access Key: " secret_key
    echo
    read -s -p "AWS Session Token (opcional, para sandbox): " session_token
    echo
    read -p "Región (default: us-east-1): " region
    
    region=${region:-us-east-1}
    
    aws configure set aws_access_key_id "$access_key"
    aws configure set aws_secret_access_key "$secret_key"
    aws configure set region "$region"
    
    if [ -n "$session_token" ]; then
        aws configure set aws_session_token "$session_token"
    fi
    
    echo "✅ Credenciales configuradas interactivamente"
}

# ============================================================================
# CONFIGURACIÓN PRINCIPAL
# ============================================================================

echo "🔍 Verificando métodos de configuración disponibles..."

if setup_env_credentials; then
    echo "✅ Configuración exitosa desde variables de entorno"
elif setup_file_credentials; then
    echo "✅ Configuración exitosa desde archivo"
else
    echo "⚠️  No se encontraron credenciales preconfiguradas"
    echo "📝 Opciones disponibles:"
    echo "   1. Exportar variables de entorno:"
    echo "      export AWS_ACCESS_KEY_ID='tu_access_key'"
    echo "      export AWS_SECRET_ACCESS_KEY='tu_secret_key'"
    echo "      export AWS_SESSION_TOKEN='tu_session_token'  # Para sandbox"
    echo ""
    echo "   2. Crear archivo aws-credentials.txt:"
    echo "      cp aws-credentials-template.txt aws-credentials.txt"
    echo "      # Editar el archivo con tus credenciales"
    echo ""
    echo "   3. Configuración interactiva:"
    read -p "¿Configurar credenciales interactivamente? (y/n): " response
    
    if [[ "$response" =~ ^[yY] ]]; then
        setup_interactive
    else
        echo "❌ Configuración cancelada"
        exit 1
    fi
fi

# ============================================================================
# VERIFICACIÓN
# ============================================================================

echo "🔍 Verificando configuración..."

if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    
    echo "✅ Configuración AWS exitosa"
    echo "📋 Account ID: $ACCOUNT_ID"
    echo "👤 User/Role: $USER_ARN"
    
    # Verificar permisos mínimos
    echo "🔍 Verificando permisos..."
    
    if aws eks list-clusters > /dev/null 2>&1; then
        echo "✅ Permisos EKS verificados"
    else
        echo "⚠️  Permisos limitados para EKS - puede funcionar con limitaciones"
    fi
    
    if aws ecr describe-repositories > /dev/null 2>&1; then
        echo "✅ Permisos ECR verificados"
    else
        echo "⚠️  Permisos limitados para ECR - puede funcionar con limitaciones"
    fi
    
else
    echo "❌ Error: No se puede verificar la configuración AWS"
    echo "💡 Verifica tus credenciales e inténtalo de nuevo"
    exit 1
fi

echo ""
echo "🎉 ¡Configuración AWS completada exitosamente!"
echo "🚀 Puedes proceder con el deployment usando ./deploy-aws-eks.sh"