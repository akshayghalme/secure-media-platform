{{/*
  Common labels used across all resources.
  WHY a helper: DRY — every resource needs the same set of labels.
  Changing them in one place updates all templates.
*/}}
{{- define "license-server.labels" -}}
app: {{ .Release.Name }}
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
managed-by: {{ .Release.Service }}
{{- end }}
