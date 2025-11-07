# Odroid H4 Kubernetes Installation Guide

This directory contains Ansible playbooks for setting up Kubernetes on Odroid H4 nodes (Intel-based Ubuntu systems) with multiple installation options.

## Overview

The Odroid H4 is an Intel-based single-board computer running Ubuntu. These scripts provide three different Kubernetes setup options:

1. **Stock Kubernetes with containerd (Single-node)** - For development/testing on one node
2. **Stock Kubernetes with containerd (Cluster)** - Full multi-node cluster setup
3. **MicroK8s** - Lightweight, simplified Kubernetes installation

## Prerequisites

- Odroid H4 nodes running Ubuntu (18.04, 20.04, or 22.04)
- SSH access to all nodes with passwordless authentication configured
- Ansible installed on your control machine
- Nodes configured with static IP addresses using the network configuration scripts

## Network Configuration

Before deploying Kubernetes, configure your nodes' network settings.

### Step 1: Plan Your IP Configuration

Use the IP configuration script to plan your network setup:

```bash
cd /home/user/ApplicationSets/odroid_h4/cluster_setup

# For Pico3, Pico5, Pico10 clusters (default: 10.1.10.240+)
ansible-playbook change_ips.ansible -e "cluster_size=5 start_ip_octet=240"

# For Pico20 clusters (10.1.10.230-239 for first 10 nodes)
ansible-playbook change_ips.ansible -e "cluster_size=20 start_ip_octet=230"
```

This script displays the planned IP assignments. **Review the output carefully.**

### Step 2: Apply Network Configuration

Apply the network configuration to each node individually:

```bash
# For pc0 with IP 10.1.10.240
ansible-playbook apply_network_config.ansible -l pc0 -e "node_ip=10.1.10.240"

# For pc1 with IP 10.1.10.241
ansible-playbook apply_network_config.ansible -l pc1 -e "node_ip=10.1.10.241"

# Repeat for each node...
```

### Step 3: Reboot and Verify

```bash
# Reboot all nodes
ansible cluster -m shell -a "shutdown -r now" -b

# Wait a few minutes, then verify connectivity
ansible cluster -m ping
```

## Kubernetes Installation Options

### Option 1: Single-Node Kubernetes with containerd

Best for: Development, testing, or single-node deployments

```bash
# Install on a single node (e.g., pc0)
ansible-playbook install_kubernetes_containerd_single.ansible -l pc0
```

**What this does:**
- Installs containerd as the container runtime
- Installs kubelet, kubeadm, and kubectl
- Initializes a Kubernetes cluster
- Installs Flannel CNI for pod networking
- Untaints the master node to allow pod scheduling

**Verify installation:**
```bash
ansible pc0 -m shell -a "kubectl get nodes"
ansible pc0 -m shell -a "kubectl get pods --all-namespaces"
```

### Option 2: Multi-Node Kubernetes Cluster with containerd

Best for: Production clusters, testing distributed applications

```bash
# Deploy to entire cluster
ansible-playbook install_kubernetes_containerd_cluster.ansible
```

**What this does:**
1. Prepares all nodes (installs containerd, kernel modules, etc.)
2. Initializes the master node (pc0)
3. Generates join token for worker nodes
4. Joins all worker nodes (pc1, pc2, etc.)
5. Installs Flannel CNI
6. Verifies cluster is ready

**Cluster Requirements:**
- One master node (defined in `[master]` group - typically pc0)
- Multiple worker nodes (defined in `[worker]` group - typically pc1+)

**Edit your Ansible inventory** (`/etc/ansible/hosts`) to define your cluster:

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

**Verify cluster health:**
```bash
ansible pc0 -m shell -a "kubectl get nodes -o wide"
ansible pc0 -m shell -a "kubectl get pods --all-namespaces"
ansible pc0 -m shell -a "kubectl cluster-info"
```

### Option 3: MicroK8s Installation

Best for: Quick setup, simplified management, single/small clusters

```bash
# Install MicroK8s on all nodes
ansible-playbook install_microk8s.ansible

# Or on a single node
ansible-playbook install_microk8s.ansible -l pc0
```

**What this does:**
- Installs MicroK8s via snap
- Waits for it to be ready
- Enables essential addons (DNS, storage, ingress, RBAC)
- Sets up kubeconfig for the picocluster user
- Provides kubectl symlink

