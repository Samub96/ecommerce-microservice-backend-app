#!/bin/bash

# ============================================================================
# DESPLIEGUE COMPLETO EN AWS EKS 
# Proyecto E-commerce Microservices - Optimizado para Sandbox
# ============================================================================

set -e

# Configuración
CLUSTER_NAME="ecommerce-eks-cluster"
REGION="us-east-1"
NODE_TYPE="t3.medium"
NODE_COUNT=2
ECR_REPO_PREFIX="ecommerce"

echo "🚀 Desplegando E-commerce Microservices en AWS EKS..."
echo "======================================================"

# ============================================================================
# 1. VERIFICAR CONFIGURACIÓN AWS
# ============================================================================
echo "📋 Paso 1: Verificando configuración AWS..."

# Verificar credenciales
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ Error: AWS CLI no configurado correctamente"
    echo "💡 Ejecuta: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account ID: $ACCOUNT_ID"
echo "✅ Región: $REGION"

# ============================================================================
# 2. CREAR CLUSTER EKS
# ============================================================================
echo "📋 Paso 2: Creando cluster EKS..."

# Verificar si eksctl está instalado
if ! command -v eksctl &> /dev/null; then
    echo "📦 Instalando eksctl..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    echo "✅ eksctl instalado"
fi

# Verificar si el cluster ya existe
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION > /dev/null 2>&1; then
    echo "✅ Cluster $CLUSTER_NAME ya existe"
else
    echo "🏗️ Creando cluster EKS: $CLUSTER_NAME"
    echo "⏰ Esto puede tomar 15-20 minutos..."
    
    eksctl create cluster \
        --name=$CLUSTER_NAME \
        --region=$REGION \
        --nodegroup-name=ecommerce-nodes \
        --node-type=$NODE_TYPE \
        --nodes=$NODE_COUNT \
        --nodes-min=1 \
        --nodes-max=4 \
        --managed \
        --version=1.28
        
    echo "✅ Cluster EKS creado exitosamente"
fi

# Actualizar kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verificar conexión
echo "📊 Verificando cluster:"
kubectl get nodes

# ============================================================================
# 3. CONFIGURAR ECR (Elastic Container Registry)
# ============================================================================
echo "📋 Paso 3: Configurando ECR..."

# Login a ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Lista de microservicios
services=("api-gateway" "service-discovery" "cloud-config" "proxy-client" "user-service" "product-service" "favourite-service" "order-service" "shipping-service" "payment-service")

# Crear repositorios ECR para cada servicio
for service in "${services[@]}"; do
    if ! aws ecr describe-repositories --repository-names "$ECR_REPO_PREFIX/$service" --region $REGION > /dev/null 2>&1; then
        echo "📦 Creando repositorio ECR para $service..."
        aws ecr create-repository --repository-name "$ECR_REPO_PREFIX/$service" --region $REGION
    else
        echo "✅ Repositorio ECR para $service ya existe"
    fi
done

# ============================================================================
# 4. CONSTRUIR Y SUBIR IMÁGENES DOCKER
# ============================================================================
echo "📋 Paso 4: Construyendo y subiendo imágenes..."

ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

for service in "${services[@]}"; do
    if [ -f "$service/Dockerfile" ]; then
        echo "🔨 Construyendo $service..."
        
        # Construir imagen
        docker build -t "$ECR_REPO_PREFIX/$service:latest" "$service/"
        
        # Tag para ECR
        docker tag "$ECR_REPO_PREFIX/$service:latest" "$ECR_URI/$ECR_REPO_PREFIX/$service:latest"
        
        # Subir a ECR
        docker push "$ECR_URI/$ECR_REPO_PREFIX/$service:latest"
        
        echo "✅ $service subido a ECR"
    else
        echo "⚠️ Dockerfile no encontrado para $service"
    fi
done

# ============================================================================
# 5. INSTALAR CONTROLADORES NECESARIOS
# ============================================================================
echo "📋 Paso 5: Instalando controladores..."

# Instalar AWS Load Balancer Controller
echo "🌐 Instalando AWS Load Balancer Controller..."

# Crear IAM service account
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --approve \
  --region=$REGION

# Instalar con Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query cluster.resourcesVpcConfig.vpcId --output text)

# Verificar instalación
kubectl get deployment -n kube-system aws-load-balancer-controller

# ============================================================================
# 6. ACTUALIZAR CONFIGURACIÓN HELM
# ============================================================================
echo "📋 Paso 6: Actualizando configuración Helm..."

