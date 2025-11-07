# Odroid H4 Cluster - Quick Reference

## Quick Setup (5-node cluster)

```bash
cd /home/user/ApplicationSets/odroid_h4

# 1. Bootstrap nodes (user/SSH setup)
cd cluster_setup
ansible-playbook bootstrap_ubuntu.ansible

# 2. Configure network (10.1.10.240-244)
ansible-playbook change_ips.ansible -e "cluster_size=5"
for i in {0..4}; do
  ansible-playbook apply_network_config.ansible -l pc$i -e "node_ip=10.1.10.$((240+i))"
done

# 3. Reboot and verify
ansible cluster -b -m shell -a "shutdown -r now"
sleep 60
ansible cluster -m ping

# 4. Install Kubernetes
cd ../kubernetes
ansible-playbook install_kubernetes_containerd_cluster.ansible

# 5. Verify cluster
ansible pc0 -m shell -a "kubectl get nodes"
```

## Cluster Status

```bash
# Check all nodes
ansible cluster -m ping

# Check Kubernetes cluster
ansible pc0 -m shell -a "kubectl get nodes -o wide"
ansible pc0 -m shell -a "kubectl cluster-info"
ansible pc0 -m shell -a "kubectl get pods --all-namespaces"
```

## Common Operations

### Deploy an application
```bash
ansible pc0 -m shell -a "kubectl apply -f /path/to/deployment.yaml"
```

### Check logs
```bash
ansible pc0 -m shell -a "kubectl logs <pod-name> -n <namespace>"
ansible pc0 -m shell -a "kubectl describe pod <pod-name>"
```

### Scale deployment
```bash
ansible pc0 -m shell -a "kubectl scale deployment <name> --replicas=3 -n <namespace>"
```

### SSH to node
```bash
# If using Ansible
ansible pc0 -m shell -a "commands here" -b

# Or direct SSH (if you know the IP)
ssh picocluster@10.1.10.240
```

### Reboot node
```bash
ansible pc0 -b -m shell -a "shutdown -r now"
```

### Stop all nodes
```bash
ansible cluster -b -m shell -a "shutdown -h now"
```

## Network Troubleshooting

### Check node IP
```bash
ansible pc0 -m shell -a "ip addr show eth0"
```

### Test connectivity between nodes
```bash
ansible pc0 -m shell -a "ping -c 3 pc1"
ansible pc0 -m shell -a "ssh pc1 hostname"
```

### Check DNS
```bash
ansible pc0 -m shell -a "nslookup kubernetes.default"
ansible pc0 -m shell -a "ping 8.8.8.8"
```

## Kubernetes Troubleshooting

### Node not ready
```bash
ansible pc0 -m shell -a "kubectl describe node <node-name>"
ansible <failing-node> -m shell -a "journalctl -u kubelet -n 50" -b
```

### Pod not starting
```bash
ansible pc0 -m shell -a "kubectl describe pod <pod-name> -n <namespace>"
ansible pc0 -m shell -a "kubectl logs <pod-name> -n <namespace> -c <container>"
```

### Reset Kubernetes on a node
```bash
ansible <node> -m shell -a "kubeadm reset -f" -b
# Then rejoin or redeploy
```

## File Locations

**Network Configuration**
- Network scripts: `/home/user/ApplicationSets/odroid_h4/cluster_setup/`
- README: `README_network_config.md`

**Kubernetes**
- K8s scripts: `/home/user/ApplicationSets/odroid_h4/kubernetes/`
- README: `README_odroid_h4_kubernetes.md`
- Config backup: `/etc/network/interfaces.backup.*`
- kubeconfig: `/home/picocluster/.kube/config` or `/root/.kube/config`

**Ansible Inventory**
- Location: `/etc/ansible/hosts`
- Should define `[cluster]`, `[master]`, `[worker]` groups

## IP Address Reference

**Pico3** (3 nodes)
- pc0: 10.1.10.240
- pc1: 10.1.10.241
- pc2: 10.1.10.242

**Pico5** (5 nodes)
- pc0-pc4: 10.1.10.240-244

**Pico10** (10 nodes)
- pc0-pc9: 10.1.10.240-249

**Pico20** (20 nodes)
- pc0-pc9: 10.1.10.230-239
- pc10-pc19: 10.1.10.240-249

## Important Variables

Edit playbooks to customize:

```yaml
# In Kubernetes playbooks
kubernetes_version: "1.28"      # Change K8s version
pod_network_cidr: "10.244.0.0/16"  # Pod network

# In Network config
gateway: "10.1.10.1"            # Change if needed
netmask: "255.255.255.0"
dns_servers: ["10.1.10.1", "8.8.8.8"]
```

## One-Liners

```bash
# Apply config to all nodes quickly
for i in {0..4}; do ansible-playbook ../cluster_setup/apply_network_config.ansible -l pc$i -e "node_ip=10.1.10.$((240+i))"; done

# Reboot all nodes
ansible cluster -b -m shell -a "shutdown -r now"

# Check status of all nodes
watch 'ansible cluster -m ping | grep -E "^(pc|FAILED)"'

# Scale a deployment to 5 replicas
kubectl scale deployment nginx --replicas=5

# Get events from cluster
kubectl get events --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

## Essential Commands

```bash
# Kubernetes
kubectl get nodes                           # List nodes
kubectl get pods -A                         # All pods
kubectl get svc -A                          # All services
kubectl describe node <name>                # Node details
kubectl describe pod <pod> -n <ns>          # Pod details
kubectl logs <pod> -n <ns>                  # Pod logs
kubectl exec -it <pod> -n <ns> -- bash     # Shell in pod

# Ansible
ansible cluster -m ping                     # Test connectivity
ansible -i inventory <group> -m <module>    # Run module
ansible-playbook <playbook>                 # Run playbook
ansible -e "var=value"                      # Pass variables

# Network
ip addr show eth0                           # Show IP
ip route show                               # Show routes
netplan apply                               # Apply netplan
systemctl restart networking                # Restart network
```

## Support

For detailed guides, see:
- `cluster_setup/README_network_config.md` - Network configuration details
- `kubernetes/README_odroid_h4_kubernetes.md` - Kubernetes setup guide

## Emergency Recovery

```bash
# If nodes become unreachable after network change
# You may need physical access to reset or console in

# Restore previous network config
sudo cp /etc/network/interfaces.backup.XXXXXX /etc/network/interfaces
sudo systemctl restart networking

# Or reconfigure manually
sudo netplan apply

# Force IP assignment via netplan
sudo nano /etc/netplan/99-custom.yaml
# Edit and save, then:
sudo netplan apply
```
