{{- define "telemetry-kafka.name" -}}
{{- printf "%s-vector" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "telemetry-kafka.namespace" -}}
{{- default .Release.Namespace .Values.deploymentNamespace -}}
{{- end -}}
{{- define "telemetry-kafka.labels" -}}
app.kubernetes.io/name: telemetry-kafka
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: vector
{{- end -}}
