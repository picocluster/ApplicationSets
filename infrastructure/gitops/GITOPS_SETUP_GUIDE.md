# Flux GitOps Setup Guide for PicoCluster

Complete guide for implementing GitOps workflow on your PicoCluster using Flux.

## Overview

Flux implements GitOps: **declaring desired infrastructure state in Git, automatically synchronized to Kubernetes clusters**.

### Key Principles

- **Single Source of Truth**: Git repository contains all configuration
- **Declarative**: Define what you want, not how to do it
- **Version Control**: Every change tracked in Git history
- **Automated**: No manual kubectl apply; Flux syncs automatically
- **Auditable**: Complete audit trail of all changes
- **Reversible**: Rollback any change via git revert

### Why GitOps?

```
Traditional Approach:
  Admin → kubectl apply → Cluster Updated
  Problem: Manual, error-prone, no audit trail

GitOps Approach:
  Developer → Git commit → Flux syncs → Cluster Updated
  Benefits: Automated, audited, reproducible, easy to rollback
```

## Quick Start

### Step 1: Install Flux

```bash
# Install Flux CLI and deploy to cluster
ansible-playbook infrastructure/gitops/install_flux.ansible
```

Flux will:
- Install on cluster in `flux-system` namespace
- Deploy source-controller, kustomize-controller, notification-controller
- Set up automatic synchronization from Git

### Step 2: Configure Git Repository

```bash
# Set up Git repository structure
ansible-playbook infrastructure/gitops/configure_flux_repo.ansible \
  -e git_repo="https://github.com/your-org/cluster-config" \
  -e git_branch="main" \
  -e github_token="ghp_xxxxx"
```

This will:
- Clone or initialize Git repository
- Create directory structure for clusters and apps
- Generate example Kustomizations
- Commit initial configuration

### Step 3: Verify Installation

```bash
# Check Flux status
flux-status

# View all Flux resources
flux get all --all-namespaces

# Watch for synchronization
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Step 4: Deploy Your First Application

```bash
# Create application manifest
cd /tmp/flux-repo  # Your cloned repository
cat > clusters/production/apps/my-app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: applications
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: nginx:latest
          ports:
            - containerPort: 80
EOF

# Commit and push
git add .
git commit -m "Deploy my-app"
git push origin main

# Flux automatically syncs within 1 minute
kubectl get deployments -n applications
```

## Architecture

### Flux Components

```
┌─────────────────────────────────────┐
│     Flux System (flux-system)       │
├─────────────────────────────────────┤
│ source-controller                   │
│ - Watches Git repositories          │
│ - Detects changes                   │
│ - Downloads manifests               │
├─────────────────────────────────────┤
│ kustomize-controller                │
│ - Builds Kustomizations             │
│ - Applies to cluster                │
│ - Reconciles state                  │
├─────────────────────────────────────┤
│ notification-controller             │
│ - Sends alerts on sync              │
│ - Integrates with Slack/Discord    │
│ - Webhook notifications             │
└─────────────────────────────────────┘
```

### Synchronization Flow

```
1. Developer commits to Git
           ↓
2. source-controller polls Git (every 1 minute)
           ↓
3. Detects changes in cluster-config/ directory
           ↓
4. Downloads manifest YAML files
           ↓
5. kustomize-controller builds Kustomizations
           ↓
6. Applies manifests to Kubernetes cluster
           ↓
7. Cluster state matches Git repository
           ↓
8. notification-controller sends update (Slack, Discord, etc.)
```

## Repository Structure

### Recommended Layout

```
cluster-config/
├── clusters/
│   ├── production/
│   │   ├── kustomization.yaml        # Production config
│   │   └── apps/
│   │       ├── app1.yaml
│   │       └── app2.yaml
│   ├── development/
│   │   ├── kustomization.yaml        # Dev config
│   │   └── apps/
│   │       └── app-dev.yaml
│   └── flux-system/
│       ├── gotk-components.yaml
│       └── kustomization.yaml
├── infrastructure/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── namespaces.yaml
│   │   ├── rbac.yaml
│   │   └── network-policies.yaml
│   └── overlays/
│       ├── production/
│       │   └── kustomization.yaml
│       └── development/
│           └── kustomization.yaml
├── .github/
│   └── workflows/
│       └── validate.yaml             # CI/CD pipeline
└── README.md
```

### Key Files

- **`clusters/production/kustomization.yaml`**: Production apps and config
- **`clusters/development/kustomization.yaml`**: Development apps and config
- **`infrastructure/base/kustomization.yaml`**: Shared infrastructure
- **`.github/workflows/validate.yaml`**: Automated manifest validation

## Configuration

### Flux GitRepository

Tells Flux where to sync from:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m                    # Check every minute
  url: https://github.com/your-org/cluster-config
  ref:
    branch: main                  # Sync from main branch
  secretRef:
    name: flux-system             # Git credentials
```

