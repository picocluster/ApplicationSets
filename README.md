# ApplicationSets - PicoCluster Infrastructure Automation

Comprehensive Ansible playbooks and configuration for deploying and managing containerized cluster infrastructure across ARM64 and x86-64 single-board computers (SBCs). This project provides production-ready automation for building scalable, distributed clusters with modern open-source software.

## 🎯 Project Overview

ApplicationSets provides complete infrastructure-as-code for the PicoCluster project, enabling automated deployment of:

- **Container Orchestration**: Kubernetes (stock, K3s, MicroK8s), Docker Swarm, Nomad
- **Service Mesh & Discovery**: Consul for service discovery and distributed configuration
- **Distributed Storage**: Ceph for object, block, and file storage with replication
- **Load Balancing**: Traefik for modern reverse proxy and load balancing
- **Container Registry**: Harbor for private image management with vulnerability scanning
- **System Containers**: LXD for lightweight containerization
- **IoT Platform**: EdgeX Foundry for edge computing and IoT data management
- **Virtualization**: KVM/QEMU (x86-64 only), Proxmox VE (x86-64 only)

## 🖥️ Supported Hardware

| Platform | Architecture | OS Variants | Status |
|----------|-------------|-------------|--------|
| **Odroid H4** | Intel x86-64 | Ubuntu Server | ✅ Full Support |
| **Raspberry Pi 5** | ARM64 | Ubuntu, Raspbian | ✅ Full Support |
| **Odroid C5** | ARM64 | Debian-based | ✅ Full Support |

### Platform-Specific Notes

**Odroid H4 (x86-64)**
- Most powerful of the three boards
- Supports all cluster software including Proxmox VE and KVM/QEMU
- Best for production workloads and mixed-architecture clusters
- Full compatibility with traditional Linux ecosystem

**Raspberry Pi 5 (ARM64)**
- Two OS options:
  - **Ubuntu**: Better software ecosystem, recommended for most use cases
  - **Raspbian**: Familiar to RPi community, lighter footprint
- Limited by 4GB RAM (RPI5), optimize for lightweight solutions (K3s, Docker)
- Great for edge computing and IoT applications

**Odroid C5 (ARM64)**
- Better performance than RPI5 with more memory options
- Same software compatibility as RPI5
- Recommended for production ARM64 clusters

**Note**: Proxmox VE is x86-64 only and NOT available on ARM64 boards.

## 📦 Repository Structure