# Crear values específicos para AWS
cat > helm/ecommerce-microservices/values-aws.yaml << EOF
# ======================================
# CONFIGURACIÓN PARA AWS EKS
# ======================================
global:
  registry: "$ECR_URI/$ECR_REPO_PREFIX"
  imageTag: "latest"
  imagePullPolicy: "Always"
  environment: "production"
  namespace: "ecommerce-production"

# Configuración específica de AWS
aws:
  region: "$REGION"
  accountId: "$ACCOUNT_ID"

# Configuración de Ingress para AWS ALB
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: '443'

# Storage Class para AWS EBS
storageClass:
  name: gp3
  provisioner: ebs.csi.aws.com
  parameters:
    type: gp3
    fsType: ext4

# ======================================
# MICROSERVICIOS CON RECURSOS OPTIMIZADOS
# ======================================
microservices:
  service-discovery:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  cloud-config:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  api-gateway:
    enabled: true
    replicas: 2
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  user-service:
    enabled: true
    replicas: 2
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  product-service:
    enabled: true
    replicas: 2
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  order-service:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  payment-service:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  shipping-service:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  favourite-service:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  proxy-client:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

# ======================================
# MONITOREO HABILITADO PARA PRODUCTION
# ======================================
monitoring:
  prometheus:
    enabled: true
    storageSize: "10Gi"
  grafana:
    enabled: true
    storageSize: "5Gi"

# ======================================
# AUTOSCALING HABILITADO
# ======================================
autoscaling:
  hpa:
    enabled: true
  keda:
    enabled: false  # Simplificar primera versión
EOF

echo "✅ Configuración AWS creada"

# ============================================================================
# 7. DESPLEGAR APLICACIÓN CON HELM
# ============================================================================
echo "📋 Paso 7: Desplegando aplicación..."

# Crear namespace
kubectl create namespace ecommerce-production --dry-run=client -o yaml | kubectl apply -f -

# Desplegar con Helm usando configuración AWS
echo "🚀 Desplegando con Helm..."
helm upgrade --install ecommerce-app helm/ecommerce-microservices/ \
    --namespace ecommerce-production \
    --values helm/ecommerce-microservices/values-aws.yaml \
    --wait \
    --timeout=15m

# ============================================================================
# 8. VERIFICAR DESPLIEGUE
# ============================================================================
echo "📋 Paso 8: Verificando despliegue..."

echo "📊 Estado de los pods:"
kubectl get pods -n ecommerce-production

echo "🌐 Servicios:"
kubectl get services -n ecommerce-production

echo "🔗 Ingress:"
kubectl get ingress -n ecommerce-production

# Obtener URL del Load Balancer
echo "🔍 Obteniendo URL de acceso..."
ALB_URL=$(kubectl get ingress -n ecommerce-production ecommerce-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Configurando...")

if [ "$ALB_URL" != "Configurando..." ] && [ ! -z "$ALB_URL" ]; then
    echo "✅ URL de acceso: https://$ALB_URL"
    echo "🌐 API Gateway: https://$ALB_URL/api/gateway/actuator/health"
else
    echo "⏰ ALB configurándose, espera unos minutos..."
    echo "💡 Ejecuta: kubectl get ingress -n ecommerce-production -w"
fi

# ============================================================================
# INFORMACIÓN FINAL
# ============================================================================
echo ""
echo "🎉 ¡DESPLIEGUE EN AWS EKS COMPLETADO!"
echo "====================================="
echo "🏗️ Cluster EKS: $CLUSTER_NAME"
echo "🌐 Región: $REGION"
echo "📦 ECR: $ECR_URI/$ECR_REPO_PREFIX"
echo "🌍 Namespace: ecommerce-production"
echo ""
echo "📋 Comandos útiles:"
echo "  kubectl get all -n ecommerce-production"
echo "  kubectl logs -f deployment/api-gateway -n ecommerce-production"
echo "  helm status ecommerce-app -n ecommerce-production"
echo ""
echo "🔧 Para monitoreo:"
echo "  kubectl port-forward svc/prometheus-server 9090:80 -n ecommerce-production"
echo "  kubectl port-forward svc/grafana 3000:80 -n ecommerce-production"
echo ""
echo "💰 Para limpiar recursos:"
echo "  helm uninstall ecommerce-app -n ecommerce-production"
echo "  eksctl delete cluster --name $CLUSTER_NAME --region $REGION"