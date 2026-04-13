# Grafana — License Server SLI Dashboard

Phase 4 observability: the Grafana dashboard that surfaces the license
server SLIs defined by the recording rules in `../prometheus/`.

## What's in the dashboard

| Panel | Query (recording rule) | Why |
|---|---|---|
| License latency p99 (stat) | `license_server:request_duration_seconds:p99` | Top-line SLO number. Red above 200ms. |
| Error ratio 5m (stat) | `license_server:error_ratio:5m` | Catches auth/validation regressions. |
| Cache hit ratio 5m (stat) | `license_server:cache_hit_ratio:5m` | Phase 4 DoD metric. Low = Redis trouble. |
| Throughput 5m (stat) | `license_server:requests:rate5m` | Load context for the latency panels. |
| Latency percentiles (timeseries) | p50 / p95 / p99 | 200ms threshold line marks the SLO. |
| Throughput vs errors (timeseries) | requests + errors rate | Visual divergence = regression. |
| Cache hit ratio trend | `license_server:cache_hit_ratio:5m` | Spot Redis eviction / cold starts. |

Every panel reads a **recording rule**, not a raw expression. That's
intentional — recorded values render instantly and guarantee panels and
alerts see the same numbers.

## How provisioning works

kube-prometheus-stack ships a Grafana sidecar (`kiwigrid/k8s-sidecar`)
that watches every namespace for ConfigMaps labelled
`grafana_dashboard=1` and loads their contents as dashboards at runtime.
No Grafana API calls, no Terraform provider, no restart needed.

Files:

- `dashboard-license-server.json` — edit this, it's the source of truth.
- `dashboard-configmap.yaml` — static reference copy of the wrapper; the
  real one is generated on apply.
- `../../../scripts/load-grafana-dashboard.sh` — regenerates the
  ConfigMap from the JSON and `kubectl apply`s it.

## Apply

```bash
# from repo root
./scripts/load-grafana-dashboard.sh
```

Override the namespace if your Grafana runs elsewhere:

```bash
GRAFANA_NAMESPACE=observability ./scripts/load-grafana-dashboard.sh
```

Wait ~30s for the sidecar to reload, then open Grafana → Dashboards →
**License Server — SLIs**.

## Troubleshooting

- **Dashboard doesn't appear:** check the sidecar is actually running
  (`kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana`)
  and that its label selector matches `grafana_dashboard=1`. Some
  custom kube-prometheus-stack values override this.
- **Panels show "No data":** the recording rules haven't evaluated yet.
  Wait one `interval` (30s) after Prometheus picked up the
  `PrometheusRule` CRD, and make sure license server traffic is
  actually flowing — the queries are `rate(...[5m])` so you need at
  least one sample.
- **p99 panel stuck at 0:** the histogram buckets in `license.py`
  probably don't cover your traffic range. Check
  `license_request_duration_seconds_bucket` directly in Prometheus.
