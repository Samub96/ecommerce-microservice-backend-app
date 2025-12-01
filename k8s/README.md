# Kubernetes Deployment for Ecommerce Microservices

Este directorio contiene todos los manifiestos de Kubernetes necesarios para desplegar la aplicación de microservicios de ecommerce con un stack completo de monitoreo, seguridad y autoescalado.

## 📁 Estructura del Directorio

```
k8s/
├── namespaces/          # Definición de namespaces
├── configmaps/          # Configuraciones de aplicación
│   ├── api-gateway-proxy-centric.yaml
│   ├── eureka-client-config.yaml
│   ├── eureka-config.yaml
│   ├── microservices-config.yaml
│   └── zipkin-config.yaml
├── secrets/             # Datos sensibles (credenciales, tokens)
├── storage/             # Volúmenes persistentes
├── deployments/         # Definiciones de deployments
│   ├── all-microservices-v0.1.0.yaml
│   ├── business-services-deployment.yaml
│   └── support-services-deployment.yaml
├── services/            # Servicios de Kubernetes
│   ├── all-services-v0.1.0.yaml
│   └── infrastructure-services.yaml
├── ingress/            # Configuración de ingress
│   ├── api-gateway-ingress.yaml
│   ├── ingress.yaml
│   ├── nginx-ingress-controller.yaml
│   └── traefik-lightweight-ingress.yaml
├── autoscaling/        # Autoescaladores y optimización de recursos
│   ├── cluster-autoscaler.yaml
│   ├── eks-nodegroups-config-simple.yaml
│   ├── eks-nodegroups-config.yaml
│   ├── hpa-optimized-complete.yaml
│   └── resource-optimization.yaml
├── monitoring/         # Stack completo de monitoreo
│   ├── basic-dashboards.yaml
│   ├── cloud-config-external.yaml
│   ├── eureka-external.yaml
│   ├── grafana-config.yaml
│   ├── grafana-dashboards.yaml
│   ├── monitoring-unified-ingress.yaml
│   ├── prometheus-config.yaml
│   ├── prometheus-external.yaml
│   ├── prometheus-grafana.yaml
│   ├── prometheus-rbac.yaml
│   ├── servicemonitors-and-alerts.yaml
│   └── zipkin-external.yaml
├── dashboards/         # Dashboards de Grafana
├── logging/            # Stack de logging
├── security/           # Seguridad y políticas
│   ├── cert-manager.yaml
│   ├── network-policies-3tier.yaml
│   ├── network-policies.yaml
│   ├── pod-security-standards.yaml
│   ├── pod-security.yaml
│   ├── rbac.yaml
│   ├── sealed-secrets-controller.yaml
│   ├── secret-rotation-cronjob.yaml
│   ├── tls-certificates.yaml
│   └── vulnerability-scanning.yaml
└── scripts/            # Scripts de automatización
    ├── apply-config-secrets.sh
    ├── cleanup.sh
    ├── deploy-full.sh
    ├── deploy.sh
    └── rotate-secrets.sh
```

## 🚀 Estrategias de Deployment

### 📊 Estrategias Disponibles

1. **Rolling Update** (Por defecto) - Todos los servicios
2. **Canary Deployment** - Servicios orientados al cliente (implementado)

### 🐤 Canary Deployment

Los servicios orientados al cliente utilizan Canary deployment:

```bash
# Configurar canary deployment
helm upgrade --install ecommerce-canary ./helm/ecommerce-microservices \
  --set canary.enabled=true \
  --set canary.weight=10 \
  --set canary.analysis.enabled=true
```

## 🚀 Despliegue Rápido

### Prerrequisitos

1. **Kubernetes Cluster** funcionando (Minikube, Docker Desktop, EKS)
2. **kubectl** configurado y conectado al cluster
3. **Helm** v3.0+ instalado (para monitoreo)
4. **Nginx Ingress Controller** (opcional, para ingress)
5. **Cert-Manager** (para TLS automático)

### Despliegue Automático Completo

```bash
# Hacer los scripts ejecutables
chmod +x k8s/scripts/*.sh

# Despliegue completo con monitoreo y seguridad
./k8s/scripts/deploy-full.sh

# O despliegue básico
./k8s/scripts/deploy.sh
```

### Despliegue Manual por Componentes

