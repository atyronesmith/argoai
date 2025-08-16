{{/*
Expand the name of the chart.
*/}}
{{- define "ai-document-pipeline.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ai-document-pipeline.fullname" -}}
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
{{- define "ai-document-pipeline.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ai-document-pipeline.labels" -}}
helm.sh/chart: {{ include "ai-document-pipeline.chart" . }}
{{ include "ai-document-pipeline.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ai-document-pipeline.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ai-document-pipeline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ai-document-pipeline.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ai-document-pipeline.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the namespace
*/}}
{{- define "ai-document-pipeline.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace }}
{{- end }}

{{/*
Get MinIO endpoint
*/}}
{{- define "ai-document-pipeline.minioEndpoint" -}}
{{- printf "minio.%s.svc.cluster.local:9000" (include "ai-document-pipeline.namespace" .) }}
{{- end }}

{{/*
Get Ollama endpoint
*/}}
{{- define "ai-document-pipeline.ollamaEndpoint" -}}
{{- printf "ollama.%s.svc.cluster.local:11434" (include "ai-document-pipeline.namespace" .) }}
{{- end }}