```
ApplicationSets/
├── README.md                              # This file
├── CLUSTER_SOFTWARE_GUIDE.md              # Overview of all 9 cluster solutions
├── CLUSTER_INTEGRATION_GUIDE.md           # Installation recipes and integration patterns
│
├── odroid_h4/                             # Odroid H4 (Intel x86-64) automation
│   ├── cluster_setup/                     # Network configuration
│   │   ├── change_ips.ansible
│   │   └── apply_network_config.ansible
│   ├── kubernetes/                        # Kubernetes variants
│   │   ├── install_kubernetes_containerd_single.ansible
│   │   ├── install_kubernetes_containerd_cluster.ansible
│   │   ├── install_k3s_single.ansible
│   │   └── install_k3s_cluster.ansible
│   ├── docker/                            # Docker and Docker Swarm
│   │   ├── install_docker.ansible
│   │   └── setup_docker_swarm.ansible
│   ├── lxd/                               # System containers
│   │   ├── install_lxd_single.ansible
│   │   └── setup_lxd_cluster.ansible
│   ├── nomad/                             # Workload orchestrator
│   │   ├── install_nomad_single.ansible
│   │   └── setup_nomad_cluster.ansible
│   ├── consul/                            # Service discovery
│   │   ├── install_consul_single.ansible
│   │   └── setup_consul_cluster.ansible
│   ├── ceph/                              # Distributed storage
│   │   ├── install_ceph_single.ansible
│   │   └── setup_ceph_cluster.ansible
│   ├── harbor/                            # Private container registry
│   │   └── install_harbor_single.ansible
│   ├── traefik/                           # Load balancer
│   │   └── install_traefik_single.ansible
│   └── QUICK_REFERENCE.md
│
├── rpi5/                                  # Raspberry Pi 5 (ARM64) automation
│   ├── cluster_setup/
│   │   ├── change_ips.ansible
│   │   └── apply_network_config_*.ansible (Ubuntu/Raspbian variants)
│   ├── kubernetes/                        # Ubuntu and Raspbian variants
│   │   ├── install_kubernetes_containerd_single_*.ansible
│   │   ├── install_kubernetes_containerd_cluster_*.ansible
│   │   ├── install_k3s_single_*.ansible
│   │   └── install_k3s_cluster_*.ansible
│   ├── docker/                            # Ubuntu and Raspbian variants
│   │   ├── install_docker_*.ansible
│   │   └── setup_docker_swarm_*.ansible
│   ├── lxd/                               # Ubuntu and Raspbian variants
│   │   ├── install_lxd_single_*.ansible
│   │   └── setup_lxd_cluster_*.ansible
│   ├── nomad/                             # Ubuntu and Raspbian variants
│   │   ├── install_nomad_single_*.ansible
│   │   └── setup_nomad_cluster_*.ansible
│   ├── consul/                            # Ubuntu and Raspbian variants
│   │   ├── install_consul_single_*.ansible
│   │   └── setup_consul_cluster_*.ansible
│   ├── ceph/                              # Ubuntu and Raspbian variants
│   │   ├── install_ceph_single_*.ansible
│   │   └── setup_ceph_cluster_*.ansible
│   └── README_RPI5_KUBERNETES.md
│
├── odroid_c5/                             # Odroid C5 (ARM64) automation
│   ├── cluster_setup/
│   │   ├── change_ips.ansible
│   │   └── apply_network_config.ansible
│   ├── kubernetes/
│   │   ├── install_kubernetes_containerd_single.ansible
│   │   ├── install_kubernetes_containerd_cluster.ansible
│   │   ├── install_k3s_single.ansible
│   │   └── install_k3s_cluster.ansible
│   ├── docker/
│   │   ├── install_docker.ansible
│   │   └── setup_docker_swarm.ansible
│   ├── lxd/
│   │   ├── install_lxd_single.ansible
│   │   └── setup_lxd_cluster.ansible
│   ├── nomad/
│   │   ├── install_nomad_single.ansible
│   │   └── setup_nomad_cluster.ansible
│   ├── consul/
│   │   ├── install_consul_single.ansible
│   │   └── setup_consul_cluster.ansible
│   ├── ceph/
│   │   ├── install_ceph_single.ansible
│   │   └── setup_ceph_cluster.ansible
│   └── README_ODROID_C5_KUBERNETES.md
│
└── DOCKER_SWARM_GUIDE.md                  # Docker Swarm specific documentation
```

## 🚀 Quick Start

### Prerequisites

1. **Hardware**: One or more of the supported SBCs
2. **OS Installation**: Fresh installation of Ubuntu Server or Raspbian
3. **Network**: Static IP addresses (scripts help configure this)
4. **Ansible**: Installed on control machine with SSH access to nodes

### Basic Network Setup

First, configure static IPs and hostnames across your cluster:

```bash
# Plan IP assignments for your cluster size
ansible-playbook <platform>/cluster_setup/change_ips.ansible

# Apply network configuration to each node
ansible-playbook <platform>/cluster_setup/apply_network_config.ansible -l <node>
```

### Example 1: Single-Node Kubernetes (K3s)

```bash
# Install K3s on a single node
ansible-playbook rpi5/kubernetes/install_k3s_single_ubuntu.ansible -l pc0

# Access cluster
ssh ubuntu@pc0
kubectl get nodes
kubectl get pods --all-namespaces
```

### Example 2: Multi-Node Kubernetes Cluster

```bash
# Install on first node (master)
ansible-playbook rpi5/kubernetes/install_k3s_single_ubuntu.ansible -l pc0

# Join worker nodes
ansible-playbook rpi5/kubernetes/install_k3s_cluster_ubuntu.ansible
```

