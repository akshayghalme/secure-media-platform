#!/usr/bin/env bash
# Regenerate the Grafana dashboard ConfigMap from the source JSON and
# apply it to the cluster. The sidecar picks it up within ~30s.
#
# WHY a script: keeping the JSON and the ConfigMap in sync by hand is
# error-prone — a missing indent breaks YAML parsing and the sidecar
# silently drops the dashboard. This script is the single source of
# truth for "apply dashboard".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DASHBOARD_JSON="${ROOT}/infra/phase4-cdn-observability/grafana/dashboard-license-server.json"
NAMESPACE="${GRAFANA_NAMESPACE:-monitoring}"

if [[ ! -f "${DASHBOARD_JSON}" ]]; then
  echo "dashboard json not found: ${DASHBOARD_JSON}" >&2
  exit 1
fi

# Build the ConfigMap imperatively. `kubectl create --dry-run -o yaml`
# guarantees correct indentation of the embedded JSON regardless of
# special characters, which is why we don't sed into the static yaml.
kubectl create configmap license-server-slis-dashboard \
  --namespace "${NAMESPACE}" \
  --from-file=license-server-slis.json="${DASHBOARD_JSON}" \
  --dry-run=client -o yaml \
  | kubectl label --local -f - \
      grafana_dashboard=1 \
      app.kubernetes.io/part-of=license-server \
      phase=4 \
      --dry-run=client -o yaml \
  | kubectl apply -f -

echo "dashboard applied. give the grafana sidecar ~30s to reload, then check:"
echo "  http://<grafana>/d/license-server-slis"
