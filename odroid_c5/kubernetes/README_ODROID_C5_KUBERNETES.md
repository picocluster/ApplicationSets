# Odroid C5 Kubernetes Installation Guide

This directory contains Ansible playbooks for setting up Kubernetes on Odroid C5 nodes (Debian-based ARM64 system).

## Odroid C5 Overview

The Odroid C5 is a powerful ARM64 single-board computer with:
- Samsung Exynos processor (ARMv8)
- 64-bit ARM architecture
- Gigabit Ethernet
- Debian-based operating system
- Excellent for cluster computing and edge applications

## Operating System

**Odroid C5 runs**: Debian-based Linux (Ubuntu 18.04+ compatible)
- Uses `apt` package manager
- Full Kubernetes and containerization support
- Excellent stability for production clusters

## Kubernetes Installation Options

This guide provides **4 Kubernetes installation options** for Odroid C5:

1. **Stock Kubernetes with containerd (Single-node)**
   - File: `install_kubernetes_containerd_single.ansible`
   - Use for: Development/testing on single node

2. **Stock Kubernetes with containerd (Cluster)**
   - File: `install_kubernetes_containerd_cluster.ansible`
   - Use for: Multi-node production clusters

3. **K3s (Single-node)**
   - File: `install_k3s_single.ansible`
   - Use for: Lightweight single-node deployments

4. **K3s (Cluster)**
   - File: `install_k3s_cluster.ansible`
   - Use for: Lightweight multi-node clusters (Recommended)

## Why C5 is Great for Kubernetes

✅ **64-bit ARM**: Full ARM64 support for all Kubernetes images
✅ **Debian-based**: Native package management with apt
✅ **Powerful**: Capable processor for edge/cluster workloads
✅ **Reliable**: Proven Kubernetes support on ARM
✅ **Community**: Well-established Odroid community

## Prerequisites

- Odroid C5 nodes running Debian-based OS
- SSH access to all nodes with passwordless authentication
- Ansible installed on your control machine
- Network configured via cluster_setup scripts
- 2GB+ RAM per node (4GB+ recommended for production)
- Gigabit Ethernet connection recommended

## Quick Start

### Step 1: Configure Network

```bash
cd cluster_setup

# Plan IP configuration
ansible-playbook change_ips.ansible -e "cluster_size=5"

# Apply to each node
for i in {0..4}; do
  ansible-playbook apply_network_config.ansible -l pc$i -e "node_ip=10.1.10.$((240+i))"
done

# Reboot
ansible cluster -b -m shell -a "shutdown -r now"
```

### Step 2: Choose Your Kubernetes

#### Option A: Stock Kubernetes (Cluster) - Full-Featured

```bash
cd ../kubernetes
ansible-playbook install_kubernetes_containerd_cluster.ansible
```

#### Option B: K3s (Cluster) - Lightweight (Recommended for C5)

```bash
cd ../kubernetes
ansible-playbook install_k3s_cluster.ansible
```

### Step 3: Verify Installation

```bash
# Check cluster status
ansible pc0 -m shell -a "kubectl get nodes"
ansible pc0 -m shell -a "kubectl get pods --all-namespaces"
```

## Detailed Installation

### Prerequisites for All Installations

1. **Modify Ansible Inventory**

Edit `/etc/ansible/hosts`:

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

2. **Verify SSH Access**

```bash
ansible cluster -m ping
```

### For Stock Kubernetes (Containerd)

#### Single-Node

```bash
ansible-playbook install_kubernetes_containerd_single.ansible -l pc0
```

**What it does:**
- Installs containerd container runtime
- Installs kubelet, kubeadm, kubectl
- Initializes single-node cluster
- Installs Flannel CNI
- Sets up kubeconfig

#### Cluster

```bash
ansible-playbook install_kubernetes_containerd_cluster.ansible
```

**What it does:**
1. Prepares all nodes
2. Initializes master (pc0)
3. Joins worker nodes
4. Installs Flannel networking
5. Verifies cluster

**Note**: This uses the older Docker/containerd approach. K3s is more modern and recommended.

### For K3s (Lightweight)

#### Single-Node

```bash
ansible-playbook install_k3s_single.ansible -l pc0
```

**Benefits:**
- 30-second installation
- ~50MB binary
- SQLite built-in
- Full Kubernetes features

#### Cluster

```bash
ansible-playbook install_k3s_cluster.ansible
```

**What it does:**
1. Prepares all nodes
2. Installs K3s server on master
3. Automatically joins worker nodes
4. Verifies cluster readiness

**This is the recommended approach for C5 clusters.**

## Kubernetes vs K3s for Odroid C5

| Feature | Kubernetes | K3s |
|---------|-----------|-----|
| Binary Size | 100MB+ | ~50MB |
| Install Time | 5-10 min | 30 sec |
| Memory Usage | 300MB+ | 100-200MB |
| Features | Full Kubernetes | All Kubernetes features |
| Database | etcd (external) | SQLite (built-in) |
| Networking | Flannel | Flannel |
| **Recommendation** | Good | **Better for C5** |

### Why K3s for Odroid C5

- **Resource Efficient**: C5 has limited resources compared to VMs
- **Fast Setup**: Quick deployment for testing/production
- **Production Ready**: Still full Kubernetes with all features
- **Modern**: Uses containerd by default
- **Proven**: Widely used in IoT/edge computing

