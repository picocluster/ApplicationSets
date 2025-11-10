# Linkerd Service Mesh Setup Guide for PicoCluster

Complete guide for implementing Linkerd service mesh on your PicoCluster.

## Overview

Linkerd is a lightweight, ultra-fast service mesh that adds reliability, observability, and security to Kubernetes applications.

### Key Differences from Other Meshes

| Feature | Linkerd | Istio | Consul |
|---------|---------|-------|--------|
| Memory per proxy | 10MB | 100MB+ | 50MB+ |
| Performance impact | <1% | 5-10% | 3-5% |
| Complexity | Low | High | Medium |
| mTLS | Automatic | Requires config | Requires config |
| Best for | Edge/small clusters | Large enterprises | Multi-cloud |

## Quick Start

### Step 1: Install Linkerd

```bash
# Install Linkerd control plane
ansible-playbook infrastructure/networking/install_linkerd.ansible
```

This deploys:
- Linkerd controller plane
- Certificate management
- Proxy injector
- Viz dashboard

### Step 2: Enable Mesh for Namespace

```bash
# Label namespace for auto-injection
kubectl label namespace myapp linkerd.io/injection=enabled

# Restart deployments to inject proxies
kubectl rollout restart deployment -n myapp
```

### Step 3: Verify mTLS is Working

```bash
# Check installation
linkerd check

# View encrypted traffic
linkerd tap deployment myapp -n myapp

# See metrics
linkerd stat deployment -n myapp
```

### Step 4: Access Dashboard

```bash
# Port-forward to Viz
linkerd-dashboard

# Open: http://localhost:50750
```

## Proxy Injection

### Automatic Namespace Injection

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
  labels:
    linkerd.io/injection: enabled  # Proxies auto-injected
```

### Manual Pod Annotation

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    metadata:
      annotations:
        linkerd.io/inject: enabled  # Enable for this pod
    spec:
      containers:
      - name: app
        image: myapp:latest
```

### Skip Injection for Pods

```yaml
metadata:
  annotations:
    linkerd.io/inject: disabled  # Don't inject proxy
```

## Traffic Policies

### Authorization Policy

Control which services can communicate:

```yaml
apiVersion: policy.linkerd.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-api
  namespace: myapp
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: api-server
  rules:
  - from:
    - principalName: system.serviceaccount.myapp.frontend
    ports:
    - 8080
```

This says: "Only frontend service account can access API on port 8080"

### Service Definition

```yaml
apiVersion: policy.linkerd.io/v1beta1
kind: Server
metadata:
  name: api-server
  namespace: myapp
spec:
  podSelector:
    matchLabels:
      app: api
  port: 8080
  protocol: HTTP
```

### Circuit Breaking

Limit concurrent connections:

```yaml
apiVersion: policy.linkerd.io/v1alpha1
kind: BackendPolicy
metadata:
  name: circuit-break-db
  namespace: myapp
spec:
  targetRef:
    group: apps
    kind: Deployment
    name: postgres
  ratelimits:
  - conditions:
    - pathRegex: /.*
      methodRegex: .*
    limit: 100  # Max 100 concurrent
    window: 1s
```

### Retry Policy

Automatic retries on failure:

```yaml
apiVersion: policy.linkerd.io/v1beta1
kind: RetryPolicy
metadata:
  name: retry-failed
  namespace: myapp
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: backend
  maxRetries: 2
  backoff:
    minDuration: 10ms
    maxDuration: 100ms
    jitter: 0ms
```

## Canary Deployments

### Traffic Split for Gradual Rollout

```yaml
---
# Stable deployment (90% of traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
  namespace: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: stable
  template:
    metadata:
      labels:
        app: myapp
        version: stable
    spec:
      containers:
      - name: app
        image: myapp:1.0.0

---
# Canary deployment (10% of traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
  namespace: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: canary
  template:
    metadata:
      labels:
        app: myapp
        version: canary
    spec:
      containers:
      - name: app
        image: myapp:2.0.0

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: myapp
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: myapp

---
# Traffic split (90% stable, 10% canary)
apiVersion: policy.linkerd.io/v1alpha1
kind: TrafficSplit
metadata:
  name: myapp-canary
  namespace: myapp
spec:
  service: myapp
  backends:
  - name: myapp-stable
    weight: 9
  - name: myapp-canary
    weight: 1
```

Monitor the canary, then gradually shift traffic:
```bash
# 50/50 split
kubectl patch trafficsplit myapp-canary --type merge -p '{"spec":{"backends":[{"name":"myapp-stable","weight":1},{"name":"myapp-canary","weight":1}]}}'

# 100% canary
kubectl patch trafficsplit myapp-canary --type merge -p '{"spec":{"backends":[{"name":"myapp-canary","weight":1}]}}'
```

## Observability

### Golden Metrics

Linkerd automatically tracks:

- **Success Rate**: Percentage of successful requests
- **Latency**: P50, P95, P99 response times
- **Traffic**: Requests per second
- **Errors**: Error rate percentage

View in dashboard or CLI:

```bash
# View golden metrics
linkerd stat deployment -n myapp

# Watch in real-time
linkerd stat deployment -n myapp -w

# View per-route metrics
linkerd routes deployment/myapp -n myapp
```

### Real-time Traffic (Tap)

Watch live traffic:

```bash
# Tap all traffic to deployment
linkerd tap deployment myapp -n myapp

# Filter by source pod
linkerd tap deployment myapp --from deployment/frontend -n myapp

# Save to file
linkerd tap deployment myapp -n myapp > traffic.log
```

### Integrate with Prometheus

Linkerd exposes metrics on port 4191:

```yaml
# Prometheus scrape config
scrape_configs:
  - job_name: 'linkerd-proxy'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_container_port_name]
        action: keep
        regex: admin-http
```

### Grafana Dashboards

Linkerd includes pre-built dashboards:

1. **Service Mesh**: Overall health
2. **Deployment**: Per-deployment metrics
3. **Pod**: Per-pod details
4. **Route**: Per-route analytics

Access via Viz dashboard or Grafana.

## Security Features

### Automatic mTLS

All traffic automatically encrypted:

```bash
# Verify mTLS is active
linkerd auth check deployment myapp -n myapp

# View certificate info
kubectl get secret -n myapp linkerd-ca -o yaml | grep cert
```

### Certificate Management

Certificates automatically rotated every 24 hours:

```bash
# View certificate details
linkerd identity -n myapp

# Check rotation
kubectl logs -n linkerd deployment/identity
```

### Zero-Trust Networking

Default deny, explicitly allow:

```yaml
# Deny all by default
apiVersion: policy.linkerd.io/v1beta1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}

# Allow specific service
apiVersion: policy.linkerd.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend
spec:
  targetRef:
    kind: Server
    name: api
  rules:
  - from:
    - principalName: system.serviceaccount.default.frontend
```

## Multi-Cluster Communication

Connect multiple PioClusters:

```bash
# Export cluster identity
linkerd export-control-plane-ca > ca.crt

# Import in other cluster
kubectl apply -f ca.crt

# Link clusters
linkerd multicluster link --cluster-name cluster-west cluster-west-kubeconfig.yaml
```

## Troubleshooting

### Check Installation Health

```bash
# Full validation
linkerd check

# Quick check
linkerd check --output=short
```

### View Proxy Logs

```bash
# Logs from proxy sidecar
kubectl logs <pod> -c linkerd-proxy -f

# Tail all proxies in namespace
kubectl logs -n myapp -l linkerd.io/workload -c linkerd-proxy -f
```

### Debug Connectivity Issues

```bash
# Test specific pod pair
linkerd diagnostics tap deployment/frontend --from deployment/backend -n myapp

# Check route metrics
linkerd routes deployment myapp -n myapp

# Verify mTLS
linkerd auth check deployment myapp
```

### Common Issues

**Proxy injection not working:**
```bash
# Verify webhook is running
kubectl get pods -n linkerd -l app.kubernetes.io/name=proxy-injector

# Check admission webhook
kubectl get mutatingwebhookconfigurations | grep linkerd
```

**High proxy memory usage:**
```bash
# Reduce log verbosity
kubectl set env daemonset/linkerd-proxy -n linkerd LINKERD_LOG_LEVEL=warn
```

**Slow request routing:**
```bash
# Check load balancing
linkerd tap deployment myapp -n myapp | grep latency
```

## Integration Examples

### With Prometheus + Grafana

```yaml
# Scrape Linkerd metrics
scrape_configs:
  - job_name: 'linkerd'
    kubernetes_sd_configs:
      - role: endpoint
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace]
        regex: linkerd
        action: keep
```

### With Jaeger (Distributed Tracing)

Linkerd proxies automatically forward traces:

```bash
# Configure proxy for Jaeger
kubectl set env daemonset/linkerd-proxy \
  JAEGER_SAMPLER_TYPE=const \
  JAEGER_SAMPLER_PARAM=1 \
  -n linkerd
```

### With GitOps (Flux)

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: linkerd-policies
spec:
  sourceRef:
    kind: GitRepository
    name: policies
  path: ./linkerd
  prune: true
  interval: 1m
```

## Performance Optimization

### Memory per Proxy

Default: ~10-30MB
```bash
# Monitor actual usage
kubectl top pods -n myapp --containers | grep linkerd-proxy
```

### CPU per Proxy

Default: ~5-10m (millicores)
```bash
# Optimize for edge devices
kubectl set resources daemonset/linkerd-proxy \
  -n linkerd \
  --limits=cpu=50m,memory=100Mi
```

### Disable Tap for Production

Tap requires local buffering:
```bash
# Disable to save memory
kubectl set env daemonset/linkerd-proxy \
  LINKERD_DISABLE_TAP=true \
  -n linkerd
```

## See Also

- [Linkerd Documentation](https://linkerd.io/docs/)
- [Service Mesh Interface (SMI)](https://smi-spec.io/)
- [Traffic Policy Examples](https://linkerd.io/docs/tasks/traffic-policy/)
- [Best Practices](https://linkerd.io/docs/tasks/)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
