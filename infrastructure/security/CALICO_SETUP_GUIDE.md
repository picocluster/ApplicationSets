# Calico Network Policies Setup Guide for PicoCluster

Complete guide for implementing network security using Calico on your PicoCluster.

## Overview

Calico enforces Kubernetes Network Policies, controlling pod-to-pod communication at the network level.

### Key Concepts

**Network Policy**: Rules controlling traffic between pods

**Selectors**: Identify which pods the policy applies to
- Label selectors
- Namespace selectors
- Service account selectors

**Rules**: Define allowed traffic
- Ingress: Incoming traffic
- Egress: Outgoing traffic
- Ports and protocols

### Zero Trust Networking

```
Default: Deny all traffic
   ↓
Explicitly allow needed traffic
   ↓
Monitor and audit
```

## Quick Start

### Step 1: Install Calico

```bash
# Install Calico network policy engine
ansible-playbook infrastructure/security/install_calico.ansible
```

Calico will:
- Deploy network policy engine
- Configure on all nodes
- Start in staged mode (non-blocking)
- Enable monitoring

### Step 2: Create Default Deny Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

This denies ALL traffic (ingress and egress) by default.

### Step 3: Allow Specific Traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

Only frontend pods can reach backend on port 8080.

### Step 4: Verify Policies

```bash
# List policies
kubectl get networkpolicies -A

# Test connectivity
calico-validate frontend-pod backend-pod default

# Monitor denied traffic
kubectl logs -n calico-system -f
```

## Policy Patterns

### Pattern 1: Deny All, Allow Specific (Recommended)

```yaml
---
# Step 1: Deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: myapp
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Step 2: Allow DNS (needed for all pods)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: myapp
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53

---
# Step 3: Allow specific service communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-traffic
  namespace: myapp
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Pattern 2: Namespace Isolation

```yaml
# Allow traffic only within same namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: myapp
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # Same namespace only
```

### Pattern 3: Tier-Based Access

```yaml
---
# Frontend tier - allows internet, denies internal
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}  # Allow to any namespace
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443

---
# Backend tier - only from frontend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080

---
# Database tier - only from backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
```

### Pattern 4: External API Access

```yaml
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
  namespace: myapp
spec:
  selector: app == 'myapp'
  types:
  - Egress
  egress:
  - action: Allow
    destination:
      domains:
      - "api.example.com"
      - "*.example.com"
    ports:
    - protocol: TCP
      port: 443
```

## Advanced Features

### Named Network Sets (IP Whitelists)

```yaml
---
# Define reusable IP set
apiVersion: crd.projectcalico.org/v1
kind: NetworkSet
metadata:
  name: external-apis
  namespace: default
spec:
  nets:
  - 10.0.0.0/8
  - 172.16.0.0/12

---
# Use in policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-ips
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
```

### Service Account Based Access

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchExpressions:
        - key: serviceAccountName
          operator: In
          values:
          - prometheus-scraper
    ports:
    - protocol: TCP
      port: 9090
```

### ICMP and DNS Rules

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-diagnostics
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Allow ICMP for troubleshooting
  - to:
    - podSelector: {}
    ports:
    - protocol: ICMP
```

## Testing and Troubleshooting

### Test Connectivity

```bash
# Test if pod A can reach pod B
calico-validate pod-a pod-b default

# Manual test
kubectl exec -it pod-a -- ping pod-b.default.svc.cluster.local

# Test specific port
kubectl exec -it pod-a -- nc -zv pod-b 8080
```

### View Policy Status

```bash
# List all policies
kubectl get networkpolicies -A

# Get specific policy
kubectl describe networkpolicy policy-name

# View policy YAML
kubectl get networkpolicy policy-name -o yaml

# Watch changes
kubectl get networkpolicies -A -w
```

### Debug Denied Traffic

```bash
# View Calico logs
kubectl logs -n calico-system -l k8s-app=calico-node -f

# Look for DENY entries
kubectl logs -n calico-system -l k8s-app=calico-node | grep DENY

# Check iptables rules on node
sudo iptables -L -n | grep DROP
```

### Common Issues

**Traffic still allowed in staged mode:**
- Normal behavior - staged mode doesn't enforce
- Switch to enforced mode when ready

**DNS broken after policies:**
- Add explicit DNS egress rule
- Allow UDP port 53 to kube-system namespace

**External connectivity failing:**
- Check egress rules allow external traffic
- Verify CIDR blocks are correct
- Check cloud firewall/security groups

## Enforcement Modes

### Staged Mode (Default)

```bash
# Policies created but not enforced
# Use for testing and validation
kubectl apply -f policies.yaml

# Monitor what would be blocked
kubectl logs -n calico-system -f
```

### Enforced Mode

```bash
# Policies actively block traffic
# Edit Installation resource:
kubectl edit Installation default -n calico-system

# Change enforcement to enforced:
# spec.podSecurityPolicy.type: "enforced"
```

## Best Practices

### 1. Layer Your Policies

```yaml
# Layer 1: Deny defaults
# Layer 2: Allow internal communication
# Layer 3: Allow external services
# Layer 4: Allow monitoring/logging
```

### 2. Use Meaningful Labels

```yaml
labels:
  app: myapp           # Application name
  version: v1          # Version
  tier: backend        # Service tier
  team: platform       # Owning team
  env: production      # Environment
```

### 3. Document Policy Intent

```yaml
metadata:
  annotations:
    description: "Allow frontend to backend on port 8080"
    owner: "platform-team"
    last-updated: "2025-01-15"
```

### 4. Test Before Enforcing

```bash
# 1. Deploy in staged mode
kubectl apply -f policy.yaml

# 2. Monitor for denied traffic
kubectl logs -n calico-system -f

# 3. Verify no false positives
calico-validate pod-a pod-b default

# 4. Switch to enforced
kubectl edit Installation
```

### 5. Version Control

```bash
# Keep policies in Git
git clone https://github.com/org/network-policies.git
kubectl apply -f network-policies/production/

# Track changes
git log network-policies/
```

## Integration with CI/CD

### Validate Policies in Pipeline

```yaml
# .gitlab-ci.yml
validate:policies:
  stage: test
  image: bitnami/kubectl:latest
  script:
    - kubectl apply -f policies/ --dry-run=server
    - calico-validate pod-a pod-b default
```

### Deploy with GitOps

```yaml
# Flux GitOps
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: network-policies
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: policies
  path: ./calico-policies
```

## Monitoring

### Check Policy Metrics

```bash
# Port-forward to Calico metrics
kubectl port-forward -n calico-system svc/calico-node 9091:9091

# View in Prometheus
# Metrics like: calico_denied_packets, calico_allowed_packets
```

### Create Prometheus Alerts

```yaml
alert: PolicyEnforcementErrors
expr: rate(calico_enforcement_errors_total[5m]) > 0
for: 5m
annotations:
  summary: "Calico policy enforcement errors detected"
```

## See Also

- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [Network Policy Reference](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Calico NetworkPolicy Extensions](https://docs.tigera.io/calico/latest/reference/calicoctl/calicoctl-api-resources/networkpolicy/)
- [Security Best Practices](https://kubernetes.io/docs/concepts/security/network-policies/)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