```bash
# 1. Crear namespaces
kubectl apply -f k8s/namespaces/

# 2. Aplicar configuraciones de seguridad
kubectl apply -f k8s/security/rbac.yaml
kubectl apply -f k8s/security/pod-security-standards.yaml

# 3. Crear secrets y configmaps
kubectl apply -f k8s/secrets/
./k8s/scripts/apply-config-secrets.sh

# 4. Crear almacenamiento
kubectl apply -f k8s/storage/

# 5. Desplegar servicios de soporte (Zipkin, Eureka, etc.)
kubectl apply -f k8s/deployments/support-services-deployment.yaml
kubectl apply -f k8s/services/infrastructure-services.yaml

# Esperar que los servicios estén listos
kubectl wait --for=condition=ready pod -l app=zipkin -n ecommerce-dev --timeout=300s
kubectl wait --for=condition=ready pod -l app=service-discovery -n ecommerce-dev --timeout=300s

# 6. Desplegar microservicios de negocio
kubectl apply -f k8s/deployments/business-services-deployment.yaml
kubectl apply -f k8s/services/all-services-v0.1.0.yaml

# 7. Configurar autoescalado
kubectl apply -f k8s/autoscaling/hpa-optimized-complete.yaml
kubectl apply -f k8s/autoscaling/cluster-autoscaler.yaml

# 8. Desplegar stack de monitoreo (opcional)
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-grafana.yaml
kubectl apply -f k8s/monitoring/servicemonitors-and-alerts.yaml

# 9. Configurar ingress y seguridad de red
kubectl apply -f k8s/ingress/nginx-ingress-controller.yaml
kubectl apply -f k8s/ingress/api-gateway-ingress.yaml
kubectl apply -f k8s/security/network-policies-3tier.yaml

# 10. Configurar TLS y certificados
kubectl apply -f k8s/security/cert-manager.yaml
kubectl apply -f k8s/security/tls-certificates.yaml
```

## 🔍 Verificación y Monitoreo

### Comandos Útiles

```bash
# Ver todos los pods
kubectl get pods -n ecommerce-dev

# Ver todos los servicios
kubectl get svc -n ecommerce-dev

# Ver estado de los deployments
kubectl get deployments -n ecommerce-dev

# Ver logs de un servicio específico
kubectl logs -f deployment/api-gateway -n ecommerce-dev

# Describir un pod
kubectl describe pod <pod-name> -n ecommerce-dev
```

### Port Forwarding para Desarrollo

```bash
# API Gateway
kubectl port-forward svc/api-gateway-service 8080:8080 -n ecommerce-dev

# Zipkin UI
kubectl port-forward svc/zipkin-service 9411:9411 -n ecommerce-dev

# Eureka UI
kubectl port-forward svc/service-discovery-service 8761:8761 -n ecommerce-dev

# Cloud Config
kubectl port-forward svc/cloud-config-service 9296:9296 -n ecommerce-dev

# Prometheus (si está desplegado)
kubectl port-forward svc/prometheus-service 9090:9090 -n ecommerce-dev

# Grafana (si está desplegado)
kubectl port-forward svc/grafana-service 3000:3000 -n ecommerce-dev
```

### Acceso a Servicios

Después de hacer port-forward:

- **API Gateway**: http://localhost:8080
- **Zipkin UI**: http://localhost:9411
- **Eureka Dashboard**: http://localhost:8761
- **Cloud Config**: http://localhost:9296
- **Prometheus**: http://localhost:9090 (si está desplegado)
- **Grafana**: http://localhost:3000 (si está desplegado)
  - Usuario: admin
  - Password: admin (cambiar después del primer login)

### Acceso vía Ingress

Si tienes ingress configurado:

- **API Gateway**: https://api.ecommerce.local
- **Zipkin**: https://zipkin.ecommerce.local
- **Eureka**: https://eureka.ecommerce.local
- **Grafana**: https://grafana.ecommerce.local
- **Prometheus**: https://prometheus.ecommerce.local

## 📊 Autoescalado y Optimización

### Configuraciones Disponibles

- **hpa-optimized-complete.yaml**: HPA optimizado para todos los microservicios
- **cluster-autoscaler.yaml**: Autoescalador de cluster para AWS EKS
- **eks-nodegroups-config.yaml**: Configuración avanzada de grupos de nodos
- **resource-optimization.yaml**: Optimización de recursos y límites

Los siguientes servicios tienen autoescalado configurado:

- **API Gateway**: 2-10 réplicas (alta demanda)
- **User Service**: 2-8 réplicas
- **Product Service**: 2-8 réplicas  
- **Order Service**: 2-10 réplicas (crítico para negocio)
- **Payment Service**: 2-6 réplicas
- **Service Discovery**: 2-3 réplicas (alta disponibilidad)

### Métricas de Escalado

