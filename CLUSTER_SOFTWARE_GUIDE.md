# Comprehensive Cluster Software Guide

This guide covers installing 9 different open-source cluster software solutions on PicoCluster boards: **Odroid H4**, **RPI5** (Ubuntu/Raspbian), and **Odroid C5**.

---

## Table of Contents

1. [LXD - System Containers](#lxd)
2. [Nomad - Multi-Workload Orchestrator](#nomad)
3. [Consul - Service Discovery & Configuration](#consul)
4. [Ceph - Distributed Storage](#ceph)
5. [Harbor - Private Container Registry](#harbor)
6. [Traefik - Load Balancer & API Gateway](#traefik)
7. [EdgeX Foundry - IoT Platform](#edgex)
8. [KVM/QEMU - Hypervisor (H4 only)](#kvm)
9. [Proxmox - Virtualization Platform (H4 only)](#proxmox)

---

## 1. LXD - System Containers {#lxd}

**What it is**: Lightweight system containers - between Docker and full VMs. Provides better isolation than containers with VM-like management.

**Best for**: Development environments, system administration, testing multi-system setups

**Supported on**: All boards (H4, RPI5 Ubuntu, RPI5 Raspbian, C5)

### Single Node Installation

```bash
# Install snapd first (if not present)
sudo apt-get update && sudo apt-get install -y snapd

# Install LXD
sudo snap install lxd --classic

# Add your user to lxd group
sudo usermod -aG lxd $USER
newgrp lxd

# Initialize LXD
lxd init --auto --storage-backend=dir

# Test
lxc launch ubuntu:22.04 test-container
lxc list
lxc exec test-container -- bash
```

### LXD Cluster Setup

```bash
# On manager node (pc0)
lxd init --auto --cluster-name=pico-cluster

# Generate token
lxc config get core.trust_password

# On worker nodes (pc1, pc2, etc)
lxd init --auto --cluster-join \
  --cluster-server-address=pc0:8443 \
  --cluster-certificate=<token>

# Verify cluster
lxc cluster list
```

### Common LXD Commands

```bash
# Container management
lxc launch ubuntu:22.04 mycontainer
lxc exec mycontainer -- bash
lxc stop mycontainer
lxc delete mycontainer

# Cluster operations
lxc cluster list
lxc node list
lxc move mycontainer --target pc1  # Migrate to node

# Images
lxc image list
lxc image copy ubuntu:22.04 local: --alias ubuntu22

# Networks
lxc network list
lxc network show lxdbr0

# Storage
lxc storage list
lxc storage show default
```

### Ansible Playbook Examples

See: `odroid_h4/lxd/install_lxd_single.ansible` and `setup_lxd_cluster.ansible`

---

## 2. Nomad - Multi-Workload Orchestrator {#nomad}

**What it is**: Flexible workload orchestrator that handles Docker, VMs, raw binaries, and more across clusters.

**Best for**: Heterogeneous clusters, microservices, flexible scheduling

**Supported on**: All boards (H4, RPI5 Ubuntu, RPI5 Raspbian, C5)

### Single Node Installation

```bash
# Download latest release
NOMAD_VERSION=$(curl -s https://api.github.com/repos/hashicorp/nomad/releases/latest | grep tag_name | cut -d'"' -f4 | sed 's/v//')

# For x86-64 (H4)
wget https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip

# For ARM64 (RPI5, C5)
wget https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_arm64.zip

# Extract and install
unzip nomad_*.zip
sudo mv nomad /usr/local/bin/
sudo chmod +x /usr/local/bin/nomad

# Create systemd service
sudo tee /etc/systemd/system/nomad.service << EOF
[Unit]
Description=Nomad
After=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad/nomad.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create config directory and basic config
sudo mkdir -p /etc/nomad
sudo tee /etc/nomad/nomad.hcl << EOF
datacenter = "dc1"
node_name = "$(hostname)"
data_dir = "/var/lib/nomad"

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true
}

telemetry {
  prometheus_metrics = true
  publish_allocation_metrics = true
}
EOF

# Start service
sudo systemctl daemon-reload
sudo systemctl enable nomad
sudo systemctl start nomad

# Verify
nomad version
nomad status
```

### Nomad Cluster Setup

```bash
# On manager (pc0) - bootstrap with 3 servers
datacenter = "dc1"
server {
  enabled = true
  bootstrap_expect = 3  # 3 servers expected
}

# On other managers (pc1, pc2)
server {
  enabled = true
  retry_join = ["pc0:4647"]
}

# On workers (pc3+)
client {
  enabled = true
  servers = ["pc0:4647", "pc1:4647", "pc2:4647"]
}

# Verify cluster
nomad server members
nomad node status
```

### Deploy Jobs on Nomad

```bash
# Create job file: my-job.nomad
job "my-app" {
  datacenters = ["dc1"]
  type = "service"

  group "app" {
    count = 3

    task "app" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 250
        memory = 256
      }

      service {
        name = "my-app"
        port = "http"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    network {
      mode = "bridge"
      port "http" {}
    }
  }
}

# Deploy
nomad run my-job.nomad

# Monitor
nomad status my-app
nomad logs <alloc-id> app
nomad alloc status <alloc-id>
```

### Common Nomad Commands

```bash
# Server/cluster
nomad server members
nomad node status
nomad node info <node-id>

# Jobs
nomad status
nomad status <job-name>
nomad run <job-file>
nomad plan <job-file>
nomad stop <job-name>

# Allocations
nomad alloc status <alloc-id>
nomad alloc logs <alloc-id> <task>
nomad alloc exec <alloc-id> <cmd>

# Metrics
nomad operator metrics
```

---

## 3. Consul - Service Discovery & Configuration {#consul}

**What it is**: Distributed service mesh for service discovery, configuration, and segmentation.

**Best for**: Service discovery, distributed configuration, health checking

**Supported on**: All boards (H4, RPI5 Ubuntu, RPI5 Raspbian, C5)

### Single Node Installation

```bash
# Download Consul
CONSUL_VERSION=$(curl -s https://api.github.com/repos/hashicorp/consul/releases/latest | grep tag_name | cut -d'"' -f4 | sed 's/v//')

# x86-64 (H4)
wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

# ARM64 (RPI5, C5)
wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_arm64.zip

# Extract
unzip consul_*.zip
sudo mv consul /usr/local/bin/
sudo chmod +x /usr/local/bin/consul

# Create config
sudo mkdir -p /etc/consul.d
sudo tee /etc/consul.d/consul.hcl << EOF
datacenter = "dc1"
node_name = "$(hostname)"
server = true
bootstrap_expect = 1
client_addr = "0.0.0.0"
ui = true

ports {
  http = 8500
  dns = 8600
}
EOF

# Create systemd service
sudo tee /etc/systemd/system/consul.service << EOF
[Unit]
Description=Consul
After=network.target

[Service]
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Start
sudo systemctl daemon-reload
sudo systemctl enable consul
sudo systemctl start consul

# Access UI: http://localhost:8500
```

### Consul Cluster

```bash
# Manager config (pc0)
server = true
bootstrap_expect = 3

# Worker config (pc1, pc2)
server = true
retry_join = ["pc0"]

# Client config (other nodes)
server = false
retry_join = ["pc0"]

# Verify
consul members
consul operator raft list-peers
```

### Service Registration

```bash
# Register a service
consul services register -name=web -id=web-1 -address=10.1.10.240 -port=8080

# Health check
consul services list
consul catalog services
consul catalog nodes
curl http://localhost:8500/v1/catalog/service/web

# Deregister
consul services deregister web-1
```

---

## 4. Ceph - Distributed Storage {#ceph}

**What it is**: Distributed storage system providing object, block, and file storage across cluster.

**Best for**: Persistent storage for containers, cluster backup, data redundancy

**Note**: Requires minimum 3 nodes, substantial resources. Better on H4 + RPI5 cluster.

### Installation Overview

```bash
# 1. Install ceph-deploy or cephadm
sudo apt-get install -y ceph-deploy  # Older way
# OR
curl --silent --remote-name --location https://github.com/ceph/ceph/raw/octopus/src/cephadm/cephadm
chmod +x cephadm

# 2. On manager node, initialize cluster
./cephadm bootstrap --mon-ip 10.1.10.240

# 3. Add storage nodes
ceph orch host add pc1 10.1.10.241
ceph orch host add pc2 10.1.10.242

# 4. Add OSD (storage devices)
ceph orch daemon add osd pc1:/dev/sda1
ceph orch daemon add osd pc2:/dev/sda1

# 5. Create pools
ceph osd pool create rbd 128 128
ceph osd pool application enable rbd rbd

# 6. Verify
ceph status
ceph osd tree
ceph df
```

### Using Ceph Storage

```bash
# Block storage (RBD)
rbd create --size 1024 my-image
rbd map my-image
sudo mkfs.ext4 /dev/rbd0
sudo mount /dev/rbd0 /mnt/ceph

# Object storage (S3)
radosgw-admin user create --uid=testuser --display-name="Test User"

# File system
ceph fs volume create cephfs
ceph fs authorize cephfs client.fs_user / rw
mount.ceph 10.1.10.240:/ /mnt/cephfs -o name=fs_user
```

---

## 5. Harbor - Private Container Registry {#harbor}

**What it is**: Enterprise-grade private Docker/container image registry with security features.

**Best for**: Hosting private container images, air-gapped environments, image scanning

**Supported on**: All boards (recommend H4 for resource requirements)

### Installation

```bash
# 1. Download Harbor release
HARBOR_VERSION=$(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep tag_name | cut -d'"' -f4 | sed 's/v//')

# For x86-64
wget https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-offline-installer-v${HARBOR_VERSION}.tgz

# For ARM64
wget https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-arm64-db-installer-v${HARBOR_VERSION}.tgz

# Extract
tar xzf harbor-*.tgz
cd harbor

# Configure
cp harbor.yml.tmpl harbor.yml
# Edit harbor.yml - set hostname, https settings, etc

# Run installer
./prepare
docker-compose up -d

# Access: https://hostname
# Default: admin / Harbor12345
```

### Using Harbor

```bash
# Login
docker login harbor.example.com

# Push image
docker tag nginx:latest harbor.example.com/library/nginx:latest
docker push harbor.example.com/library/nginx:latest

# Pull image
docker pull harbor.example.com/library/nginx:latest

# Manage via API
curl https://admin:password@harbor.example.com/api/v2.0/projects
```

---

## 6. Traefik - Load Balancer & API Gateway {#traefik}

**What it is**: Modern reverse proxy and load balancer, works great with containers and Kubernetes.

**Best for**: API gateway, load balancing services, SSL termination, service routing

**Supported on**: All boards (excellent for edge deployments)

### Single Node with Docker

```bash
# Create Traefik config
mkdir -p ~/traefik
cd ~/traefik

# traefik.yml
cat > traefik.yml << 'EOF'
global:
  checkNewVersion: true
  sendAnonymousUsage: false

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    filename: config.yml
    watch: true

api:
  insecure: true
  dashboard: true

log:
  level: INFO
EOF

# docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  traefik:
    image: traefik:latest
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./traefik.yml:/traefik.yml
      - ./config.yml:/config.yml
    command:
      - "--configFile=/traefik.yml"

  nginx:
    image: nginx:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nginx.rule=Host(\`nginx.localhost\`)"
      - "traefik.http.services.nginx.loadbalancer.server.port=80"
EOF

# Start
docker-compose up -d

# Dashboard: http://localhost:8080
```

### Nomad Integration

```bash
job "traefik" {
  datacenters = ["dc1"]

  group "traefik" {
    network {
      mode = "host"
      port "web" {
        static = 80
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      provider = "nomad"
      port = "api"
    }

    task "traefik" {
      driver = "docker"
      config {
        image = "traefik:latest"
        ports = ["web", "api"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }
    }
  }
}
```

---

## 7. EdgeX Foundry - IoT Platform {#edgex}

**What it is**: Lightweight open-source IoT edge computing platform.

**Best for**: IoT deployments, edge analytics, sensor management

**Supported on**: All boards (great for edge use cases)

### Installation

```bash
# Install EdgeX Foundry (docker-compose based)
mkdir -p ~/edgex && cd ~/edgex

# Get docker-compose file
wget https://raw.githubusercontent.com/edgexfoundry/edgex-compose/main/docker-compose.yml

# Get environment file
wget https://raw.githubusercontent.com/edgexfoundry/edgex-compose/main/.env

# Edit for ARM64 if needed (change image tags)
# Start services
docker-compose up -d

# Core services running on:
# API: http://localhost:48080
# UI: http://localhost:4200
```

### Using EdgeX

```bash
# View devices
curl http://localhost:48080/api/v2/device

# Add device
curl -X POST http://localhost:48080/api/v2/device \
  -H "Content-Type: application/json" \
  -d '{
    "apiVersion": "v2",
    "device": {
      "name": "my-sensor",
      "description": "My Sensor",
      "deviceProfileName": "MQTT-Sensor"
    }
  }'

# Read data
curl http://localhost:48080/api/v2/reading

# View logs
docker-compose logs -f
```

---

## 8. KVM/QEMU - Hypervisor {#kvm}

**What it is**: Linux kernel virtual machine support for running full VMs.

**Best for**: H4 only (x86-64 architecture), running multiple full VMs

**Supported on**: Odroid H4 only (Intel x86-64)

### Installation on H4

```bash
# Install KVM/QEMU
sudo apt-get update
sudo apt-get install -y \
  qemu-kvm \
  qemu-system-x86 \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virt-manager \
  cpu-checker

# Verify KVM support
kvm-ok

# Enable and start libvirtd
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Add user to kvm/libvirt groups
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER
newgrp libvirt

# Create VM
virt-install \
  --name ubuntu-vm \
  --memory 2048 \
  --vcpus 2 \
  --disk size=20 \
  --cdrom ubuntu-22.04-live-server-amd64.iso \
  --os-type linux \
  --os-variant ubuntu22.04

# List VMs
virsh list --all

# Start/stop VM
virsh start ubuntu-vm
virsh shutdown ubuntu-vm
```

---

## 9. Proxmox VE - Virtualization Platform {#proxmox}

**Important Research Note**: Proxmox VE is x86-64 only and designed for data centers. **RPI5 cannot run Proxmox VE** (ARM64 architecture).

**What it is**: Enterprise hypervisor combining KVM, LXD containers, and management tools.

**Best for**: H4 only (full VM and container infrastructure)

**Supported on**: Odroid H4 ONLY (not viable on RPI5 or C5 - ARM64)

### Installation on H4

```bash
# WARNING: Proxmox installation is disruptive
# It requires reformatting disk and becomes the system OS
# Not recommended if H4 is already running services

# 1. Download Proxmox ISO
wget https://www.proxmox.com/en/downloads/category/proxmox-virtual-environment

# 2. Create bootable USB
sudo dd if=proxmox-ve_*.iso of=/dev/sdX bs=4M status=progress

# 3. Boot from USB and install
# - Follow installation wizard
# - Set network configuration
# - Choose filesystem (ZFS or ext4)

# 4. Post-install (SSH into management interface)
ssh root@<proxmox-ip>

# 5. Access web UI
# https://<proxmox-ip>:8006
# Default: root / password_set_during_install

# 6. Add nodes to cluster (if multiple H4 units)
pvecm create pico-cluster
pvecm add <node-ip>

# 7. Upload ISO and create VMs via web UI
```

### Proxmox Limitations for PicoCluster

- **Resource Heavy**: Requires 4GB+ RAM, 20GB+ disk
- **Complex**: Steep learning curve vs Kubernetes/Swarm
- **Storage Overhead**: Takes full control of system
- **Better Alternative**: Use Nomad + LXD or K3s

### Recommendation

**For PicoCluster:**
- **H4**: Consider Nomad + LXD instead of Proxmox (more flexible)
- **RPI5**: Use K3s or Nomad (Proxmox VE NOT supported on ARM)
- **C5**: Use K3s or Nomad (Proxmox VE NOT supported on ARM)

---

## Comparison Matrix

| Tool | Single Node | Cluster | ARM64 Support | Resource Use | Complexity |
|------|-----------|---------|---------------|--------------|-----------|
| **LXD** | ✅ | ✅ | ✅ | Low | Low |
| **Nomad** | ✅ | ✅ | ✅ | Medium | Medium |
| **Consul** | ✅ | ✅ | ✅ | Medium | Medium |
| **Ceph** | ❌ | ✅ | ✅ | High | High |
| **Harbor** | ✅ | ✅ | ✅ | High | Medium |
| **Traefik** | ✅ | ✅ | ✅ | Low | Low |
| **EdgeX** | ✅ | ❌ | ✅ | Medium | Medium |
| **KVM** | ✅ | ✅ | ❌ | High | Medium |
| **Proxmox** | ✅ | ✅ | ❌ (H4 only) | Very High | High |

---

## Recommended Combinations

### For Development/Testing
```
H4: Nomad + Traefik + Docker
RPI5: K3s + Traefik
```

### For Production Edge Cluster
```
H4: Nomad + Ceph + Consul + Traefik
RPI5 (Ubuntu): K3s + Traefik + Harbor
C5: K3s + Traefik
```

### For IoT Deployment
```
H4: EdgeX Foundry + Nomad + Traefik
RPI5: K3s + EdgeX Lightweight + Traefik
C5: K3s + Traefik
```

### For Maximum Flexibility
```
All nodes: Nomad + Consul + Traefik
(Can run Docker, VMs, raw binaries, Kubernetes)
```

---

## Next Steps

1. **Choose your stack** based on use case
2. **Review official documentation** for each tool
3. **Start with single-node** for testing
4. **Scale to cluster** when ready
5. **Monitor and tune** performance

## References

- [LXD Documentation](https://linuxcontainers.org/lxd/docs/)
- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Consul Documentation](https://www.consul.io/docs)
- [Ceph Documentation](https://docs.ceph.com/)
- [Harbor Documentation](https://goharbor.io/docs/)
- [Traefik Documentation](https://doc.traefik.io/)
- [EdgeX Foundry](https://www.edgexfoundry.org/)
- [KVM/QEMU](https://www.linux-kvm.org/)
- [Proxmox VE](https://www.proxmox.com/en/)

