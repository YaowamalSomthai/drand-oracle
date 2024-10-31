{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "updater.fullname" -}}
drand-oracle-updater
{{- end -}}

{{/*
Common labels
*/}}
{{- define "updater.labels" -}}
app.kubernetes.io/name: {{ include "updater.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "updater.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "updater.selectorLabels" -}}
app.kubernetes.io/name: {{ include "updater.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