### Example 3: Nomad + Consul Stack

```bash
# Deploy Consul first (Nomad requires it for coordination)
ansible-playbook odroid_h4/consul/install_consul_single.ansible -l pc0
ansible-playbook odroid_h4/consul/setup_consul_cluster.ansible

# Deploy Nomad
ansible-playbook odroid_h4/nomad/install_nomad_single.ansible -l pc0
ansible-playbook odroid_h4/nomad/setup_nomad_cluster.ansible

# Access UI
# Consul: http://<node>:8500
# Nomad: http://<node>:4646
```

### Example 4: Distributed Storage with Ceph (3+ nodes required)

```bash
# Install Ceph on first node
ansible-playbook odroid_c5/ceph/install_ceph_single.ansible -l pc0

# Join remaining nodes
ansible-playbook odroid_c5/ceph/install_ceph_single.ansible -l pc1
ansible-playbook odroid_c5/ceph/install_ceph_single.ansible -l pc2

# Create cluster
ansible-playbook odroid_c5/ceph/setup_ceph_cluster.ansible

# Check status
ssh debian@pc0
ceph -s
```

## 📋 Available Cluster Software

### 1. **Container Orchestration**

#### Kubernetes
- **Stock Kubernetes**: Full-featured, kubeadm + containerd
- **K3s**: Lightweight Kubernetes, ideal for resource-constrained devices
- **MicroK8s**: Snap-based (Ubuntu only)

#### Alternative Orchestrators
- **Docker Swarm**: Native Docker clustering, simpler than Kubernetes
- **Nomad**: Multi-workload orchestrator (Docker, raw binaries, Java)

### 2. **Service Discovery & Coordination**
- **Consul**: Service registry, health checking, distributed KV store, DNS interface
  - Integrates with Nomad for service coordination
  - Provides DNS-based service discovery across cluster

### 3. **Distributed Storage**
- **Ceph**:
  - Object storage (RadosGW) for S3-compatible access
  - Block storage (RBD) for Kubernetes persistent volumes
  - File storage (CephFS) for shared filesystems
  - Minimum 3 nodes for replication and reliability

### 4. **Load Balancing & Reverse Proxy**
- **Traefik**: Modern reverse proxy with:
  - Automatic Docker service discovery
  - Let's Encrypt HTTPS/TLS support
  - Dashboard and monitoring
  - Middleware support (compression, rate limiting, circuit breaker)

### 5. **Container Registry**
- **Harbor**: Enterprise-grade private registry with:
  - Vulnerability scanning (Trivy)
  - Image replication and RBAC
  - Webhook support for CI/CD
  - Web UI and API

### 6. **System Containers**
- **LXD**: Lightweight containerization between Docker and full VMs
  - System container clustering
  - Snapshots and backup capabilities

### 7. **IoT & Edge Platform**
- **EdgeX Foundry**: Lightweight IoT edge platform
  - Device management and data collection
  - Microservices-based architecture
  - Cloud connectivity

### 8. **Virtualization** (x86-64 Only)
- **KVM/QEMU**: Hypervisor for running VMs
- **Proxmox VE**: Full virtualization platform with clustering
  - **Note**: x86-64 (Odroid H4) only. NOT available on ARM64 boards.

## 📖 Documentation

### Main Guides
- **CLUSTER_SOFTWARE_GUIDE.md**: Technical overview of all 9 solutions, features, and comparisons
- **CLUSTER_INTEGRATION_GUIDE.md**: Complete integration guide with:
  - 3 recommended stack configurations
  - Installation recipes for each stack
  - Cross-platform compatibility matrix
  - Backup and disaster recovery procedures
  - Security best practices
  - Troubleshooting guide
  - Performance tuning recommendations

### Platform-Specific Documentation
- **odroid_h4/QUICK_REFERENCE.md**: Quick command reference for Odroid H4
- **rpi5/kubernetes/README_RPI5_KUBERNETES.md**: RPI5-specific Kubernetes guide
- **odroid_c5/kubernetes/README_ODROID_C5_KUBERNETES.md**: Odroid C5-specific guide
- **DOCKER_SWARM_GUIDE.md**: Comprehensive Docker Swarm guide
- **DOCKER_SWARM_QUICK_REFERENCE.md**: Quick Docker command reference

