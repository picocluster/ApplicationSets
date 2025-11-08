# PicoCluster Comprehensive Integration Guide

This guide covers integrating all 9 cluster software solutions across the PicoCluster platforms (Odroid H4, RPI5 Ubuntu/Raspbian, Odroid C5).

## Cluster Software Stack Overview

### Tier 1: Foundational Infrastructure
These solutions form the base of your cluster infrastructure.

#### 1. **Network & Service Discovery**
- **Consul**: Service registry, key-value store, health checking, DNS interface
  - Enables automatic service discovery across cluster
  - Provides distributed configuration management
  - DNS-based service lookup (*.service.consul)
  - Health checks prevent routing to unhealthy services

#### 2. **Load Balancing & Reverse Proxy**
- **Traefik**: Modern load balancer with automatic service discovery
  - Watches Docker/Kubernetes for running services
  - Automatically configures routes via labels
  - SSL/TLS termination with Let's Encrypt support
  - Integrates with Consul for dynamic backend discovery

#### 3. **Distributed Storage**
- **Ceph**: Distributed storage with 3+ node redundancy
  - Object storage (RadosGW) for S3-compatible storage
  - Block storage (RBD) for VM and container volumes
  - File storage (CephFS) for shared filesystem needs
  - Automatic data replication across 3+ nodes

### Tier 2: Workload Orchestration
These handle running and managing applications.

#### 4. **Container Orchestration** (Choose One)
Multiple options available:

**Kubernetes Variants:**
- Stock Kubernetes (kubeadm + containerd): Full-featured, production-grade
- K3s: Lightweight Kubernetes, ideal for resource-constrained devices
- MicroK8s: Snap-based, easy installation on Ubuntu

**Alternative Orchestrators:**
- **Nomad**: Multi-workload orchestrator supporting Docker, raw binaries, Java
- **Docker Swarm**: Native Docker clustering, simpler than Kubernetes

#### 5. **Container Runtime**
- **Docker**: Standard container runtime with Docker Swarm clustering option
- **LXD**: System containers, lightweight VM alternative with clustering

### Tier 3: Registry & Image Management
#### 6. **Private Container Registry**
- **Harbor**: Enterprise-grade private registry with:
  - Image vulnerability scanning
  - Image signing and verification
  - Replication to multiple registries
  - RBAC and project management
  - Webhook support for CI/CD

### Tier 4: Platform Services
#### 7. **IoT & Edge Computing**
- **EdgeX Foundry**: Lightweight IoT edge platform
  - Device integration and management
  - Data collection and processing
  - Cloud connectivity
  - Microservices-based architecture

### Tier 5: Virtualization (x86-64 only)
#### 8. **KVM/QEMU** (Odroid H4 only)
- Hypervisor for running VMs on bare metal
- Lower overhead than Proxmox
- Direct control for advanced use cases

#### 9. **Proxmox VE** (Odroid H4 only)
- **Note**: x86-64 only, NOT available on RPI5 or Odroid C5 (ARM64)
- Complete virtualization platform combining KVM and LXC
- Web-based management interface
- Clustering support for HA

---

## Recommended Stack Configurations

### Configuration 1: Kubernetes-Based Production Cluster
Best for: Container-centric deployments, cloud-native applications

```
1. Network: Consul (service discovery)
2. Load Balancer: Traefik (ingress controller alternative)
3. Orchestration: Kubernetes (K3s for ARM, stock for H4)
4. Storage: Ceph (persistent volumes)
5. Registry: Harbor (container images)
```

**Installation Order:**
1. Deploy Consul cluster for service discovery
2. Deploy Kubernetes cluster
3. Deploy Ceph cluster (minimum 3 nodes)
4. Configure persistent volume support via Ceph RBD
5. Deploy Harbor registry
6. Deploy Traefik as ingress controller

### Configuration 2: Nomad + Docker Stack
Best for: Mixed workload types, flexibility, simpler than Kubernetes

```
1. Network: Consul (Nomad uses Consul internally)
2. Load Balancer: Traefik (reverse proxy)
3. Orchestration: Nomad (supports Docker, raw binaries, Java)
4. Storage: Ceph (for persistent data)
5. Registry: Harbor (container images)
```

