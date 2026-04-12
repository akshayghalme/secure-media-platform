# Prometheus — License Server Scraping

Two ways to get the license server scraped, pick whichever matches your cluster:

## Option A — kube-prometheus-stack (recommended)

If your EKS cluster runs `kube-prometheus-stack` (Prometheus Operator), the **license-server Helm chart already ships a `ServiceMonitor`** — enable it via `values.yaml`:

```yaml
serviceMonitor:
  enabled: true
  labels:
    release: kube-prometheus-stack   # must match your stack's release name
  interval: 15s
```

Apply the recording rules:

```bash
kubectl apply -f recording-rules.yaml
```

That's it — Prometheus picks up the ServiceMonitor on the next reconcile and starts scraping `/metrics` every 15s. Verify in the Prometheus UI under **Status → Targets**.

## Option B — Raw Prometheus (no Operator)

Copy the job block from `scrape-config.yaml` into your `prometheus.yml` under `scrape_configs:`, paste the `rules:` block from `recording-rules.yaml` into a file referenced by `rule_files:`, and reload Prometheus:

```bash
curl -X POST http://prometheus:9090/-/reload
```

## What gets scraped

The license server exposes a `/metrics` endpoint via `prometheus_client.make_asgi_app()` (see `license-server/app/main.py`). Key metrics:

| Metric | Type | Meaning |
|---|---|---|
| `license_requests_total{status}` | Counter | Requests by status: `issued` / `cached` / `denied` / `not_found` / `error` |
| `license_request_duration_seconds_bucket` | Histogram | Per-request latency, buckets tuned for the 200ms p99 SLO |
| `license_cache_hits_total` | Counter | Redis cache hits (fed into cache hit ratio) |

Recording rules flatten these into dashboard-ready series:

- `license_server:request_duration_seconds:{p50,p95,p99}` — rolling latency percentiles
- `license_server:requests:rate5m` / `license_server:errors:rate5m` — throughput + errors
- `license_server:error_ratio:5m` — error ratio (NaN-safe)
- `license_server:cache_hit_ratio:5m` — cache hit ratio (feeds the phase 4 DoD)

## How to test

```bash
# Port-forward the license server Service
kubectl port-forward svc/license-server 8000:80
curl -s localhost:8000/metrics | grep license_

# Port-forward Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090
# Open http://localhost:9090 → Status → Targets → look for license-server (1/1 UP)
# Then try: license_server:request_duration_seconds:p99
```