**Using MicroK8s:**
```bash
# Check status
ansible pc0 -m shell -a "microk8s status"

# Run kubectl commands
ansible pc0 -m shell -a "microk8s kubectl get nodes"

# Enable additional addons
ansible pc0 -m shell -a "microk8s enable metallb"
ansible pc0 -m shell -a "microk8s enable dashboard"

# Join worker nodes to cluster
ansible pc0 -m shell -a "microk8s add-node"  # Get join command on master
ansible pc1 -m shell -a "microk8s join <token>"  # Join on worker
```

## Configuration Details

### containerd Configuration

Both containerd-based setups use systemd cgroup driver for better integration with modern Linux systems. The configuration is automatically applied during installation.

**Key settings:**
- CRI socket: `/run/containerd/containerd.sock`
- Cgroup driver: systemd
- Pod CIDR: 10.244.0.0/16

### Kubernetes Versions

- Default version: 1.28 (latest stable)
- Adjust `kubernetes_version` variable in playbooks for specific versions

### Network Plugins

- **containerd setups**: Flannel (default) - lightweight, simple, recommended for ARM
- **MicroK8s**: Built-in networking with customizable CNI options

## Troubleshooting

### Nodes not joining cluster

```bash
# Check kubelet logs on worker node
ansible pc1 -m shell -a "journalctl -u kubelet -n 100 --no-pager" -b

# Reset kubeadm and try again
ansible pc1 -m shell -a "kubeadm reset -f" -b
ansible-playbook install_kubernetes_containerd_cluster.ansible -l pc1
```

### Pods not starting

```bash
# Check pod status details
kubectl describe pod <pod-name> -n <namespace>

# Check network connectivity
kubectl get nodes
kubectl get pods -A
```

### containerd issues

```bash
# Check containerd status
ansible pc0 -m shell -a "systemctl status containerd" -b

# Restart containerd
ansible pc0 -m systemd -a "name=containerd state=restarted" -b

# Check containerd logs
ansible pc0 -m shell -a "journalctl -u containerd -n 50 --no-pager" -b
```

## Common Tasks

### Add a new node to existing cluster

```bash
# Set up network configuration
ansible-playbook apply_network_config.ansible -l pc5 -e "node_ip=10.1.10.245"

# Install Kubernetes components
ansible-playbook install_kubernetes_containerd_cluster.ansible -l pc5

# Or for MicroK8s
ansible-playbook install_microk8s.ansible -l pc5
microk8s add-node  # On master to get join command
```

### Remove a node from cluster

```bash
# On the node to remove
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <node-name>

# Or reset the node
ansible <node> -m shell -a "kubeadm reset -f" -b
```

### Upgrade Kubernetes version

```bash
# Plan the upgrade
ansible-playbook install_kubernetes_containerd_cluster.ansible -e "kubernetes_version=1.29"

# Apply carefully with minimal disruption
```

## Performance Tuning

For better performance on limited resources:

1. **Reduce CPU requests** in pod specifications
2. **Enable resource limits** to prevent one pod from consuming all resources
3. **Use node affinity** to distribute workloads
4. **Monitor resource usage**: `kubectl top nodes`, `kubectl top pods`

## Security Considerations

1. **Enable RBAC** (enabled by default in all setups)
2. **Network policies**: Restrict pod-to-pod communication
3. **Pod security policies**: Control what pods can do
4. **Regular updates**: Keep Kubernetes and containerd updated
5. **SSH key-based authentication**: All nodes should use SSH keys

## File Locations

- **Network config**: `cluster_setup/apply_network_config.ansible`
- **containerd single node**: `kubernetes/install_kubernetes_containerd_single.ansible`
- **containerd cluster**: `kubernetes/install_kubernetes_containerd_cluster.ansible`
- **MicroK8s**: `kubernetes/install_microk8s.ansible`
- **kubeconfig files**:
  - Root: `/root/.kube/config`
  - picocluster user: `/home/picocluster/.kube/config`

## Next Steps

After Kubernetes is running:

1. **Deploy applications**: Use kubectl to deploy your workloads
2. **Set up ingress**: Configure external access to services
3. **Enable monitoring**: Install Prometheus/Grafana for cluster monitoring
4. **Configure storage**: Set up persistent volumes for stateful applications
5. **Implement backups**: Backup cluster state and configurations

## Support and Troubleshooting

For detailed debugging:

```bash
# Collect detailed cluster info
kubectl cluster-info dump --all-namespaces --output-directory=./cluster-dump

# Check component status (k8s 1.26+)
kubectl get cs

# For older versions
kubectl get componentstatuses
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [containerd Project](https://containerd.io/)
- [Flannel Network Plugin](https://github.com/coreos/flannel)
- [MicroK8s Documentation](https://microk8s.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
