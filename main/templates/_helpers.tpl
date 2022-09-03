{{/*
Expand the name of the chart.
*/}}
{{- define "main.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "main.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "main.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 50 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 50 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 50 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
{{- define "front.fullname" -}}
{{ include "main.fullname" . }}-front
{{- end }}
{{- define "externalDns.fullname" -}}
{{ include "main.fullname" . }}-external-dns
{{- end }}

{{/*
Common labels
*/}}
{{- define "front.labels" -}}
helm.sh/chart: {{ include "main.chart" . }}
{{ include "front.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "externalDns.labels" -}}
helm.sh/chart: {{ include "main.chart" . }}
{{ include "externalDns.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "front.instanceLabel" -}}
{{ .Release.Name }}-front
{{- end }}
{{- define "externalDns.instanceLabel" -}}
{{ .Release.Name }}-external-dns
{{- end }}
{{- define "front.selectorLabels" -}}
app.kubernetes.io/name: {{ include "main.name" . }}
app.kubernetes.io/instance: {{ include "front.instanceLabel" . }}
{{- end }}
{{- define "externalDns.selectorLabels" -}}
app.kubernetes.io/name: {{ include "main.name" . }}
app.kubernetes.io/instance: {{ include "externalDns.instanceLabel" . }}
{{- end }}
