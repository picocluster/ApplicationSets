# Docker & Docker Swarm Quick Reference

## Installation Quick Start

### All Boards - Docker Installation

```bash
# Odroid H4
ansible-playbook odroid_h4/docker/install_docker.ansible

# RPI5 Ubuntu
ansible-playbook rpi5/docker/install_docker_ubuntu.ansible

# RPI5 Raspbian
ansible-playbook rpi5/docker/install_docker_raspbian.ansible

# Odroid C5
ansible-playbook odroid_c5/docker/install_docker.ansible
```

### All Boards - Docker Swarm Setup

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

## Basic Docker Commands

```bash
# Pull image
docker pull ubuntu:latest
docker pull arm64v8/nginx  # For ARM64 boards

# Run container
docker run -d --name myapp ubuntu:latest

# List containers
docker ps              # Running
docker ps -a          # All

# Stop/Start container
docker stop myapp
docker start myapp

# Remove container
docker rm myapp

# View logs
docker logs myapp
docker logs -f myapp   # Follow logs

# Execute command
docker exec -it myapp bash

# Build image
docker build -t myapp:1.0 .

# Push to registry
docker push myregistry/myapp:1.0
```

## Docker Compose

```bash
# Create/start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f service_name

# Scale service
docker-compose up -d --scale web=3

# Build images
docker-compose build

# Pull images
docker-compose pull
```

## Docker Swarm Management

```bash
# Check Swarm status
docker info | grep Swarm

# List nodes
docker node ls

# Inspect node
docker node inspect pc0

# Promote node to manager
docker node promote pc1

# Demote node to worker
docker node demote pc2

# Drain node (remove tasks)
docker node update --availability drain pc2

# Re-enable node
docker node update --availability active pc2

# Remove node
docker node rm pc3

# Get manager token
docker swarm join-token manager

# Get worker token
docker swarm join-token worker

# Leave Swarm
docker swarm leave
```

## Docker Service Management

```bash
# Create service
docker service create --name web -p 80:80 nginx:latest

# Create service with replicas
docker service create --name api --replicas 3 myapi:latest

# Create service with resource limits
docker service create \
  --name app \
  --limit-memory 512m \
  --limit-cpus 0.5 \
  myapp:latest

# List services
docker service ls

# Inspect service
docker service inspect web

# Update service replicas
docker service update --replicas 5 web

# Update service image
docker service update --image nginx:alpine web

# View service tasks
docker service ps web

# View service logs
docker service logs web -f

# Remove service
docker service rm web

# Restart service
docker service update --force web
```

## Docker Stack (Compose on Swarm)

```bash
# Deploy stack
docker stack deploy -c docker-compose.yml myapp

# List stacks
docker stack ls

# List services in stack
docker stack services myapp

# List tasks in stack
docker stack ps myapp

# Remove stack
docker stack rm myapp

# Update stack
docker stack deploy -c docker-compose.yml myapp  # Redeploy with changes
```

## Networking

```bash
# List networks
docker network ls

# Create overlay network
docker network create -d overlay mynetwork

# Inspect network
docker network inspect mynetwork

# Remove network
docker network rm mynetwork

# Connect service to network
docker service create --network mynetwork myapp:latest

# Service discovery
# Use service name as hostname: web.mynetwork
curl http://web:80
```

## Monitoring & Debugging

```bash
# Container stats
docker stats

# Image size
docker image ls --format "table {{.Repository}}\t{{.Size}}"

# Volume usage
docker system df

# View events
docker events --filter type=service

# Node info
docker node inspect pc0 -f '{{json .}}' | jq

# Service events
docker service logs web --details

# Task logs
docker service logs web --follow

# Metrics
docker stats --no-stream
```

## Image Management

```bash
# List images
docker images

# Tag image
docker tag ubuntu:latest myrepo/ubuntu:1.0

# Push image
docker push myrepo/ubuntu:1.0

# Pull image
docker pull myrepo/ubuntu:1.0

# Remove image
docker rmi ubuntu:latest

# Remove unused images
docker image prune -a

# View image history
docker history ubuntu:latest

# Search registry
docker search nginx
```

