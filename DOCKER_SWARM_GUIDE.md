# Docker and Docker Swarm Installation Guide

This guide covers Docker and Docker Swarm setup across all PicoCluster boards: **Odroid H4**, **RPI5** (Ubuntu & Raspbian), and **Odroid C5**.

## Overview

**Docker**: Containerization platform for running isolated applications
**Docker Swarm**: Native container orchestration for managing multi-node clusters

### When to Use

| Solution | Best For |
|----------|----------|
| **Docker (Single)** | Development, testing, single-node deployments |
| **Docker Swarm** | Small to medium clusters, simple orchestration |
| **Kubernetes** | Large clusters, advanced features, production |

## Quick Start by Board

### Odroid H4

```bash
# Install Docker
ansible-playbook odroid_h4/docker/install_docker.ansible

# Set up Docker Swarm (multi-node)
ansible-playbook odroid_h4/docker/setup_docker_swarm.ansible

# Verify
ansible pc0 -m shell -a "docker node ls"
```

### RPI5 Ubuntu

```bash
# Install Docker
ansible-playbook rpi5/docker/install_docker_ubuntu.ansible

# Set up Docker Swarm (multi-node)
ansible-playbook rpi5/docker/setup_docker_swarm_ubuntu.ansible

# Verify
ansible pc0 -m shell -a "docker node ls"
```

### RPI5 Raspbian

```bash
# Install Docker
ansible-playbook rpi5/docker/install_docker_raspbian.ansible

# Set up Docker Swarm (multi-node)
ansible-playbook rpi5/docker/setup_docker_swarm_raspbian.ansible

# Verify
ansible pc0 -m shell -a "docker node ls"
```

### Odroid C5

```bash
# Install Docker
ansible-playbook odroid_c5/docker/install_docker.ansible

# Set up Docker Swarm (multi-node)
ansible-playbook odroid_c5/docker/setup_docker_swarm.ansible

# Verify
ansible pc0 -m shell -a "docker node ls"
```

## Prerequisites

1. **Network configured** (see cluster_setup scripts)
2. **SSH access** to all nodes
3. **Ansible inventory** defined:
   ```ini
   [cluster]
   pc0
   pc1
   pc2

   [master]
   pc0

   [worker]
   pc[1:2]
   ```

## Installation Steps

### Step 1: Install Docker on All Nodes

Choose the script matching your board and OS:

```bash
# Odroid H4 (Intel Ubuntu)
ansible-playbook odroid_h4/docker/install_docker.ansible

# RPI5 Ubuntu
ansible-playbook rpi5/docker/install_docker_ubuntu.ansible

# RPI5 Raspbian
ansible-playbook rpi5/docker/install_docker_raspbian.ansible

# Odroid C5 (Debian-based)
ansible-playbook odroid_c5/docker/install_docker.ansible
```

**What this does:**
- Installs Docker and Docker Compose
- Enables Docker service
- Adds user to docker group
- Verifies installation

### Step 2: Initialize Docker Swarm

```bash
# Odroid H4
ansible-playbook odroid_h4/docker/setup_docker_swarm.ansible

# RPI5 Ubuntu
ansible-playbook rpi5/docker/setup_docker_swarm_ubuntu.ansible

# RPI5 Raspbian
ansible-playbook rpi5/docker/setup_docker_swarm_raspbian.ansible

# Odroid C5
ansible-playbook odroid_c5/docker/setup_docker_swarm.ansible
```

**What this does:**
1. Initializes Swarm on manager node (pc0)
2. Generates join tokens
3. Joins all worker nodes automatically
4. Verifies cluster is ready

### Step 3: Verify Swarm

```bash
# Check nodes
ansible pc0 -m shell -a "docker node ls"

# Check node details
ansible pc0 -m shell -a "docker node inspect pc1"

# Check Swarm status
ansible pc0 -m shell -a "docker info | grep -i swarm"
```

## Using Docker Swarm

### Deploy a Service

```bash
# Simple nginx service with 3 replicas
docker service create --name web --replicas 3 -p 80:80 nginx

# With resource limits
docker service create \
  --name api \
  --replicas 2 \
  --memory 256m \
  --cpus 0.5 \
  myimage:latest

# With environment variables
docker service create \
  --name db \
  --env DATABASE_URL=postgres://db \
  postgres:latest
```

### Manage Services

```bash
# List services
docker service ls

# Get service details
docker service inspect web

# View service logs
docker service logs web

# Scale service
docker service update --replicas 5 web

# Update service
docker service update \
  --image nginx:alpine \
  web

# Remove service
docker service rm web
```

### View Nodes and Tasks

```bash
# List nodes
docker node ls

# Inspect a node
docker node inspect pc0

# List tasks (containers) on all nodes
docker node ps

# List tasks on specific node
docker node ps pc1

# Get task details
docker inspect <task-id>
```

## Docker Compose with Swarm

Create a `docker-compose.yml`:

```yaml
version: '3.9'
services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
      restart_policy:
        condition: on-failure

  db:
    image: postgres:latest
    environment:
      POSTGRES_PASSWORD: secret
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: '1'
          memory: 512M
      placement:
        constraints: [node.role == manager]
```

Deploy stack:

```bash
# Deploy
docker stack deploy -c docker-compose.yml myapp

# List stacks
docker stack ls

# List services in stack
docker stack services myapp

# Remove stack
docker stack rm myapp
```

## Networking in Swarm

### Ingress Network (Load Balancing)

Published ports automatically load balance across nodes:

```bash
# Publish port 8080 on any node -> reaches service
docker service create \
  --name app \
  --replicas 3 \
  -p 8080:8080 \
  myapp:latest

# Now accessible on any node:
curl pc0:8080
curl pc1:8080
curl pc2:8080
```

### Overlay Network (Container to Container)

For service-to-service communication:

```bash
# Create overlay network
docker network create -d overlay app-network

# Create services on network
docker service create \
  --name web \
  --network app-network \
  nginx:latest

docker service create \
  --name api \
  --network app-network \
  myapi:latest

# Services can communicate: web -> api by hostname
```

## Troubleshooting

### Node Not Joining Swarm

```bash
# Check node is accessible
ansible pc1 -m ping

# Check Docker is running
ansible pc1 -m shell -a "systemctl status docker" -b

# View manager logs
docker logs <swarm-manager-id>

# Try manual join with proper token
docker swarm join --token SWMTKN-... 10.1.10.240:2377
```

### Service Not Starting

```bash
# Check service status
docker service ps web

# Get detailed task info
docker inspect <task-id>

# Check logs
docker service logs web -f

# Check resource constraints
docker stats
```

### Connectivity Issues

```bash
# Test overlay network
docker service create \
  --name test-ping \
  --network app-network \
  alpine ping -c 4 web

# View network
docker network ls

# Inspect network
docker network inspect app-network
```

### Node Offline/Failed

```bash
# Demote node
docker node demote pc2

# Update node availability
docker node update --availability drain pc2

# Update node to drain tasks
docker node update --availability drain pc2

# Re-enable node
docker node update --availability active pc2

# Remove failed node
docker node rm pc2
```

## Performance Tuning

### Resource Limits

```bash
docker service create \
  --limit-memory 512m \
  --limit-cpus 1 \
  --reserve-memory 256m \
  --reserve-cpus 0.5 \
  myapp:latest
```

### Rolling Updates

```bash
docker service update \
  --update-parallelism 1 \
  --update-delay 10s \
  --image myapp:v2 \
  myapp
```

### Service Placement

```bash
# Run only on managers
docker service create \
  --constraint 'node.role==manager' \
  task:latest

# Run on specific nodes
docker node update --label-add zone=worker pc1
docker service create \
  --constraint 'node.labels.zone==worker' \
  app:latest
```

## Monitoring

### Container Metrics

```bash
# Real-time stats
docker stats

# Per-service stats
docker stats --no-stream

# Memory and CPU by service
docker service ls --format "table {{.Name}}\t{{.Replicas}}"
```

### Logs

```bash
# Follow service logs
docker service logs web -f

# Last 100 lines
docker service logs web --tail 100

# Since timestamp
docker service logs web --since 2024-01-01
```

## Security Considerations

1. **TLS for Swarm**: Enabled by default
2. **Secrets Management**:
   ```bash
   echo "password123" | docker secret create db_password -
   docker service create \
     --secret db_password \
     postgres:latest
   ```

3. **Network Isolation**: Use overlay networks to segment services
4. **Access Control**: Use Docker Content Trust for image verification

## Comparison: Docker Swarm vs Kubernetes

| Feature | Docker Swarm | Kubernetes |
|---------|--------------|------------|
| **Setup** | Minutes | Hours |
| **Complexity** | Simple | Complex |
| **Learning Curve** | Easy | Steep |
| **Networking** | Good | Excellent |
| **Storage** | Basic | Advanced |
| **Scale** | Medium | Large |
| **Community** | Smaller | Huge |
| **Use Case** | Small clusters | Enterprise |

## File Locations

**Installation Scripts:**
- Odroid H4: `odroid_h4/docker/`
- RPI5: `rpi5/docker/`
- Odroid C5: `odroid_c5/docker/`

**Configuration:**
- Docker: `/etc/docker/daemon.json`
- Swarm: `/var/lib/docker/swarm/`

## Next Steps

1. **Deploy applications** using `docker service create` or docker-compose stacks
2. **Set up monitoring** with Prometheus/Grafana
3. **Configure log aggregation** with ELK or similar
4. **Implement CI/CD** with Docker registries
5. **Plan backup strategy** for Swarm state

## References

- [Docker Official Docs](https://docs.docker.com/)
- [Docker Swarm Guide](https://docs.docker.com/engine/swarm/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

## Support

For issues, check:
1. Docker logs: `journalctl -u docker -f`
2. Swarm status: `docker info | grep Swarm`
3. Node status: `docker node ls`
4. Service health: `docker service ps <service>`