### Flux Kustomization

Defines what to apply:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m                    # Reconcile every minute
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/production     # Apply from this path
  prune: true                     # Remove resources not in Git
  wait: true                      # Wait for resources to be ready
  timeout: 5m0s
```

### Kustomization File

Structure for applications:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

commonLabels:
  app.kubernetes.io/managed-by: flux

resources:
  - apps/app1.yaml
  - apps/app2.yaml
  - infrastructure/

images:
  - name: myapp
    newTag: v1.2.0                # Pin image version

replicas:
  - name: myapp
    count: 3                      # Production replicas

patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/spec/securityContext
        value:
          runAsNonRoot: true
```

## Daily Workflow

### Deploy New Application

1. **Create manifest**:
   ```bash
   cat > clusters/production/apps/my-app.yaml << 'EOF'
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-app
     namespace: applications
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: my-app
     template:
       metadata:
         labels:
           app: my-app
       spec:
         containers:
           - name: app
             image: my-image:1.0.0
   EOF
   ```

2. **Test locally**:
   ```bash
   kustomize build clusters/production | kubectl apply -f - --dry-run=client
   ```

3. **Commit and push**:
   ```bash
   git add clusters/production/apps/my-app.yaml
   git commit -m "Deploy my-app v1.0.0"
   git push origin main
   ```

4. **Verify**:
   ```bash
   flux-status
   kubectl get deployments -n applications
   ```

### Update Application

1. **Edit manifest**:
   ```bash
   # Update image version or replicas
   nano clusters/production/apps/my-app.yaml
   ```

2. **Commit and push**:
   ```bash
   git add .
   git commit -m "Update my-app to v1.1.0"
   git push origin main
   ```

3. **Flux automatically applies** within 1 minute

### Rollback Application

1. **Find commit to revert**:
   ```bash
   git log --oneline | grep "my-app"
   ```

2. **Revert**:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

3. **Flux automatically rolls back** the application

## Monitoring and Management

### Check Flux Status

```bash
# Quick status
flux-status

# Detailed status
flux get all --all-namespaces

# Watch reconciliation
kubectl get events -n flux-system --sort-by='.lastTimestamp' -w
```

### View Logs

```bash
# source-controller (Git monitoring)
flux-logs source-controller

# kustomize-controller (manifest application)
flux-logs kustomize-controller

# All components
kubectl logs -n flux-system -l app=source-controller -f
kubectl logs -n flux-system -l app=kustomize-controller -f
```

### Trigger Manual Sync

```bash
# Sync all
flux-sync

# Sync specific kustomization
flux reconcile kustomization my-app -n flux-system

# Sync Git source
flux reconcile source git flux-system
```

### Check Git Status

```bash
# View last commit synced
flux get sources git flux-system

# View last reconciliation
flux get kustomizations --all-namespaces
```

## Security

### Git Authentication

#### HTTPS with Personal Access Token

```bash
# Create secret with GitHub PAT
kubectl create secret generic flux-github \
  --from-literal=username=git \
  --from-literal=password=ghp_xxxxx \
  -n flux-system
```

#### SSH Key Authentication

```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/flux-repo

# Add public key to GitHub repository deploy keys

# Create secret
kubectl create secret generic flux-ssh \
  --from-file=identity=~/.ssh/flux-repo \
  --from-file=known_hosts=$(mktemp) \
  -n flux-system
```

### Secrets Management

Encrypt secrets with Sealed Secrets or External Secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: applications
type: Opaque
data:
  password: cGFzc3dvcmQx  # base64 encoded
```

**Never commit secrets to Git!** Use sealed-secrets instead:

```bash
# Install sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/sealed-secrets-0.18.0.yaml