**Installation Order:**
1. Deploy Consul cluster
2. Deploy Nomad cluster (shares Consul for service discovery)
3. Deploy Ceph cluster
4. Deploy Harbor registry
5. Deploy Traefik for load balancing

### Configuration 3: Docker Swarm + LXD
Best for: Lightweight, simple clustering

```
1. Network: Consul (optional, for advanced service discovery)
2. Orchestration: Docker Swarm (native Docker clustering)
3. Containers: LXD (system containers for resource isolation)
4. Storage: Ceph (distributed storage)
5. Registry: Harbor (private images)
```

**Installation Order:**
1. Deploy Docker Swarm cluster
2. Deploy LXD on nodes for system containers
3. Deploy Ceph cluster
4. Deploy Harbor registry
5. Optional: Deploy Consul for advanced service discovery

### Configuration 4: EdgeX Foundry IoT Platform
Best for: IoT data collection and edge processing

```
1. Core: EdgeX Foundry services
2. Storage: Ceph (data persistence)
3. Registry: Harbor (service images)
4. Network: Consul (service coordination)
5. Load Balancing: Traefik (API gateway)
```

---

## Installation Recipes

### Recipe 1: Complete Kubernetes Cluster with Ceph

```bash
# 1. Network Setup
ansible-playbook rpi5/cluster_setup/apply_network_config_ubuntu.ansible

# 2. Consul Cluster
ansible-playbook rpi5/consul/install_consul_single_ubuntu.ansible -l pc0
ansible-playbook rpi5/consul/install_consul_single_ubuntu.ansible -l pc1
ansible-playbook rpi5/consul/install_consul_single_ubuntu.ansible -l pc2
ansible-playbook rpi5/consul/setup_consul_cluster_ubuntu.ansible

# 3. Kubernetes Cluster
ansible-playbook rpi5/kubernetes/install_k3s_single_ubuntu.ansible -l pc0
ansible-playbook rpi5/kubernetes/install_k3s_cluster_ubuntu.ansible

# 4. Ceph Storage Cluster (requires 3+ nodes)
ansible-playbook rpi5/ceph/install_ceph_single_ubuntu.ansible -l pc0
ansible-playbook rpi5/ceph/install_ceph_single_ubuntu.ansible -l pc1
ansible-playbook rpi5/ceph/install_ceph_single_ubuntu.ansible -l pc2
ansible-playbook rpi5/ceph/setup_ceph_cluster_ubuntu.ansible

# 5. Add OSDs to Ceph (on each node with available disk)
# On each node: sudo ceph-volume lvm prepare --data /dev/sdb
# Then: sudo ceph-volume lvm activate --all

# 6. Harbor Registry
ansible-playbook rpi5/harbor/install_harbor_single_ubuntu.ansible -l pc0

# 7. Traefik Load Balancer
ansible-playbook rpi5/traefik/install_traefik_single_ubuntu.ansible -l pc0
```

### Recipe 2: Nomad + Consul Stack

```bash
# 1. Network Setup
ansible-playbook odroid_h4/cluster_setup/apply_network_config.ansible

# 2. Consul Cluster (Nomad requires Consul)
ansible-playbook odroid_h4/consul/install_consul_single.ansible -l pc0
ansible-playbook odroid_h4/consul/install_consul_single.ansible -l pc1
ansible-playbook odroid_h4/consul/setup_consul_cluster.ansible

# 3. Nomad Cluster (uses Consul for coordination)
ansible-playbook odroid_h4/nomad/install_nomad_single.ansible -l pc0
ansible-playbook odroid_h4/nomad/install_nomad_single.ansible -l pc1
ansible-playbook odroid_h4/nomad/setup_nomad_cluster.ansible

# 4. Harbor Registry
ansible-playbook odroid_h4/harbor/install_harbor_single.ansible -l pc0

# 5. Traefik for API Gateway
ansible-playbook odroid_h4/traefik/install_traefik_single.ansible -l pc0

# 6. Deploy sample Nomad job
cat > web.nomad << 'EOF'
job "web" {
  datacenters = ["dc1"]
  type = "service"
  group "nginx" {
    count = 3
    task "server" {
      driver = "docker"
      config {
        image = "registry.local/library/nginx:latest"
        ports = ["http"]
      }
      resources {
        cpu = 250
        memory = 256
      }
      service {
        name = "nginx"
        port = "http"
        check {
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "2s"
        }
      }
    }
    network {
      mode = "bridge"
      port "http" {}
    }
  }
}
EOF

nomad run web.nomad
```

