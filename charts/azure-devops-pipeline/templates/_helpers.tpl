{{/*
Expand the name of the chart.
*/}}
{{- define "azure-devops-pipeline.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "azure-devops-pipeline.fullname" -}}
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
{{- define "azure-devops-pipeline.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "azure-devops-pipeline.labels" -}}
helm.sh/chart: {{ include "azure-devops-pipeline.chart" . }}
{{ include "azure-devops-pipeline.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "azure-devops-pipeline.selectorLabels" -}}
app.kubernetes.io/name: {{ include "azure-devops-pipeline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "azure-devops-pipeline.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "azure-devops-pipeline.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "azure-devops-pipeline.secretName" -}}
{{- if .Values.serviceAccount.secretname }}
{{- default "default" .Values.serviceAccount.secretname }}
{{- else }}
{{- printf "%s-%s" (include "azure-devops-pipeline.serviceAccountName" .) "devops-secret" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