# Create sealed secret
echo -n password1 | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal > sealed-secret.yaml

# Commit sealed-secret.yaml (safe to commit)
```

### RBAC

Flux uses service accounts with minimal permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: flux-reconciler
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]  # Configure as needed
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: flux-reconciler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flux-reconciler
subjects:
  - kind: ServiceAccount
    name: flux-system
    namespace: flux-system
```

## Troubleshooting

### Applications Not Deploying

```bash
# 1. Check Flux status
flux-status
flux get all --all-namespaces

# 2. Check for errors
kubectl describe kustomization flux-system -n flux-system

# 3. View detailed logs
flux-logs kustomize-controller

# 4. Check Git sync
flux get sources git flux-system

# 5. Manually trigger sync
flux-sync
```

### Git Sync Failing

```bash
# 1. Check Git source status
kubectl describe gitrepository flux-system -n flux-system

# 2. View source-controller logs
flux-logs source-controller

# 3. Verify Git credentials
kubectl get secret flux-system -n flux-system -o jsonpath='{.data.username}'

# 4. Check repository access
git ls-remote https://github.com/your-org/cluster-config main
```

### Manifests Invalid

```bash
# 1. Validate locally
kustomize build clusters/production

# 2. Check Kustomization status
kubectl describe kustomization flux-system -n flux-system

# 3. View validation errors
flux-logs kustomize-controller | grep -i error

# 4. Test manifest
kubectl apply -f manifest.yaml --dry-run=server
```

## Best Practices

### 1. Use Pull Requests

Never push directly to main:

```bash
# Create feature branch
git checkout -b feature/add-new-app

# Make changes
git add .
git commit -m "Add new application"

# Push and create PR
git push origin feature/add-new-app
# Create PR on GitHub for review
```

### 2. Enable Branch Protection

In GitHub repository settings:
- Require pull request reviews (at least 1)
- Require status checks to pass (CI/CD validation)
- Dismiss stale pull request approvals
- Require branches to be up to date

### 3. Use Kustomize for Variations

```
clusters/
├── production/
│   ├── kustomization.yaml
│   ├── patches/
│   │   └── replicas.yaml      # 3 replicas
│   └── apps/
├── development/
│   ├── kustomization.yaml
│   ├── patches/
│   │   └── replicas.yaml      # 1 replica
│   └── apps/
```

### 4. Semantic Versioning

Tag releases for easy reference:

```bash
# Tag release
git tag v1.0.0

# List tags
git tag -l

# Reference specific version
git checkout v1.0.0
```

### 5. Document Changes

Include detailed commit messages:

```bash
git commit -m "Deploy monitoring stack

- Install Prometheus v2.40.0
- Install Grafana v9.3.0
- Configure persistent storage (10GB)
- Enable RBAC for monitoring namespace

Fixes #123"
```

### 6. Test Before Deploying

Use CI/CD to validate:

```yaml
# .github/workflows/validate.yaml
name: Validate

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: kustomize build clusters/production
      - run: kustomize build clusters/development
```

## Integration with Other Tools

### Helm Charts

Flux can manage Helm releases:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus
  namespace: monitoring
spec:
  interval: 1m
  chart:
    spec:
      chart: kube-prometheus-stack
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
  values:
    prometheus:
      retention: 15d
```

### Notifications (Slack/Discord)

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Alert
metadata:
  name: flux-system
  namespace: flux-system
spec:
  providerRef:
    name: slack
  suspend: false
  eventSeverity: info
  eventSources:
    - kind: Kustomization
      name: '*'
    - kind: GitRepository
      name: '*'
---
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  address: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Image Updates

Automatically update image tags in Git:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageRepository
metadata:
  name: myapp
  namespace: flux-system
spec:
  image: ghcr.io/your-org/my-app
  interval: 1m
---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImagePolicy
metadata:
  name: myapp
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: myapp
  policy:
    semver:
      range: '>=1.0.0'
---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    commit:
      author:
        email: flux@example.com
        name: Flux
  update:
    strategy: Semver
  push:
    branch: main
```

## See Also

- [Flux Official Documentation](https://fluxcd.io/docs/)
- [Flux GitHub Repository](https://github.com/fluxcd/flux2)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://opengitops.dev/)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