- **CPU**: 70-75% de utilización
- **Memoria**: 80% de utilización
- **Requests por segundo**: Configurado por servicio
- **Latencia**: P99 < 500ms para servicios críticos

## 📊 Monitoreo y Observabilidad

### Stack de Monitoreo Completo

- **Prometheus**: Recolección de métricas
- **Grafana**: Dashboards y visualización
- **Zipkin**: Tracing distribuido
- **AlertManager**: Gestión de alertas

### Dashboards Disponibles

- **basic-dashboards.yaml**: Dashboards básicos para microservicios
- **grafana-dashboards.yaml**: Dashboards avanzados de Grafana
- **servicemonitors-and-alerts.yaml**: ServiceMonitors y alertas de Prometheus

### Métricas Disponibles

Todos los servicios exponen métricas de Actuator:
- `/actuator/health` - Health checks
- `/actuator/info` - Información de la aplicación
- `/actuator/metrics` - Métricas detalladas
- `/actuator/prometheus` - Métricas en formato Prometheus

### Alertas Configuradas

- Alta utilización de CPU/Memoria
- Servicios no disponibles
- Latencia elevada (P99 > 1s)
- Errores HTTP 5xx elevados
- Circuit breakers abiertos

### Tracing Distribuido

Zipkin está configurado para recopilar traces de todos los microservicios:
- URL: http://zipkin-service:9411
- UI: Accesible vía port-forward o ingress
- Retención: 7 días de traces

## 🔧 Configuración

### Variables de Entorno Importantes

Definidas en ConfigMaps:

- `SPRING_PROFILES_ACTIVE`: kubernetes
- `SPRING_ZIPKIN_BASE_URL`: http://zipkin-service:9411
- `EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE`: http://service-discovery-service:8761/eureka/

### Secrets

**⚠️ IMPORTANTE**: Actualiza los secrets en `k8s/secrets/secrets.yaml` antes del despliegue:

```bash
# Codificar credenciales en base64
echo -n "tu-usuario" | base64
echo -n "tu-password" | base64

# Actualizar en el archivo secrets.yaml
```

## 🗑️ Limpieza

Para eliminar todos los recursos:

```bash
# Limpieza automática completa
./k8s/scripts/cleanup.sh

# O limpieza manual por componentes
kubectl delete namespace ecommerce-dev
kubectl delete namespace ecommerce-prod
kubectl delete namespace monitoring
kubectl delete clusterrolebinding ecommerce-rbac
kubectl delete clusterrole ecommerce-role

# Limpiar recursos de cluster
kubectl delete clusterissuer letsencrypt-prod
kubectl delete storageclass ecommerce-storage
```

## 🔒 Seguridad

### Componentes de Seguridad Implementados

#### Gestión de Certificados y TLS
- **cert-manager.yaml**: Gestión automática de certificados TLS
- **tls-certificates.yaml**: Configuración de certificados para servicios

#### Políticas de Red y Segmentación
- **network-policies.yaml**: Políticas básicas de red
- **network-policies-3tier.yaml**: Segmentación de red en 3 capas (frontend, backend, datos)

#### Seguridad de Pods y RBAC
- **rbac.yaml**: Control de acceso basado en roles
- **pod-security-standards.yaml**: Estándares de seguridad para pods
- **pod-security.yaml**: Políticas de seguridad adicionales

#### Gestión de Secretos
- **sealed-secrets-controller.yaml**: Controlador de Sealed Secrets
- **secret-rotation-cronjob.yaml**: Rotación automática de secretos
- **vulnerability-scanning.yaml**: Escaneo de vulnerabilidades

### Buenas Prácticas Implementadas

1. **Usuarios no-root** en todos los contenedores
2. **Resource limits** y requests definidos
3. **Secrets** para datos sensibles
4. **Network policies** implementadas
5. **RBAC** configurado
6. **Pod security standards** aplicados
7. **TLS** automático con cert-manager
8. **Sealed Secrets** para secretos en GitOps

### Para Producción

Antes de desplegar en producción:

1. **Actualizar secrets** con valores reales
2. **Configurar TLS** en todos los servicios
3. **Activar network policies**
4. **Configurar RBAC específico**
5. **Activar logging y monitoring**
6. **Configurar backups automáticos**
7. **Implementar escaneo de vulnerabilidades**
8. **Configurar rotación de secretos**

## 🔧 Scripts de Automatización

### Scripts Disponibles

- **deploy.sh**: Despliegue básico de microservicios
- **deploy-full.sh**: Despliegue completo con monitoreo y seguridad
- **cleanup.sh**: Limpieza completa del cluster
- **apply-config-secrets.sh**: Aplicación de configuraciones y secretos
- **rotate-secrets.sh**: Rotación manual de secretos

