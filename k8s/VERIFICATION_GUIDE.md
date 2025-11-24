# 📋 Guía de Verificación Post-Despliegue

Este documento te ayudará a verificar que todos los componentes de tu plataforma de ecommerce están funcionando correctamente.

## 🏗️ Verificación de Infraestructura Base

### 1. Verificar que todos los pods estén ejecutándose
```bash
kubectl get pods -n ecommerce-dev
```
**Esperado:** Todos los pods en estado `Running` o `Ready`

### 2. Verificar servicios
```bash
kubectl get svc -n ecommerce-dev
```
**Esperado:** Todos los servicios con IP asignada

### 3. Verificar almacenamiento
```bash
kubectl get pv,pvc -n ecommerce-dev
```
**Esperado:** Volúmenes en estado `Bound`

## 🔒 Verificación de Seguridad

### 1. Network Policies
```bash
kubectl get networkpolicy -n ecommerce-dev
```
**Verificar:** Políticas para database-access, monitoring-access, logging-access

### 2. RBAC
```bash
kubectl get roles,rolebindings -n ecommerce-dev
kubectl get serviceaccounts -n ecommerce-dev
```
**Verificar:** Roles específicos para cada componente

### 3. Pod Security
```bash
kubectl get pod -n ecommerce-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'
```
**Verificar:** Security contexts configurados

## 📊 Verificación de Monitoreo

### 1. Acceder a Prometheus
```bash
kubectl port-forward svc/prometheus-service 9090:9090 -n ecommerce-dev
```
Abrir: http://localhost:9090
**Verificar:** 
- Targets están UP
- Métricas de Spring Boot están disponibles
- Queries básicas funcionan: `up`, `jvm_memory_used_bytes`

### 2. Acceder a Grafana
```bash
kubectl port-forward svc/grafana-service 3000:3000 -n ecommerce-dev
```
Abrir: http://localhost:3000
**Credenciales:** admin/admin123
**Verificar:**
- Datasource Prometheus configurado
- Dashboards cargados (JVM, Spring Boot, Microservices)
- Datos aparecen en los gráficos

### 3. Verificar métricas de aplicación
```bash
# Verificar endpoints de métricas
kubectl exec -n ecommerce-dev deployment/api-gateway -- curl -s http://localhost:8080/actuator/health
kubectl exec -n ecommerce-dev deployment/api-gateway -- curl -s http://localhost:8080/actuator/prometheus
```

## 📋 Verificación de Logging

### 1. Acceder a Kibana
```bash
kubectl port-forward svc/kibana-service 5601:5601 -n ecommerce-dev
```
Abrir: http://localhost:5601
**Verificar:**
- Elasticsearch está conectado
- Índices de logs están siendo creados
- Logs de aplicaciones son visibles

### 2. Verificar Fluent Bit
```bash
kubectl logs -n ecommerce-dev daemonset/fluent-bit
```
**Verificar:** Sin errores de conexión a Elasticsearch

### 3. Verificar logs de aplicación
```bash
# Ver logs en tiempo real
kubectl logs -f deployment/api-gateway -n ecommerce-dev
```
**Verificar:** Logs estructurados en JSON

## 🔍 Verificación de Tracing

### 1. Acceder a Zipkin
```bash
kubectl port-forward svc/zipkin-service 9411:9411 -n ecommerce-dev
```
Abrir: http://localhost:9411
**Verificar:**
- Interface carga correctamente
- Servicios aparecen en la lista
- Traces están siendo capturados

## 🏪 Verificación de Microservicios

### 1. Service Discovery (Eureka)
```bash
kubectl port-forward svc/service-discovery-service 8761:8761 -n ecommerce-dev
```
Abrir: http://localhost:8761
**Verificar:** Todos los servicios registrados

### 2. API Gateway
```bash
kubectl port-forward svc/api-gateway-service 8080:8080 -n ecommerce-dev
```
**Pruebas:**
```bash
# Health check
curl http://localhost:8080/actuator/health

# Endpoints de negocio (si están configurados)
curl http://localhost:8080/api/users/health
curl http://localhost:8080/api/products/health
curl http://localhost:8080/api/orders/health
```

### 3. Verificar conectividad entre servicios
```bash
# Verificar desde API Gateway a otros servicios
kubectl exec -n ecommerce-dev deployment/api-gateway -- curl -s http://user-service:8083/actuator/health
kubectl exec -n ecommerce-dev deployment/api-gateway -- curl -s http://product-service:8082/actuator/health
```

## 📈 Verificación de Autoescalado

### 1. HPA Status
```bash
kubectl get hpa -n ecommerce-dev
kubectl describe hpa api-gateway-hpa -n ecommerce-dev
```
**Verificar:** Métricas de CPU/memoria están siendo leídas

### 2. Generar carga (opcional)
```bash
# Generar carga en API Gateway
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Dentro del pod:
while true; do wget -q -O- http://api-gateway-service.ecommerce-dev.svc.cluster.local:8080/actuator/health; done
```

## 🌍 Verificación de Ingress (si aplicable)

```bash
kubectl get ingress -n ecommerce-dev
kubectl describe ingress ecommerce-ingress -n ecommerce-dev
```

## ⚠️ Solución de Problemas Comunes

### Pods en estado Pending
```bash
kubectl describe pod <pod-name> -n ecommerce-dev
```
**Posibles causas:** Recursos insuficientes, PV no disponible

### Servicios no accesibles
```bash
kubectl get endpoints -n ecommerce-dev
```
**Verificar:** Endpoints tienen IPs asignadas

### Métricas no aparecen en Grafana
```bash
kubectl logs deployment/prometheus -n ecommerce-dev
```
**Verificar:** Prometheus puede scrape los targets

### Logs no aparecen en Kibana
```bash
kubectl logs daemonset/fluent-bit -n ecommerce-dev
kubectl logs deployment/elasticsearch -n ecommerce-dev
```

## ✅ Checklist de Verificación Completa

- [ ] Todos los pods están Running
- [ ] Todos los servicios tienen ClusterIP
- [ ] Prometheus accesible y scrapeando métricas
- [ ] Grafana muestra dashboards con datos
- [ ] Kibana muestra logs de aplicaciones
- [ ] Zipkin captura traces
- [ ] Eureka muestra servicios registrados
- [ ] API Gateway responde a health checks
- [ ] HPA está funcionando
- [ ] Network policies están aplicadas
- [ ] RBAC configurado correctamente
- [ ] Volúmenes persistentes montados

## 🔧 Comandos de Limpieza

Si necesitas limpiar el despliegue:
```bash
# Eliminar todo el namespace (¡CUIDADO!)
kubectl delete namespace ecommerce-dev

# O usar el script de limpieza
./k8s/scripts/cleanup.sh
```

## 📞 Información de Soporte

- **Logs centralizados:** Kibana http://localhost:5601
- **Métricas:** Grafana http://localhost:3000  
- **Traces:** Zipkin http://localhost:9411
- **Service Discovery:** Eureka http://localhost:8761
- **API Gateway:** http://localhost:8080

Para más detalles, revisa los logs específicos de cada componente usando `kubectl logs`.