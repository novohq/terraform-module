{{/*
Expand the name of the chart.
*/}}
{{- define "heartbeat-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "heartbeat-chart.labels" -}}
  app: {{ include "heartbeat-chart.name" . }}
  release: {{ .Release.Name }}
  heritage: {{ .Release.Service }}
{{- end -}}
