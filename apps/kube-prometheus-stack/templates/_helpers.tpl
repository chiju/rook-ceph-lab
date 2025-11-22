{{/*
Create a dashboard ConfigMap from a JSON file
Usage: {{ include "dashboard.configmap" (dict "name" "my-dashboard" "file" "dashboards/my-dashboard.json" "root" .) }}
*/}}
{{- define "dashboard.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .name }}
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  {{ .name }}.json: |
{{ .root.Files.Get .file | indent 4 }}
{{- end }}