---

## Cross-Platform Considerations

### Odroid H4 (Intel x86-64)
- ✅ All 9 cluster software solutions supported
- Recommended: Kubernetes, Docker Swarm, or Nomad for orchestration
- Can run KVM/QEMU and Proxmox VE
- Best for: Production workloads, mixed workload types

### RPI5 (ARM64)
- ✅ LXD, Nomad, Consul, Ceph, Harbor, Traefik, EdgeX Foundry, K3s, Kubernetes
- ❌ Proxmox VE (x86-64 only)
- ❌ MicroK8s (requires full snap support - limited on Raspbian)
- Recommended: K3s or Nomad for lightweight orchestration
- Ubuntu variant: Better ecosystem support, easier installation
- Raspbian variant: Familiar to RPi users, lighter footprint
- Best for: Edge computing, IoT, lightweight clusters

### Odroid C5 (ARM64)
- ✅ LXD, Nomad, Consul, Ceph, Harbor, Traefik, EdgeX Foundry, K3s, Kubernetes
- ❌ Proxmox VE (x86-64 only)
- ❌ MicroK8s (snap limitations)
- Similar capabilities to RPI5 with better performance
- Recommended: K3s or Kubernetes for production
- Best for: Scalable ARM-based production clusters

---

## Storage Pool Creation Examples

### Kubernetes Persistent Volumes via Ceph RBD

```bash
# Create RBD pool
ceph osd pool create volumes 32 32
ceph osd pool application enable volumes rbd

# Create volume
rbd create --size 100G volumes/pvc-001

# Mount in Kubernetes
# StorageClass example:
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: <cluster-fsid>
  pool: volumes
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi-rbd
```

### Docker/Nomad Persistent Volumes via Ceph RBD

```bash
# Create pool and volume
ceph osd pool create docker-volumes 32 32
ceph osd pool application enable docker-volumes rbd
rbd create --size 50G docker-volumes/app-data

# Mount in Docker
docker run -v my-volume:/data my-app

# Or with Docker volume driver:
docker volume create --driver ceph --opt pool=docker-volumes my-volume
```

---

## Network & DNS Configuration

### Consul DNS for Service Discovery

Once Consul is deployed, services are discoverable via DNS:

```bash
# Query consul DNS (on Consul agent port 8600)
dig @<consul-ip> -p 8600 nginx.service.consul

# From containers:
docker run --dns <consul-ip> --dns-search service.consul myapp
```

### Traefik Service Discovery via Docker Labels

```yaml
services:
  myapp:
    image: myapp:latest
    labels:
      traefik.enable: "true"
      traefik.http.routers.myapp.rule: "Host(`myapp.local`)"
      traefik.http.services.myapp.loadbalancer.server.port: "8080"
      traefik.http.routers.myapp.entrypoints: "web"
```

### Traefik + Consul Integration

```yaml
# Traefik config with Consul discovery
providers:
  consul:
    endpoint: "consul:8500"
    namespace: ""
```

---

## Backup & Disaster Recovery

### Ceph Cluster Backup

```bash
# Backup cluster configuration
ceph config dump > /backup/ceph-config.txt

# Backup OSD maps
ceph osd getmap > /backup/osdmap
ceph monmap dump > /backup/monmap

# Backup CRUSH map
ceph osd getcrushmap > /backup/crushmap

# List and backup images
rbd ls -l

# Create RBD snapshot
rbd snap create volumes/pvc-001@backup-001
```

### Kubernetes Persistent Volume Backup

```bash
# Via Ceph RBD
rbd snap create volumes/pvc-001@k8s-backup-$(date +%s)

# List snapshots
rbd snap ls volumes/pvc-001
```

