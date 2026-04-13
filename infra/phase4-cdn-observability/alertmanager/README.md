# License Server Alerts

Phase 4 alerting: fire a Slack + SNS alert when the license server
violates its SLOs.

## What fires

| Alert | Expression | For | Severity | Receivers |
|---|---|---|---|---|
| `LicenseServerP99LatencyHigh` | `p99 > 200ms` | 5m | critical | Slack #alerts-critical + SNS |
| `LicenseServerP95LatencyDrifting` | `p95 > 150ms` | 10m | warning | Slack #alerts-warn |
| `LicenseServerErrorRateHigh` | `error_ratio > 5%` | 2m | critical | Slack #alerts-critical + SNS |
| `LicenseServerCacheHitRatioLow` | `cache_hit_ratio < 50%` | 15m | warning | Slack #alerts-warn |
| `LicenseServerNoMetrics` | `absent(...)` | 3m | critical | Slack #alerts-critical + SNS |

All expressions query the **recording rules** from
`../prometheus/recording-rules.yaml`, not raw histograms — so what
fires always matches what the dashboard shows.

## Files

- `../prometheus/alert-rules.yaml` — `PrometheusRule` CRD with the rules above.
- `alertmanager-config.yaml` — Alertmanager route tree, receivers, and
  inhibit rules (Slack + SNS fan-out, p95↔p99 suppression).
- `../alerts.tf` — SNS topic + IRSA role for Alertmanager to publish.

## Deploy

### 1. Provision SNS + IRSA (Terraform)

```bash
cd infra/phase4-cdn-observability
export TF_VAR_eks_oidc_provider_url="$(aws eks describe-cluster \
  --name <your-cluster> \
  --query 'cluster.identity.oidc.issuer' --output text)"
terraform apply
```

Capture the outputs — you need them in step 3:

```bash
terraform output license_alerts_topic_arn
terraform output alertmanager_publisher_role_arn
```

### 2. Apply the alert rules

```bash
kubectl -n monitoring apply -f prometheus/alert-rules.yaml
```

Verify Prometheus picked them up:

```bash
kubectl -n monitoring port-forward svc/prometheus-operated 9090
# → http://localhost:9090/alerts
```

### 3. Configure Alertmanager

Create the Slack webhook secret:

```bash
kubectl -n monitoring create secret generic alertmanager-slack \
  --from-literal=webhook_url="https://hooks.slack.com/services/XXX/YYY/ZZZ"
```

Annotate the Alertmanager ServiceAccount so it can assume the IRSA
role (one-time, after `terraform apply`):

```bash
kubectl -n monitoring annotate sa kube-prometheus-stack-alertmanager \
  eks.amazonaws.com/role-arn="$(terraform output -raw alertmanager_publisher_role_arn)" \
  --overwrite
```

Substitute the Terraform outputs into `alertmanager-config.yaml` and
load it via Helm values:

```bash
SNS_TOPIC_ARN="$(terraform output -raw license_alerts_topic_arn)" \
ALERTMANAGER_PUBLISHER_ROLE_ARN="$(terraform output -raw alertmanager_publisher_role_arn)" \
  envsubst < alertmanager/alertmanager-config.yaml > /tmp/am-config.yaml

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --reuse-values \
  --set-file alertmanager.config=/tmp/am-config.yaml
```

Restart Alertmanager to pick up the new SA annotation:

```bash
kubectl -n monitoring rollout restart statefulset alertmanager-kube-prometheus-stack-alertmanager
```

## Test it

Force a latency breach:

```bash
# scale license server down to 1 replica and hammer it
kubectl -n license scale deploy license-server --replicas=1
while true; do curl -s "https://license.<your-domain>/license?content_id=test" >/dev/null; done
```

Within ~6 minutes you should see:
- `LicenseServerP99LatencyHigh` firing in Prometheus /alerts
- A message in Slack #alerts-critical
- An SNS delivery in CloudWatch Logs (if you subscribed a logger) or
  whatever you subscribed to the topic

## Troubleshooting

- **SNS delivery fails with `AccessDenied`:** the SA annotation didn't
  take effect. Check `kubectl describe sa kube-prometheus-stack-alertmanager`
  shows the `eks.amazonaws.com/role-arn` annotation and that the
  Alertmanager pods were restarted *after* the annotation was added.
- **Slack messages never arrive:** webhook secret not mounted or key
  name mismatched. Alertmanager expects the file at
  `/etc/alertmanager/secrets/slack/webhook_url` — the key in the secret
  must be literally `webhook_url`.
- **Alert evaluates but doesn't page:** the alert probably matched the
  generic `severity: warning` fallback route. Check the matchers in
  `alertmanager-config.yaml` — they're strict equality on
  `service = "license-server"`.