## 🏗️ Recommended Cluster Configurations

### Config 1: Kubernetes-Based (Production)
Best for: Container-centric, cloud-native applications
```
- Orchestration: K3s (lightweight) or stock Kubernetes
- Service Discovery: Consul
- Load Balancing: Traefik
- Storage: Ceph (RBD persistent volumes)
- Registry: Harbor
```

### Config 2: Nomad + Consul (Flexible)
Best for: Mixed workload types, flexibility
```
- Orchestration: Nomad (Docker, raw binary, Java)
- Service Discovery: Consul (integrated)
- Load Balancing: Traefik
- Storage: Ceph
- Registry: Harbor
```

### Config 3: Docker Swarm (Simple)
Best for: Lightweight, straightforward clustering
```
- Orchestration: Docker Swarm
- Containers: LXD (optional system containers)
- Storage: Ceph
- Registry: Harbor
- Service Discovery: Consul (optional)
```

See **CLUSTER_INTEGRATION_GUIDE.md** for complete installation recipes.

## 💾 Storage Options

### Single-Node Storage
- Docker volumes (local)
- LXD snapshots
- Ceph single-node (reduced redundancy)

### Distributed Storage (3+ nodes)
- **Ceph RBD**: Block storage for Kubernetes persistent volumes
- **Ceph CephFS**: Shared filesystem access
- **Ceph RadosGW**: S3-compatible object storage

## 🔐 Security Considerations

All scripts include:
- Proper systemd service configuration
- User/group creation with least privilege
- TLS/HTTPS support where applicable
- Authentication and RBAC options
- Network security best practices

See **CLUSTER_INTEGRATION_GUIDE.md** Security section for detailed recommendations.

## 🐛 Troubleshooting

Each cluster software includes:
- Verification commands to check installation
- Common diagnostic commands
- Log locations and viewing methods

Common troubleshooting scenarios are covered in:
- **CLUSTER_INTEGRATION_GUIDE.md**: Comprehensive troubleshooting guide
- Individual script documentation with helpful next-steps
- Platform-specific READMEs with known issues

## 📊 Features

- ✅ **Multi-platform**: x86-64 and ARM64 support
- ✅ **OS variants**: Ubuntu and Raspbian for RPI5
- ✅ **Single and cluster**: Both configurations for all tools
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Well-documented**: Clear comments and helpful guidance
- ✅ **Production-ready**: Systemd services, security configs, monitoring hooks
- ✅ **Open-source**: Licensed for sharing and modification

## 🤝 Contributing

Contributions welcome! Please:
1. Test scripts on actual hardware
2. Document any platform-specific issues
3. Follow existing script patterns and structure
4. Update documentation for any new additions
5. Ensure ARM64 compatibility where applicable

## 📄 License

Open-source - see individual script headers for specific license information.

## 🔗 Resources

- [Consul Documentation](https://www.consul.io/docs)
- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs)
- [K3s Documentation](https://docs.k3s.io)
- [Ceph Documentation](https://docs.ceph.com/)
- [Harbor Documentation](https://goharbor.io/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [LXD Documentation](https://linuxcontainers.org/lxd/docs/)
- [EdgeX Foundry Documentation](https://docs.edgexfoundry.org/)
- [Proxmox Documentation](https://pve.proxmox.com/pve-docs/) (x86-64 only)

## 📞 Support

For issues, questions, or suggestions:
1. Check the relevant documentation files
2. Review the CLUSTER_INTEGRATION_GUIDE.md troubleshooting section
3. Check script comments for platform-specific notes
4. Review git commit messages for implementation details

---

**Last Updated**: 2025-11-08
**Repository**: PicoCluster ApplicationSets
**Status**: Active Development - Production Ready for Kubernetes, Nomad, and Docker Swarm deployments
