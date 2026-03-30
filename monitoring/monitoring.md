# Monitoring setup

This document provides instructions on how to set up OpenTelemetry monitoring for the `deviser`, `events-ingester`, and `events-presenter` services using OpenTelemetry Collector and kube-prometheus-stack.

> **Warning:** This setup is intended for development and testing purposes. For production environments, additional configuration and security measures should be implemented.

## Prerequisites

`deviser`, `events-ingester`, `events-presenter` running with OpenTelemetry enabled:
```yaml
config:
  OTEL_ENABLED: "true"
  OTEL_EXPORT_INTERVAL: "30s"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318" # To be changed to the endpoint of the OpenTelemetry Collector
```

Note that there is a `krateoctl` profile named ([monitoring](https://github.com/krateoplatformops/releases/blob/main/krateo-overrides.monitoring.yaml)) that includes the above configuration for the services. You can use it to deploy the services with OpenTelemetry enabled.
Note that if the configuration needs to be updated based on your environment, you can create your own profile file for monitoring.

## OpenTelemetry Collector

OpenTelemetry Collector is a vendor-agnostic agent that can receive, process, and export telemetry data. 
In this simple setup, we will configure it to receive metrics in the OTLP format and export them to Prometheus.

Add the OpenTelemetry Helm repository and update it:
```sh
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

Create a `otelcol-values.yaml` file with the following content to configure a basic OpenTelemetry Collector:
```sh
cat <<EOF > otelcol-values.yaml
mode: deployment

image:
  repository: "otel/opentelemetry-collector-contrib"

config:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
  processors:
    batch: {}
  exporters:
    prometheus:
      endpoint: 0.0.0.0:9464
  service:
    pipelines:
      metrics:
        receivers: [otlp]
        processors: [batch]
        exporters: [prometheus]

ports:
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318
    protocol: TCP
  prom-metrics:
    enabled: true
    containerPort: 9464
    servicePort: 9464
    protocol: TCP
EOF
```

Deploy the OpenTelemetry Collector using Helm:
```sh
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -n monitoring --create-namespace \
  -f otelcol-values.yaml
```

Verify that the OpenTelemetry Collector is running and the services are created:
```sh
kubectl -n monitoring get pods
kubectl -n monitoring get svc
```

## Kube-Prometheus-Stack

Kube-Prometheus-Stack is a simple way to deploy a full Prometheus monitoring stack, including Prometheus, Alertmanager, and Grafana.

Add the Prometheus Helm repository and update it:
```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Create a `kube-prom-values.yaml` file with the following content to configure a non-production setup of kube-prometheus-stack:
```sh
cat <<EOF > kube-prom-values.yaml
grafana:
  enabled: true
  adminPassword: admin

prometheus:
  prometheusSpec:
    scrapeInterval: 15s
    additionalScrapeConfigs:
      - job_name: "otel-collector"
        static_configs:
          - targets: ["otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:9464"]

alertmanager:
  enabled: false

nodeExporter:
  enabled: false

kubeStateMetrics:
  enabled: false
EOF
```

Deploy kube-prometheus-stack using Helm:
```sh
helm upgrade --install kube-prom prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f kube-prom-values.yaml
```

Verify that the kube-prometheus-stack components are running and the services are created:
```sh
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Access Prometheus and Grafana dashboards:
```sh
kubectl port-forward svc/kube-prom-kube-prometheus-prometheus -n monitoring 9090:9090
# check on http://localhost:9090
```

```sh
kubectl port-forward svc/kube-prom-grafana -n monitoring 3000:80
# check on http://localhost:3000 with credentials (admin/admin)
```
