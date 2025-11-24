# Kubernetes Deployment for Ecommerce Microservices

Este directorio contiene todos los manifiestos de Kubernetes necesarios para desplegar la aplicación de microservicios de ecommerce.

## 📁 Estructura del Directorio

```
k8s/
├── namespaces/          # Definición de namespaces
├── configmaps/          # Configuraciones de aplicación
├── secrets/             # Datos sensibles (credenciales, tokens)
├── storage/             # Volúmenes persistentes
├── deployments/         # Definiciones de deployments
├── services/            # Servicios de Kubernetes
├── ingress/            # Configuración de ingress
├── autoscaling/        # Autoescaladores horizontales
└── scripts/            # Scripts de automatización
```

## 🚀 Despliegue Rápido

### Prerrequisitos

1. **Kubernetes Cluster** funcionando (Minikube, Docker Desktop, etc.)
2. **kubectl** configurado y conectado al cluster
3. **Nginx Ingress Controller** (opcional, para ingress)

### Despliegue Automático

```bash
# Hacer el script ejecutable
chmod +x k8s/scripts/deploy.sh

# Ejecutar despliegue completo
./k8s/scripts/deploy.sh
```

### Despliegue Manual

```bash
# 1. Crear namespaces
kubectl apply -f k8s/namespaces/

# 2. Crear secrets y configmaps
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# 3. Crear almacenamiento
kubectl apply -f k8s/storage/

# 4. Desplegar servicios de infraestructura
kubectl apply -f k8s/deployments/zipkin-deployment.yaml
kubectl apply -f k8s/services/infrastructure-services.yaml

# Esperar que Zipkin esté listo
kubectl wait --for=condition=ready pod -l app=zipkin -n ecommerce-dev --timeout=300s

# 5. Desplegar Service Discovery
kubectl apply -f k8s/deployments/service-discovery-deployment.yaml
kubectl wait --for=condition=ready pod -l app=service-discovery -n ecommerce-dev --timeout=300s

# 6. Desplegar Cloud Config
kubectl apply -f k8s/deployments/cloud-config-deployment.yaml
kubectl wait --for=condition=ready pod -l app=cloud-config -n ecommerce-dev --timeout=300s

# 7. Desplegar API Gateway
kubectl apply -f k8s/deployments/api-gateway-deployment.yaml
kubectl apply -f k8s/services/application-services.yaml

# 8. Desplegar microservicios
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/

# 9. Configurar ingress (opcional)
kubectl apply -f k8s/ingress/

# 10. Configurar autoescalado
kubectl apply -f k8s/autoscaling/
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
```

### Acceso a Servicios

Después de hacer port-forward:

- **API Gateway**: http://localhost:8080
- **Zipkin UI**: http://localhost:9411
- **Eureka Dashboard**: http://localhost:8761
- **Cloud Config**: http://localhost:9296

## 📊 Autoescalado

Los siguientes servicios tienen autoescalado configurado:

- **API Gateway**: 2-10 réplicas
- **User Service**: 2-8 réplicas
- **Product Service**: 2-8 réplicas
- **Order Service**: 2-10 réplicas

Métricas de escalado:
- CPU: 70-75% de utilización
- Memoria: 80% de utilización

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
# Limpieza automática
chmod +x k8s/scripts/cleanup.sh
./k8s/scripts/cleanup.sh

# O manual
kubectl delete namespace ecommerce-dev
kubectl delete namespace ecommerce-prod
```

## 🔒 Seguridad

### Buenas Prácticas Implementadas

1. **Usuarios no-root** en todos los contenedores
2. **Resource limits** y requests definidos
3. **Secrets** para datos sensibles
4. **Network policies** (por implementar)
5. **RBAC** (por implementar)

### Para Producción

Antes de desplegar en producción:

1. **Actualizar secrets** con valores reales
2. **Configurar TLS** en ingress
3. **Implementar network policies**
4. **Configurar RBAC**
5. **Activar logging y monitoring**
6. **Configurar backups**

## 📈 Monitoreo y Logging

### Métricas Disponibles

Todos los servicios exponen métricas de Actuator:
- `/actuator/health` - Health checks
- `/actuator/info` - Información de la aplicación
- `/actuator/metrics` - Métricas detalladas
- `/actuator/prometheus` - Métricas en formato Prometheus

### Tracing Distribuido

Zipkin está configurado para recopilar traces de todos los microservicios:
- URL: http://zipkin-service:9411
- UI: Accesible vía port-forward en http://localhost:9411

## 🆘 Troubleshooting

### Problemas Comunes

1. **Pods en estado Pending**
   ```bash
   kubectl describe pod <pod-name> -n ecommerce-dev
   # Verificar recursos disponibles y storage classes
   ```

2. **ImagePullBackOff**
   ```bash
   # Verificar que las imágenes existan en Docker Hub
   # Verificar secrets de Docker registry
   kubectl get secret docker-registry-secret -n ecommerce-dev -o yaml
   ```

3. **Service Discovery Issues**
   ```bash
   # Verificar logs de Eureka
   kubectl logs deployment/service-discovery -n ecommerce-dev
   
   # Verificar configuración de servicios
   kubectl get svc -n ecommerce-dev
   ```

4. **Problemas de Red**
   ```bash
   # Probar conectividad entre pods
   kubectl exec -it <pod-name> -n ecommerce-dev -- nslookup service-discovery-service
   ```

### Logs Útiles

```bash
# Ver logs de todos los containers de un deployment
kubectl logs deployment/api-gateway -n ecommerce-dev --all-containers=true

# Seguir logs en tiempo real
kubectl logs -f deployment/api-gateway -n ecommerce-dev

# Ver logs previos después de un restart
kubectl logs deployment/api-gateway -n ecommerce-dev --previous
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