### Uso de Scripts

```bash
# Hacer scripts ejecutables
chmod +x k8s/scripts/*.sh

# Despliegue completo
./k8s/scripts/deploy-full.sh

# Limpieza
./k8s/scripts/cleanup.sh

# Rotación de secretos
./k8s/scripts/rotate-secrets.sh
```

## 🆘 Troubleshooting

### Problemas Comunes

1. **Pods en estado Pending**
   ```bash
   kubectl describe pod <pod-name> -n ecommerce-dev
   # Verificar recursos disponibles y storage classes
   kubectl top nodes
   kubectl get storageclass
   ```

2. **ImagePullBackOff**
   ```bash
   # Verificar que las imágenes existan en Docker Hub
   # Verificar secrets de Docker registry
   kubectl get secret docker-registry-secret -n ecommerce-dev -o yaml
   
   # Verificar configuración de imagen
   kubectl describe pod <pod-name> -n ecommerce-dev
   ```

3. **Service Discovery Issues**
   ```bash
   # Verificar logs de Eureka
   kubectl logs deployment/service-discovery -n ecommerce-dev
   
   # Verificar configuración de servicios
   kubectl get svc -n ecommerce-dev
   
   # Verificar endpoints
   kubectl get endpoints -n ecommerce-dev
   ```

4. **Problemas de Red y Conectividad**
   ```bash
   # Probar conectividad entre pods
   kubectl exec -it <pod-name> -n ecommerce-dev -- nslookup service-discovery-service
   
   # Verificar network policies
   kubectl get networkpolicy -n ecommerce-dev
   
   # Verificar DNS
   kubectl exec -it <pod-name> -n ecommerce-dev -- cat /etc/resolv.conf
   ```

5. **Problemas de Monitoreo**
   ```bash
   # Verificar ServiceMonitors
   kubectl get servicemonitor -n ecommerce-dev
   
   # Verificar targets en Prometheus
   kubectl port-forward svc/prometheus-service 9090:9090 -n ecommerce-dev
   # Ir a http://localhost:9090/targets
   
   # Verificar logs de Grafana
   kubectl logs deployment/grafana -n ecommerce-dev
   ```

6. **Problemas de Seguridad y Certificados**
   ```bash
   # Verificar certificados
   kubectl get certificates -n ecommerce-dev
   kubectl describe certificate <cert-name> -n ecommerce-dev
   
   # Verificar cert-manager
   kubectl get clusterissuer
   kubectl logs deployment/cert-manager -n cert-manager
   
   # Verificar sealed secrets
   kubectl get sealedsecrets -n ecommerce-dev
   ```

### Logs Útiles

```bash
# Ver logs de todos los containers de un deployment
kubectl logs deployment/api-gateway -n ecommerce-dev --all-containers=true

# Seguir logs en tiempo real
kubectl logs -f deployment/api-gateway -n ecommerce-dev

# Ver logs previos después de un restart
kubectl logs deployment/api-gateway -n ecommerce-dev --previous

# Logs de múltiples servicios
kubectl logs -f -l tier=backend -n ecommerce-dev

# Logs con timestamp
kubectl logs deployment/api-gateway -n ecommerce-dev --timestamps=true
```

### Comandos de Diagnóstico Avanzados

```bash
# Verificar recursos del cluster
kubectl top nodes
kubectl top pods -n ecommerce-dev

# Verificar eventos del cluster
kubectl get events --sort-by='.lastTimestamp' -n ecommerce-dev

# Verificar configuración de HPA
kubectl get hpa -n ecommerce-dev
kubectl describe hpa <hpa-name> -n ecommerce-dev

# Verificar configuración de ingress
kubectl get ingress -n ecommerce-dev
kubectl describe ingress <ingress-name> -n ecommerce-dev

# Verificar estado de cluster autoscaler (EKS)
kubectl logs deployment/cluster-autoscaler -n kube-system

# Verificar métricas de pods
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

## 🔄 Actualizaciones

Para actualizar un servicio:

```bash
# Actualizar imagen
kubectl set image deployment/api-gateway api-gateway=nuevo-tag -n ecommerce-dev

# Reiniciar deployment
kubectl rollout restart deployment/api-gateway -n ecommerce-dev

# Ver estado del rollout
kubectl rollout status deployment/api-gateway -n ecommerce-dev

# Rollback si es necesario
kubectl rollout undo deployment/api-gateway -n ecommerce-dev
```