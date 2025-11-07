# K3s Installation Guide for Odroid H4

K3s is a lightweight, single-binary Kubernetes distribution optimized for edge devices, IoT, and resource-constrained environments. It's perfect for Odroid H4 clusters where you want full Kubernetes functionality with minimal overhead.

## What is K3s?

K3s is:
- **Lightweight**: ~50MB binary vs 100MB+ for full Kubernetes
- **Fast**: Single binary installation in seconds vs minutes
- **Resource-efficient**: Perfect for 2GB+ RAM devices
- **Production-ready**: Certified Kubernetes distribution
- **Simple**: Built-in SQLite or optionally uses external database
- **Secure**: Uses TLS for all communication by default

## Prerequisites

- Odroid H4 nodes running Ubuntu (18.04, 20.04, or 22.04)
- SSH access to all nodes
- Network configured via `apply_network_config.ansible`
- Passwordless sudo access (or use `-b` flag with Ansible)
- At least 512MB free RAM per node (1GB+ recommended)

## Installation Options

### Option 1: Single-Node K3s

Perfect for development, testing, or single-node deployments.

```bash
cd /home/user/ApplicationSets/odroid_h4/kubernetes

# Install on a single node
ansible-playbook install_k3s_single.ansible -l pc0
```

**What this does:**
- Installs K3s server (includes everything needed)
- Disables swap (required for Kubernetes)
- Sets up kubeconfig for root and picocluster users
- Creates kubectl symlink for easy access
- Configures K3s to run without Traefik ingress

**Verify installation:**
```bash
# On the node or remotely via Ansible
k3s kubectl get nodes
k3s kubectl get pods --all-namespaces
```

### Option 2: Multi-Node K3s Cluster

For distributed workloads across multiple nodes.

```bash
# Install across entire cluster
ansible-playbook install_k3s_cluster.ansible
```

**Cluster Requirements:**
- One master node (defined in `[master]` group - typically pc0)
- Multiple worker nodes (defined in `[worker]` group - typically pc1+)

**Edit your Ansible inventory** (`/etc/ansible/hosts`):

```ini
[cluster]
pc0
pc1
pc2
pc3

[master]
pc0

[worker]
pc[1:3]
```

**What the cluster script does:**
1. Prepares all nodes (install dependencies, disable swap, etc.)
2. Installs K3s server on master node
3. Extracts node token and distributes to workers
4. Installs K3s agent on worker nodes
5. Verifies all nodes are ready
6. Sets up kubeconfig for both users

**Verify cluster:**
```bash
ansible pc0 -m shell -a "k3s kubectl get nodes -o wide"
ansible pc0 -m shell -a "k3s kubectl get pods -A"
```

## K3s vs Full Kubernetes vs MicroK8s

| Feature | K3s | Kubernetes | MicroK8s |
|---------|-----|-----------|----------|
| Binary Size | ~50MB | 100MB+ | Via snap |
| Install Time | ~30 seconds | 5+ minutes | 2+ minutes |
| Memory Usage | ~100-200MB | 300MB+ | 200MB+ |
| Database | SQLite (default) | etcd | etcd |
| Networking | flannel (default) | Multiple options | Multiple options |
| Addons | Minimal | Install separate | Pre-packaged |
| Use Case | Edge/IoT/Dev | Enterprise | Quick prototyping |
| Learning Curve | Easy | Steep | Medium |

**Choose K3s if:** You want lightweight, simple Kubernetes with minimal setup
**Choose Kubernetes if:** You need advanced features, HA, or enterprise support
**Choose MicroK8s if:** You want snap-based package management and easy addons

## Configuration

### K3s Defaults

- **Database**: SQLite at `/var/lib/rancher/k3s/server/db`
- **Config**: `/etc/rancher/k3s/k3s.yaml`
- **Data**: `/var/lib/rancher/k3s`
- **Service Port**: 6443
- **Disable by default**: Traefik (ingress), ServiceLB

### Customizing Installation

Edit the playbooks to modify:

```yaml
# K3s version
k3s_version: "latest"  # or "v1.28.0", "v1.27.5", etc.

# Server installation flags (in install_k3s_cluster.ansible)
INSTALL_K3S_EXEC: "server --disable traefik --disable servicelb"

# Add additional flags like:
# INSTALL_K3S_EXEC: "server --disable traefik --flannel-backend=vxlan"
```

### Enable Addons

K3s has minimal default addons. To add more:

```bash
# CoreDNS is built-in
k3s kubectl get deployment -n kube-system coredns

# Add Traefik ingress (if disabled)
k3s kubectl apply -f https://github.com/traefik/traefik-helm-chart/releases/download/v23.0.0/traefik-crd-v23.0.0.tgz

# Add MetalLB for LoadBalancer services
k3s kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
```

## Common Operations

### Check cluster status
```bash
k3s kubectl get nodes -o wide
k3s kubectl get pods --all-namespaces
k3s kubectl cluster-info
```

### Deploy an application
```bash
k3s kubectl apply -f deployment.yaml
k3s kubectl get pods
k3s kubectl logs <pod-name>
```

### Scale deployment
```bash
k3s kubectl scale deployment nginx --replicas=5
k3s kubectl rollout status deployment nginx
```

### Get node info
```bash
k3s kubectl describe node pc0
k3s kubectl top nodes  # Resource usage
```

