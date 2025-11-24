#!/bin/bash

# ============================================================================
# DESPLIEGUE AWS EKS - SIN SUDO
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
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account ID: $ACCOUNT_ID"
echo "✅ Región: $REGION"

# ============================================================================
# 2. INSTALAR EKSCTL (sin sudo)
# ============================================================================
echo "📋 Paso 2: Instalando eksctl..."

if ! command -v eksctl &> /dev/null; then
    echo "📦 Instalando eksctl en directorio local..."
    mkdir -p ~/bin
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C ~/bin
    export PATH=$PATH:~/bin
    echo "✅ eksctl instalado"
else
    echo "✅ eksctl ya está instalado"
fi

# ============================================================================
# 3. CREAR CONFIGURACIÓN DE CLUSTER
# ============================================================================
echo "📋 Paso 3: Creando configuración de cluster..."

cat > eks-cluster-config.yaml << EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME
  region: $REGION

nodeGroups:
  - name: ecommerce-nodes
    instanceType: $NODE_TYPE
    desiredCapacity: $NODE_COUNT
    minSize: 1
    maxSize: 4
    volumeSize: 20
    ssh:
      allow: false
    iam:
      withAddonPolicies:
        autoScaler: true
        ebs: true
        efs: true
        awsLoadBalancerController: true
        cloudWatch: true

addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy
  - name: aws-ebs-csi-driver

cloudWatch:
  clusterLogging:
    enable: true
    logTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
EOF

echo "✅ Configuración de cluster creada"

# ============================================================================
# 4. CREAR CLUSTER EKS  
# ============================================================================
echo "📋 Paso 4: Creando cluster EKS..."

# Verificar si el cluster ya existe
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION > /dev/null 2>&1; then
    echo "✅ Cluster $CLUSTER_NAME ya existe"
else
    echo "🏗️ Creando cluster EKS: $CLUSTER_NAME"
    echo "⏰ Esto puede tomar 15-20 minutos..."
    
    ~/bin/eksctl create cluster -f eks-cluster-config.yaml
    
    echo "✅ Cluster EKS creado exitosamente"
fi

# Actualizar kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verificar conexión
echo "📊 Verificando cluster:"
kubectl get nodes

# ============================================================================
# 5. CONFIGURAR ECR
# ============================================================================
echo "📋 Paso 5: Configurando ECR..."

# Login a ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Lista de microservicios core (empezamos con pocos)
core_services=("api-gateway" "service-discovery" "cloud-config" "user-service" "product-service")

# Crear repositorios ECR para servicios core
for service in "\${core_services[@]}"; do
    if ! aws ecr describe-repositories --repository-names "$ECR_REPO_PREFIX/$service" --region $REGION > /dev/null 2>&1; then
        echo "📦 Creando repositorio ECR para $service..."
        aws ecr create-repository --repository-name "$ECR_REPO_PREFIX/$service" --region $REGION --image-scanning-configuration scanOnPush=true
    else
        echo "✅ Repositorio ECR para $service ya existe"
    fi
done

# ============================================================================
# 6. CONSTRUIR Y SUBIR IMÁGENES CORE
# ============================================================================
echo "📋 Paso 6: Construyendo y subiendo imágenes core..."

ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

for service in "\${core_services[@]}"; do
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
# 7. INSTALAR AWS LOAD BALANCER CONTROLLER
# ============================================================================
echo "📋 Paso 7: Instalando AWS Load Balancer Controller..."

# Crear IAM service account
~/bin/eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --approve \
  --region=$REGION \
  --override-existing-serviceaccounts

# Verificar que Helm esté instalado
if ! command -v helm &> /dev/null; then
    echo "📦 Instalando Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Instalar con Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Obtener VPC ID
VPC_ID=\$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query cluster.resourcesVpcConfig.vpcId --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$VPC_ID

echo "✅ AWS Load Balancer Controller instalado"

# ============================================================================
# 8. CREAR CONFIGURACIÓN HELM PARA AWS
# ============================================================================
echo "📋 Paso 8: Creando configuración Helm..."

cat > helm/ecommerce-microservices/values-aws-core.yaml << EOF
# ======================================
# CONFIGURACIÓN CORE PARA AWS EKS
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

# ======================================
# SERVICIOS CORE HABILITADOS
# ======================================
microservices:
  # Infraestructura
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
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  # Servicios de negocio básicos
  user-service:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  product-service:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  # Deshabilitar otros servicios para esta fase
  order-service:
    enabled: false
  payment-service:
    enabled: false
  shipping-service:
    enabled: false
  favourite-service:
    enabled: false
  proxy-client:
    enabled: false

# ======================================
# CONFIGURACIÓN SIMPLIFICADA
# ======================================
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'

# Monitoreo deshabilitado para esta fase
monitoring:
  prometheus:
    enabled: false
  grafana:
    enabled: false

# Autoscaling básico
autoscaling:
  hpa:
    enabled: true
  keda:
    enabled: false
EOF

echo "✅ Configuración Helm creada"

# ============================================================================
# 9. DESPLEGAR SERVICIOS CORE
# ============================================================================
echo "📋 Paso 9: Desplegando servicios core..."

# Crear namespace
kubectl create namespace ecommerce-production --dry-run=client -o yaml | kubectl apply -f -

# Desplegar con Helm
echo "🚀 Desplegando con Helm..."
helm upgrade --install ecommerce-app helm/ecommerce-microservices/ \
    --namespace ecommerce-production \
    --values helm/ecommerce-microservices/values-aws-core.yaml \
    --wait \
    --timeout=10m

# ============================================================================
# 10. VERIFICAR DESPLIEGUE
# ============================================================================
echo "📋 Paso 10: Verificando despliegue..."

echo "📊 Estado de los pods:"
kubectl get pods -n ecommerce-production

echo "🌐 Servicios:"
kubectl get services -n ecommerce-production

echo "🔗 Ingress:"
kubectl get ingress -n ecommerce-production

# ============================================================================
# INFORMACIÓN FINAL
# ============================================================================
echo ""
echo "🎉 ¡DESPLIEGUE CORE EN AWS EKS COMPLETADO!"
echo "=========================================="
echo "🏗️ Cluster EKS: $CLUSTER_NAME"
echo "🌐 Región: $REGION"
echo "📦 ECR: $ECR_URI/$ECR_REPO_PREFIX"
echo "🌍 Namespace: ecommerce-production"
echo ""
echo "📋 Servicios desplegados:"
echo "  ✅ service-discovery"
echo "  ✅ cloud-config"
echo "  ✅ api-gateway"
echo "  ✅ user-service"
echo "  ✅ product-service"
echo ""
echo "🔧 Para expandir a todos los servicios:"
echo "  ./deploy-aws-full.sh"
echo ""
echo "💰 Para limpiar recursos:"
echo "  helm uninstall ecommerce-app -n ecommerce-production"
echo "  ~/bin/eksctl delete cluster --name $CLUSTER_NAME --region $REGION"
EOF