## Verification and Testing

### Check Cluster Status

```bash
# View nodes
ansible pc0 -m shell -a "kubectl get nodes -o wide"

# View pods
ansible pc0 -m shell -a "kubectl get pods --all-namespaces"

# View cluster info
ansible pc0 -m shell -a "kubectl cluster-info"
```

### Test Node Communication

```bash
# Ping between nodes
ansible pc0 -m shell -a "ping -c 3 pc1"

# Test Kubernetes DNS
ansible pc0 -m shell -a "kubectl run -it debug --image=nicolaka/netshoot -- bash"
# Inside pod: nslookup kubernetes.default
```

### Deploy Test Pod

```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx

# Scale it
kubectl scale deployment nginx --replicas=3

# Check pods across nodes
kubectl get pods -o wide
```

## Troubleshooting

### Cluster Won't Initialize

```bash
# Check containerd status (Stock K8s)
ansible pc0 -m shell -a "systemctl status containerd" -b

# Check K3s status
ansible pc0 -m shell -a "systemctl status k3s" -b

# View logs
ansible pc0 -m shell -a "journalctl -u kubelet -n 50" -b
ansible pc0 -m shell -a "journalctl -u k3s -n 50" -b
```

### Worker Node Not Joining

```bash
# Verify network connectivity
ansible pc1 -m shell -a "curl -k https://10.1.10.240:6443"

# Check worker logs
ansible pc1 -m shell -a "journalctl -u kubelet -n 100" -b
ansible pc1 -m shell -a "journalctl -u k3s-agent -n 100" -b

# Reset and retry
ansible pc1 -m shell -a "kubeadm reset -f" -b
```

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check node resources
kubectl top nodes
kubectl top pods --all-namespaces

# Check if node is ready
kubectl describe node pc1
```

## Performance Considerations for C5

1. **RAM**: Monitor memory usage
   ```bash
   kubectl top nodes
   free -h
   ```

2. **CPU**: Set resource requests/limits
   ```yaml
   resources:
     requests:
       memory: "64Mi"
       cpu: "50m"
     limits:
       memory: "128Mi"
       cpu: "100m"
   ```

3. **Storage**: C5 often has limited disk space
   - Use external USB/SSD storage
   - Configure persistent volumes appropriately

4. **Networking**: GbE connection recommended
   - Cluster communication is bandwidth-sensitive
   - Use dedicated network switch if possible

## Security Best Practices

1. **RBAC**: Always enable (default)
2. **Network Policies**: Restrict pod communication
3. **Pod Security**: Use security contexts
4. **Regular Updates**: Keep K8s/K3s updated
5. **Backups**: Regular cluster state backups

## File Locations

### Kubernetes (Stock)
- **kubeconfig**: `/root/.kube/config`, `/home/picocluster/.kube/config`
- **Kubelet config**: `/etc/kubernetes/kubelet.conf`
- **Logs**: `journalctl -u kubelet`

### K3s
- **kubeconfig**: `/etc/rancher/k3s/k3s.yaml`
- **Data**: `/var/lib/rancher/k3s`
- **Logs**: `journalctl -u k3s` (master), `journalctl -u k3s-agent` (workers)

### Network Config
- **interfaces**: `/etc/network/interfaces` (Odroid C5)

## Common Tasks

### Deploy Application

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/myapp
```

### Scale Deployment

```bash
kubectl scale deployment nginx --replicas=5
kubectl get pods -o wide
```

### Update Kubernetes/K3s

Edit the playbook `k3s_version` or `kubernetes_version` variable and re-run.

### Add New Node to Cluster

```bash
# Network config
ansible-playbook ../cluster_setup/apply_network_config.ansible -l pc5 -e "node_ip=10.1.10.245"

# K3s
ansible-playbook install_k3s_cluster.ansible -l pc5

# Kubernetes
ansible-playbook install_kubernetes_containerd_cluster.ansible -l pc5
```

### Monitor Cluster

```bash
# Watch nodes
watch kubectl get nodes

# Watch pods
watch kubectl get pods --all-namespaces

# Get events
kubectl get events --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods -A
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [containerd Project](https://containerd.io/)
- [Flannel Networking](https://github.com/flannel-io/flannel)
- [Odroid C5 Documentation](https://wiki.odroid.com/odroid-c5/odroid-c5)

## Next Steps

After installation:
1. Deploy applications
2. Set up ingress for external access
3. Configure persistent storage
4. Enable monitoring (Prometheus/Grafana)
5. Set up logging (ELK stack or similar)
6. Configure backups

## Support

For issues:
1. Check logs: `journalctl -u kubelet` or `journalctl -u k3s`
2. Verify network: `ansible cluster -m ping`
3. Check resources: `kubectl top nodes`
4. Review cluster info: `kubectl cluster-info dump`

## Updating from Old C5 Kubernetes Scripts

If you have old C5 Kubernetes installations:

1. **Old scripts used**:
   - Docker 18.06.3 (from 2019)
   - Kubernetes 1.9.4 (very outdated)

2. **New scripts use**:
   - containerd (modern container runtime)
   - Kubernetes 1.28+ (current stable)
   - K3s latest (recommended)

3. **Migration**:
   - Backup your data
   - Reset nodes: `kubeadm reset -f`
   - Re-run new installation scripts
