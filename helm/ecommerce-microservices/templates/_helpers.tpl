{{/*
Expand the name of the chart.
*/}}
{{- define "ecommerce-microservices.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ecommerce-microservices.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ecommerce-microservices.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ecommerce-microservices.labels" -}}
helm.sh/chart: {{ include "ecommerce-microservices.chart" . }}
{{ include "ecommerce-microservices.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ index .Values.global.labels "part-of" }}
app.kubernetes.io/component: {{ .Values.global.labels.component }}
environment: {{ .Values.global.environment }}
{{- range $key, $value := .Values.global.labels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ecommerce-microservices.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ecommerce-microservices.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ecommerce-microservices.serviceAccountName" -}}
{{- if .Values.security.serviceAccount.create }}
{{- default (include "ecommerce-microservices.fullname" .) .Values.security.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.security.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate image name for microservice
*/}}
{{- define "ecommerce-microservices.image" -}}
{{- $registry := .Values.global.registry }}
{{- $image := .image }}
{{- $tag := .Values.global.imageTag }}
{{- printf "%s/%s:%s" $registry $image $tag }}
{{- end }}

{{/*
Generate microservice deployment name
*/}}
{{- define "ecommerce-microservices.deploymentName" -}}
{{- printf "%s-%s" (include "ecommerce-microservices.fullname" .) .name }}
{{- end }}

{{/*
Generate microservice service name
*/}}
{{- define "ecommerce-microservices.serviceName" -}}
{{- printf "%s-%s" (include "ecommerce-microservices.fullname" .) .name }}
{{- end }}

{{/*
Generate resource requests and limits
*/}}
{{- define "ecommerce-microservices.resources" -}}
{{- if .resources }}
resources:
  {{- if .resources.requests }}
  requests:
    {{- if .resources.requests.memory }}
    memory: {{ .resources.requests.memory }}
    {{- end }}
    {{- if .resources.requests.cpu }}
    cpu: {{ .resources.requests.cpu }}
    {{- end }}
  {{- end }}
  {{- if .resources.limits }}
  limits:
    {{- if .resources.limits.memory }}
    memory: {{ .resources.limits.memory }}
    {{- end }}
    {{- if .resources.limits.cpu }}
    cpu: {{ .resources.limits.cpu }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generate environment variables
*/}}
{{- define "ecommerce-microservices.env" -}}
{{- if .env }}
env:
{{- range .env }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
- name: KUBERNETES_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: KUBERNETES_POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: KUBERNETES_NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
{{- end }}
{{- end }}

{{/*
Generate health check probes
*/}}
{{- define "ecommerce-microservices.probes" -}}
{{- if .healthCheck.enabled }}
livenessProbe:
  httpGet:
    path: {{ .healthCheck.path }}
    port: {{ .healthCheck.port }}
  initialDelaySeconds: {{ .healthCheck.initialDelaySeconds | default 30 }}
  periodSeconds: {{ .healthCheck.periodSeconds | default 10 }}
  timeoutSeconds: {{ .healthCheck.timeoutSeconds | default 5 }}
  failureThreshold: {{ .healthCheck.failureThreshold | default 3 }}
readinessProbe:
  httpGet:
    path: {{ .healthCheck.path }}
    port: {{ .healthCheck.port }}
  initialDelaySeconds: {{ .healthCheck.initialDelaySeconds | default 30 }}
  periodSeconds: {{ .healthCheck.periodSeconds | default 10 }}
  timeoutSeconds: {{ .healthCheck.timeoutSeconds | default 5 }}
  failureThreshold: {{ .healthCheck.failureThreshold | default 3 }}
startupProbe:
  httpGet:
    path: {{ .healthCheck.path }}
    port: {{ .healthCheck.port }}
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 10
{{- end }}
{{- end }}

{{/*
Generate security context
*/}}
{{- define "ecommerce-microservices.securityContext" -}}
{{- if .Values.security.securityContext }}
securityContext:
  {{- toYaml .Values.security.securityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Generate container security context
*/}}
{{- define "ecommerce-microservices.containerSecurityContext" -}}
{{- if .Values.security.containerSecurityContext }}
securityContext:
  {{- toYaml .Values.security.containerSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Generate volume mounts for microservice
*/}}
{{- define "ecommerce-microservices.volumeMounts" -}}
volumeMounts:
- name: tmp
  mountPath: /tmp
- name: cache
  mountPath: /app/cache
{{- if .Values.security.containerSecurityContext.readOnlyRootFilesystem }}
- name: logs
  mountPath: /app/logs
{{- end }}
{{- end }}

{{/*
Generate volumes for microservice
*/}}
{{- define "ecommerce-microservices.volumes" -}}
volumes:
- name: tmp
  emptyDir: {}
- name: cache
  emptyDir: {}
{{- if .Values.security.containerSecurityContext.readOnlyRootFilesystem }}
- name: logs
  emptyDir: {}
{{- end }}
{{- end }}

{{/*
Generate annotations for deployments
*/}}
{{- define "ecommerce-microservices.annotations" -}}
annotations:
  {{- range $key, $value := .Values.global.annotations }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  prometheus.io/scrape: "true"
  prometheus.io/port: {{ .port | quote }}
  prometheus.io/path: "/actuator/prometheus"
{{- end }}

{{/*
Generate network policy rules
*/}}
{{- define "ecommerce-microservices.networkPolicyRules" -}}
{{- if .Values.security.networkPolicies.enabled }}
- from:
  - namespaceSelector:
      matchLabels:
        name: {{ .Values.global.namespace }}
  - podSelector:
      matchLabels:
        app.kubernetes.io/part-of: {{ index .Values.global.labels "part-of" }}
- from:
  - namespaceSelector:
      matchLabels:
        name: "ingress-nginx"
  - podSelector:
      matchLabels:
        app.kubernetes.io/name: "ingress-nginx"
{{- end }}
{{- end }}

{{/*
Generate HPA configuration
*/}}
{{- define "ecommerce-microservices.hpa" -}}
{{- if .Values.autoscaling.hpa.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "ecommerce-microservices.deploymentName" . }}-hpa
  labels:
    {{- include "ecommerce-microservices.labels" $ | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "ecommerce-microservices.deploymentName" . }}
  minReplicas: {{ .Values.autoscaling.hpa.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.hpa.maxReplicas }}
  metrics:
  {{- if .Values.autoscaling.hpa.targetCPUUtilizationPercentage }}
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.hpa.targetCPUUtilizationPercentage }}
  {{- end }}
  {{- if .Values.autoscaling.hpa.targetMemoryUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.hpa.targetMemoryUtilizationPercentage }}
  {{- end }}
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
{{- end }}
{{- end }}

{{/*
Generate canary configuration
*/}}
{{- define "ecommerce-microservices.canary" -}}
{{- if and .Values.canary.enabled .Values.canary.flagger.enabled }}
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: {{ include "ecommerce-microservices.deploymentName" . }}
  namespace: {{ .Values.global.namespace }}
  labels:
    {{- include "ecommerce-microservices.labels" $ | nindent 4 }}
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "ecommerce-microservices.deploymentName" . }}
  progressDeadlineSeconds: 60
  service:
    port: {{ .Values.canary.flagger.service.port }}
    targetPort: {{ .Values.canary.flagger.service.targetPort }}
    gateways:
    - public-gateway.istio-system.svc.cluster.local
    hosts:
    - ecommerce.example.com
  analysis:
    interval: {{ .Values.canary.flagger.analysis.interval }}
    threshold: {{ .Values.canary.flagger.analysis.threshold }}
    maxWeight: {{ .Values.canary.flagger.analysis.maxWeight }}
    stepWeight: {{ .Values.canary.flagger.analysis.stepWeight }}
    metrics:
    {{- range .Values.canary.flagger.analysis.metrics }}
    - name: {{ .name }}
      thresholdRange:
        {{- if .thresholdRange.min }}
        min: {{ .thresholdRange.min }}
        {{- end }}
        {{- if .thresholdRange.max }}
        max: {{ .thresholdRange.max }}
        {{- end }}
      interval: {{ .interval }}
    {{- end }}
    webhooks:
    {{- range .Values.canary.flagger.analysis.webhooks }}
    - name: {{ .name }}
      url: {{ .url }}
      timeout: {{ .timeout }}
      metadata:
        {{- range $key, $value := .metadata }}
        {{ $key }}: {{ $value | quote }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}