### Harbor Registry Backup

```bash
cd /data/harbor
# All images and metadata are in this directory
# Back up entire directory for complete registry backup
tar czf /backup/harbor-backup-$(date +%s).tar.gz /data/harbor
```

---

## Security Considerations

### Network Security
1. Deploy Consul with ACLs enabled
2. Use TLS for Traefik (Let's Encrypt or self-signed)
3. Configure Harbor HTTPS and authentication
4. Network segmentation: management network separate from workload network

### Container Security
1. Use Harbor image scanning (Trivy) to find vulnerabilities
2. Enable image signing in Harbor
3. Configure pod security policies in Kubernetes
4. Use resource limits (CPU/memory) in all schedulers

### Storage Security
1. Enable Ceph authentication (default: enabled)
2. Backup Ceph keys and cluster info
3. Encrypt RBD volumes if sensitive data
4. Regular snapshots for disaster recovery

### Access Control
1. Use Consul ACLs for service-to-service authentication
2. Harbor RBAC for image access control
3. Kubernetes RBAC for API access
4. Traefik BasicAuth or OAuth2 for dashboard

---

## Troubleshooting Guide

### Consul Cluster Issues
```bash
# Check cluster status
consul members

# Check cluster leader
consul operator raft list-peers

# Debug service registration
consul catalog services
consul catalog service <service-name>

# View service health
consul health checks <service-name>
```

### Kubernetes Pod Issues (K3s)
```bash
# Check node status
kubectl get nodes -o wide

# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check Ceph RBD access
kubectl exec -it <pod-name> -n <namespace> -- mount | grep rbd

# View logs
kubectl logs <pod-name> -n <namespace>
```

### Nomad Job Issues
```bash
# Check job status
nomad job status <job-name>

# Check allocation status
nomad alloc status <alloc-id>

# View allocation logs
nomad alloc logs <alloc-id>

# Check node status
nomad node status <node-id>
```

### Ceph Cluster Issues
```bash
# Full cluster status
ceph status

# Check OSD status
ceph osd tree

# Check health warnings
ceph health detail

# Check disk usage
ceph df

# Heal degraded PGs
ceph pg deep-scrub <pg-id>
```

### Traefik Routing Issues
```bash
# Check dashboard at http://host:8081/dashboard/

# View configuration
curl http://localhost:8081/api/config

# Test routing
curl -H "Host: myapp.local" http://localhost

# Check logs
docker logs traefik
cd /opt/traefik && docker-compose logs traefik
```

---

## Performance Tuning

### Ceph Performance
- Set appropriate PG count based on OSDs
- Monitor OSD load
- Adjust osd_pool_default_size based on cluster size
- Monitor network bandwidth between nodes

### Kubernetes Performance
- Use resource limits to prevent node overload
- Monitor etcd performance (K3s uses SQLite, less overhead)
- Enable metrics-server for HPA
- Use NodeLocal DNS cache

### Traefik Performance
- Monitor dashboard connections
- Enable compression for large responses
- Configure rate limiting for DDoS protection
- Use router priority for conflict resolution

---

## Next Steps

1. **Choose your orchestration**: Kubernetes (production) or Nomad (flexibility)
2. **Deploy Consul**: Foundation for service discovery
3. **Deploy storage**: Ceph for distributed persistence
4. **Deploy registry**: Harbor for private images
5. **Deploy ingress**: Traefik for load balancing
6. **Monitor & backup**: Set up monitoring and regular backups
7. **Document your setup**: Keep runbooks for operational procedures

---

## Additional Resources

- **Consul**: https://www.consul.io/docs
- **Nomad**: https://www.nomadproject.io/docs
- **Kubernetes/K3s**: https://kubernetes.io/docs
- **Ceph**: https://docs.ceph.com/
- **Harbor**: https://goharbor.io/docs/
- **Traefik**: https://doc.traefik.io/traefik/
- **EdgeX Foundry**: https://docs.edgexfoundry.org/
- **Proxmox** (H4 only): https://pve.proxmox.com/pve-docs/