## Volume Management

```bash
# List volumes
docker volume ls

# Create volume
docker volume create mydata

# Inspect volume
docker volume inspect mydata

# Remove volume
docker volume rm mydata

# Remove unused volumes
docker volume prune

# Mount volume in service
docker service create \
  -v mydata:/data \
  myapp:latest
```

## Secrets Management

```bash
# Create secret
echo "password123" | docker secret create db_pass -

# List secrets
docker secret ls

# Inspect secret
docker secret inspect db_pass

# Use secret in service
docker service create \
  --secret db_pass \
  postgres:latest

# Remove secret (service must be stopped)
docker secret rm db_pass
```

## Troubleshooting

```bash
# Check Docker daemon
systemctl status docker

# View Docker logs
journalctl -u docker -f

# Check Swarm logs
docker logs <swarm-task-id>

# Inspect service task
docker inspect <task-id>

# Check network connectivity
docker service create --name test alpine ping -c 4 google.com

# View service events
docker service ps web --no-trunc

# Health check
docker container ls --format "table {{.Names}}\t{{.Status}}"

# System info
docker system info

# Check resource usage
docker stats --no-stream

# View propagation error
docker service ps web --no-trunc | grep -i error
```

## Common Patterns

### High Availability Service

```bash
docker service create \
  --name ha-app \
  --replicas 3 \
  --restart-condition on-failure \
  --update-parallelism 1 \
  --update-delay 10s \
  myapp:latest
```

### Pinned to Manager Node

```bash
docker service create \
  --constraint 'node.role==manager' \
  critical-service:latest
```

### With Health Check

```bash
docker service create \
  --health-cmd='curl -f http://localhost:8080/health' \
  --health-interval=30s \
  --health-timeout=3s \
  --health-retries=3 \
  myapp:latest
```

### With Placement Constraints

```bash
# Label nodes first
docker node update --label-add type=compute pc1

# Use labels
docker service create \
  --constraint 'node.labels.type==compute' \
  workload:latest
```

### Rolling Update

```bash
docker service update \
  --update-order start-first \
  --update-parallelism 1 \
  --update-delay 30s \
  --image myapp:v2 \
  myapp
```

## Useful Docker Commands Cheatsheet

```
CONTAINER MANAGEMENT
  docker run          Start container
  docker ps           List running containers
  docker stop         Stop container
  docker restart      Restart container
  docker rm           Remove container
  docker logs         Show logs
  docker exec         Execute command

IMAGE MANAGEMENT
  docker build        Build image
  docker pull         Download image
  docker push         Upload image
  docker images       List images
  docker rmi          Remove image

SWARM MANAGEMENT
  docker swarm init   Initialize Swarm
  docker swarm join   Join Swarm
  docker node ls      List nodes
  docker service      Manage services
  docker stack        Manage stacks

NETWORK MANAGEMENT
  docker network ls   List networks
  docker network create  Create network
  docker network inspect Inspect network

VOLUME MANAGEMENT
  docker volume ls    List volumes
  docker volume create Create volume
  docker volume inspect Inspect volume

SYSTEM MANAGEMENT
  docker stats        Show statistics
  docker version      Show version
  docker info         Show system info
  docker system df    Disk usage
```

## Performance Tips

```bash
# Update multiple services in parallel
docker service update --image v2 service1 &
docker service update --image v2 service2 &
wait

# Use --update-order for zero-downtime
docker service update \
  --update-order start-first \
  --image newimage \
  myservice

# Limit resource usage per container
docker service create \
  --limit-memory 512m \
  --limit-cpus 0.5 \
  myapp

# Monitor performance
docker stats --no-stream > docker-metrics.log
```

## Quick Diagnostics

```bash
# Is Swarm running?
docker info | grep "Swarm"

# How many nodes?
docker node ls | wc -l

# How many services?
docker service ls | wc -l

# What's failing?
docker service ps web | grep -v Running

# Node memory usage
free -h

# Docker disk usage
docker system df

# Network issues
docker service inspect web -f '{{json .NetworkID}}'
```