### Access pod shell
```bash
k3s kubectl exec -it <pod-name> -- bash
```

### View service information
```bash
k3s kubectl get svc -A
k3s kubectl describe svc <service-name>
```

## Troubleshooting

### Checking K3s service status
```bash
# On the node
systemctl status k3s          # Master node
systemctl status k3s-agent    # Worker nodes

# Check logs
journalctl -u k3s -n 100 --no-pager
journalctl -u k3s-agent -n 100 --no-pager
```

### Worker node not joining
```bash
# Verify master is accessible from worker
ansible pc1 -m shell -a "curl -k https://10.1.10.240:6443" -b

# Check worker agent logs
ansible pc1 -m shell -a "journalctl -u k3s-agent -n 50 --no-pager" -b

# Uninstall and retry
ansible pc1 -m shell -a "/usr/local/bin/k3s-agent-uninstall.sh" -b
```

### Pod not starting
```bash
k3s kubectl describe pod <pod-name>
k3s kubectl logs <pod-name> -c <container>
k3s kubectl events --sort-by='.lastTimestamp'
```

### Network connectivity issues
```bash
# Test inter-node connectivity
ansible pc0 -m shell -a "ping -c 3 pc1"

# Check service DNS resolution
k3s kubectl run -it debug --image=nicolaka/netshoot -- bash
# Inside the pod:
nslookup kubernetes.default
ping 10.1.10.241  # Another node
```

## Advanced Configuration

### Using PostgreSQL or MySQL instead of SQLite

For production clusters with high availability:

```bash
# Edit the playbook to use:
INSTALL_K3S_EXEC: "server --datastore-endpoint='postgres://user:password@dbhost/k3s'"

# Or for MySQL:
INSTALL_K3S_EXEC: "server --datastore-endpoint='mysql://user:password@dbhost/k3s'"
```

### Custom Flannel backend

K3s uses flannel by default. To change:

```bash
INSTALL_K3S_EXEC: "server --flannel-backend=vxlan"  # or host-gw, ipsec, etc.
```

### Enable HA (High Availability)

For production with multiple master nodes:

```bash
# Setup requires external load balancer or internal API server endpoint
INSTALL_K3S_EXEC: "server --cluster-init"
INSTALL_K3S_EXEC: "server --server https://api.example.com:6443"
```

## Performance Tuning

For optimal performance on Odroid H4:

1. **Increase file descriptors**:
   ```bash
   ulimit -n 65536
   # Add to /etc/security/limits.conf
   ```

2. **Adjust kubelet settings**:
   ```bash
   # Edit /etc/rancher/k3s/kubelet.config
   # Add memory/cpu limits for pods
   ```

3. **Monitor resource usage**:
   ```bash
   k3s kubectl top nodes
   k3s kubectl top pods --all-namespaces
   ```

## Security Considerations

1. **TLS is enabled by default** - All communication is encrypted
2. **RBAC is enabled** - Control what users/pods can do
3. **Network policies** - Restrict pod-to-pod communication
4. **Regular updates** - Keep K3s updated with security patches
5. **Secure kubeconfig** - Protect `/etc/rancher/k3s/k3s.yaml`

## Uninstalling K3s

If you need to remove K3s:

```bash
# On master node
sudo /usr/local/bin/k3s-uninstall.sh

# On worker nodes
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

## File Locations

- **Installation script**: `install_k3s_single.ansible`, `install_k3s_cluster.ansible`
- **kubeconfig**: `/etc/rancher/k3s/k3s.yaml` (root), `/home/picocluster/.kube/config`
- **Data directory**: `/var/lib/rancher/k3s`
- **Database**: `/var/lib/rancher/k3s/server/db/state.db` (SQLite)
- **Logs**: Via `journalctl -u k3s`

## Quick Comparison: K3s Cluster Setup Time

Single node: ~30 seconds
3-node cluster: ~2 minutes
10-node cluster: ~5 minutes

(vs 5-15+ minutes for full Kubernetes)

## Useful Commands Summary

```bash
# Installation
ansible-playbook install_k3s_single.ansible -l pc0
ansible-playbook install_k3s_cluster.ansible

# Cluster info
k3s kubectl get nodes
k3s kubectl get pods -A
k3s kubectl cluster-info dump

# Troubleshooting
k3s kubectl describe node <node>
k3s kubectl logs <pod> -n <namespace>
journalctl -u k3s -f

# Scaling
k3s kubectl scale deployment nginx --replicas=5
k3s kubectl autoscale deployment nginx --min=2 --max=10

# Update K3s
# Edit playbook k3s_version and re-run
```

## References

- [K3s Official Documentation](https://docs.k3s.io/)
- [K3s GitHub Repository](https://github.com/k3s-io/k3s)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Flannel Networking](https://github.com/flannel-io/flannel)

## Support

For issues specific to K3s on Odroid H4:
1. Check K3s logs: `journalctl -u k3s -n 100`
2. Verify network connectivity between nodes
3. Check available disk space and memory
4. Consult K3s documentation for advanced troubleshooting

## Next Steps

After K3s is running:

1. **Deploy applications**: Start deploying workloads
2. **Configure ingress**: Set up external access
3. **Enable monitoring**: Install Prometheus/Grafana
4. **Setup backups**: Backup SQLite database or etcd
5. **Scale workloads**: Test multi-node deployment
