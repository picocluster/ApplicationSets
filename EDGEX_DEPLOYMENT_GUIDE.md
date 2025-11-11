# EdgeX Foundry Deployment Guide

Complete guide for deploying and managing EdgeX Foundry IoT edge platform on PicoCluster hardware.

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Scenarios](#deployment-scenarios)
4. [Installation](#installation)
5. [Device Integration](#device-integration)
6. [Monitoring & Observability](#monitoring--observability)
7. [Security](#security)
8. [Troubleshooting](#troubleshooting)
9. [Production Best Practices](#production-best-practices)

---

## Introduction

EdgeX Foundry is an open-source, vendor-neutral IoT edge computing framework that enables:
- **Device Connectivity**: Support for 30+ protocols (Modbus, MQTT, BACnet, OPC-UA, etc.)
- **Data Processing**: Local processing and filtering at the edge
- **Cloud Integration**: Flexible export to cloud platforms
- **Extensibility**: Microservices architecture with plugin support
- **Scalability**: From single-board computers to enterprise gateways

### Use Cases

- **Smart Buildings**: HVAC, lighting, security systems
- **Industrial IoT**: Equipment monitoring, predictive maintenance
- **Smart Cities**: Traffic sensors, environmental monitoring
- **Agriculture**: Soil sensors, irrigation control
- **Healthcare**: Medical device integration

---

## Architecture Overview

### EdgeX Foundry Components

```
┌─────────────────────────────────────────────────────────────┐
│                     EdgeX Foundry                            │
├─────────────────────────────────────────────────────────────┤
│  Application Services                                        │
│  ├── Rules Engine    (data filtering, transformation)       │
│  └── Export Services (cloud connectors, analytics)          │
├─────────────────────────────────────────────────────────────┤
│  Core Services                                               │
│  ├── Core Data       (event/reading persistence)            │
│  ├── Core Metadata   (device/service registry)              │
│  └── Core Command    (device control)                       │
├─────────────────────────────────────────────────────────────┤
│  Support Services                                            │
│  ├── Notifications   (alerts and events)                    │
│  └── Scheduler       (scheduled actions)                    │
├─────────────────────────────────────────────────────────────┤
│  Device Services                                             │
│  ├── Virtual Device  (testing/simulation)                   │
│  ├── Modbus          (industrial devices)                   │
│  ├── MQTT            (IoT sensors)                          │
│  └── REST            (HTTP devices)                         │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure                                              │
│  ├── Consul          (service registry, config)             │
│  └── Redis           (database, message bus)                │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Sensor → Device Service**: Physical sensors connect via protocol-specific device services
2. **Device Service → Core Data**: Readings published to message bus
3. **Core Data → Application Services**: Data forwarded to processing pipelines
4. **Application Services → Cloud/Local**: Processed data exported to destinations

---

## Deployment Scenarios

### Scenario 1: Single Node Development/Testing

**Hardware**: 1x Odroid H4, RPI5, or Odroid C5
**Use Case**: Development, testing, proof-of-concept
**Services**: All EdgeX services on single node

```bash
# Deploy EdgeX on Odroid H4
ansible-playbook -i inventory.ini odroid_h4/edgex/install_edgex_single.ansible

# Deploy EdgeX on RPI5 Ubuntu
ansible-playbook -i inventory.ini rpi5/edgex/install_edgex_single_ubuntu.ansible

# Deploy EdgeX on RPI5 Raspbian
ansible-playbook -i inventory.ini rpi5/edgex/install_edgex_single_raspbian.ansible

# Deploy EdgeX on Odroid C5
ansible-playbook -i inventory.ini odroid_c5/edgex/install_edgex_single.ansible
```

### Scenario 2: EdgeX + Kubernetes

**Hardware**: 3+ node cluster
**Use Case**: Production IoT gateway with orchestration
**Stack**: EdgeX + K3s + Prometheus + Grafana

```bash
# 1. Deploy K3s cluster
ansible-playbook -i inventory.ini odroid_h4/kubernetes/install_k3s_cluster.ansible

# 2. Deploy monitoring stack
ansible-playbook -i inventory.ini monitoring/install_prometheus.ansible
ansible-playbook -i inventory.ini monitoring/install_grafana.ansible

# 3. Deploy EdgeX (adapt for Kubernetes deployment)
# Create EdgeX Kubernetes manifests or use Helm chart
kubectl apply -f edgex-k8s-manifests/
```

### Scenario 3: Distributed Edge Computing

**Hardware**: Multiple edge nodes
**Use Case**: Geographically distributed sensors
**Architecture**: EdgeX on each edge node + centralized management

```bash
# Deploy EdgeX to multiple edge locations
ansible-playbook -i edge_locations.ini odroid_h4/edgex/install_edgex_single.ansible

# Configure data aggregation to central location
# Each node exports to central data lake or cloud
```

### Scenario 4: EdgeX + Consul Cluster

**Hardware**: 3+ nodes
**Use Case**: High availability service discovery
**Stack**: EdgeX + Consul cluster (shared across nodes)

```bash
# 1. Deploy Consul cluster first
ansible-playbook -i inventory.ini odroid_h4/consul/setup_consul_cluster.ansible

# 2. Configure EdgeX to use external Consul
# Modify EdgeX docker-compose to point to Consul cluster
```

---

## Installation

### Prerequisites

#### Hardware Requirements
- **Minimum**: 4GB RAM, 20GB storage
- **Recommended**: 8GB RAM, 50GB storage
- **CPU**: ARM64 or x86-64 with multi-core support

#### Software Requirements
- Ubuntu Server 20.04+ or Debian 11+
- Docker 20.10+
- Docker Compose 2.0+
- Static IP address
- Network connectivity to devices

#### Network Requirements
- Ports 8500 (Consul), 59880-59882 (Core services)
- Device protocol ports (Modbus: 502, MQTT: 1883, etc.)

### Installation Steps

#### 1. Prepare Inventory File

Create `inventory.ini`:
```ini
[edgex]
edge01 ansible_host=192.168.1.101 ansible_user=picocluster

[edgex:vars]
ansible_python_interpreter=/usr/bin/python3
```

#### 2. Run Installation Playbook

```bash
# For Odroid H4 (x86-64)
ansible-playbook -i inventory.ini odroid_h4/edgex/install_edgex_single.ansible

# For Raspberry Pi 5 Ubuntu (ARM64)
ansible-playbook -i inventory.ini rpi5/edgex/install_edgex_single_ubuntu.ansible

# For Raspberry Pi 5 Raspbian (ARM64)
ansible-playbook -i inventory.ini rpi5/edgex/install_edgex_single_raspbian.ansible

# For Odroid C5 (ARM64)
ansible-playbook -i inventory.ini odroid_c5/edgex/install_edgex_single.ansible
```

#### 3. Verify Installation

```bash
# SSH to the node
ssh picocluster@192.168.1.101

# Check EdgeX services
sudo systemctl status edgex

# Check running containers
docker ps

# Use CLI helper
/opt/edgex/edgex-cli.sh status

# Check Consul UI
# Open browser: http://192.168.1.101:8500
```

#### 4. Test with Virtual Device

```bash
# Check virtual device readings
/opt/edgex/edgex-cli.sh devices

# View recent readings
/opt/edgex/edgex-cli.sh readings

# Expected output: Random sensor values from virtual devices
```

---

## Device Integration

### Adding Real Devices

#### Step 1: Install Device Service

EdgeX supports many device services out of the box. To add additional device services:

```bash
# Example: Add Modbus device service
cd /opt/edgex/compose

# Edit docker-compose.override.yml to add:
cat >> docker-compose.override.yml <<'EOF'
  device-modbus:
    container_name: edgex-device-modbus
    image: edgexfoundry/device-modbus:3.1
    ports:
      - "59901:59901"
    networks:
      - edgex-network
    environment:
      EDGEX_SECURITY_SECRET_STORE: "false"
      REGISTRY_HOST: consul
      CLIENTS_CORE_COMMAND_HOST: core-command
      CLIENTS_CORE_METADATA_HOST: core-metadata
      CLIENTS_CORE_DATA_HOST: core-data
      MESSAGEQUEUE_HOST: redis
    depends_on:
      - consul
      - redis
      - core-data
      - core-metadata
      - core-command
    restart: unless-stopped
EOF

# Restart EdgeX
sudo systemctl restart edgex
```

#### Step 2: Define Device Profile

Device profiles describe device capabilities (resources, commands).

```bash
# Create device profile JSON
cat > /tmp/temperature-sensor-profile.json <<'EOF'
{
  "apiVersion": "v3",
  "profile": {
    "name": "Temperature-Sensor",
    "manufacturer": "Generic",
    "model": "TempSensor-01",
    "labels": ["temperature", "sensor"],
    "deviceResources": [
      {
        "name": "Temperature",
        "description": "Temperature reading in Celsius",
        "attributes": {
          "register": "4001",
          "primaryTable": "HOLDING_REGISTER"
        },
        "properties": {
          "valueType": "Float32",
          "readWrite": "R"
        }
      }
    ]
  }
}
EOF

# Upload to Core Metadata
curl -X POST http://localhost:59881/api/v3/deviceprofile \
  -H "Content-Type: application/json" \
  -d @/tmp/temperature-sensor-profile.json
```

#### Step 3: Add Device Instance

```bash
# Register device instance
curl -X POST http://localhost:59881/api/v3/device \
  -H "Content-Type: application/json" \
  -d '{
    "apiVersion": "v3",
    "device": {
      "name": "Temperature-Sensor-01",
      "description": "Temperature sensor in server room",
      "adminState": "UNLOCKED",
      "operatingState": "UP",
      "serviceName": "device-modbus",
      "profileName": "Temperature-Sensor",
      "protocols": {
        "modbus-tcp": {
          "Address": "192.168.1.50",
          "Port": "502",
          "UnitID": "1"
        }
      }
    }
  }'
```

#### Step 4: Read Device Data

```bash
# Get device readings
curl http://localhost:59882/api/v3/device/name/Temperature-Sensor-01/Temperature

# View all recent events
/opt/edgex/edgex-cli.sh events
```

### Supported Device Protocols

| Protocol | Device Service | Common Use Cases |
|----------|---------------|------------------|
| **Modbus TCP/RTU** | device-modbus | Industrial PLCs, meters, sensors |
| **MQTT** | device-mqtt | IoT sensors, smart home devices |
| **BACnet** | device-bacnet | Building automation (HVAC) |
| **REST** | device-rest | HTTP-based devices, web APIs |
| **SNMP** | device-snmp | Network equipment monitoring |
| **Grove** | device-grove | Seeed Studio Grove sensors |
| **GPIO** | device-gpio | Direct GPIO on Raspberry Pi |

---

## Monitoring & Observability

### Built-in Metrics

EdgeX services expose Prometheus metrics on their management ports.

#### Enable Prometheus Scraping

```yaml
# /opt/edgex/compose/prometheus.yml
scrape_configs:
  - job_name: 'edgex-core-data'
    static_configs:
      - targets: ['localhost:59880']
    metrics_path: '/api/v3/metrics'

  - job_name: 'edgex-core-metadata'
    static_configs:
      - targets: ['localhost:59881']
    metrics_path: '/api/v3/metrics'

  - job_name: 'edgex-core-command'
    static_configs:
      - targets: ['localhost:59882']
    metrics_path: '/api/v3/metrics'
```

### Grafana Dashboard

Import the EdgeX Foundry Grafana dashboard (included in monitoring/config/grafana/).

**Key Metrics**:
- Event ingestion rate (events/second)
- Reading count by device
- Service response times
- Error rates by service
- Device connectivity status

### Logging

EdgeX services log to Docker:

```bash
# View logs for specific service
docker logs -f edgex-core-data

# View all EdgeX logs
/opt/edgex/edgex-cli.sh logs

# View logs for specific service
/opt/edgex/edgex-cli.sh logs core-data
```

---

## Security

### Production Security Configuration

By default, the playbooks install EdgeX with security **disabled** for ease of development. For production:

#### 1. Enable Security

```bash
# Edit /opt/edgex/compose/.env
EDGEX_SECURITY_ENABLED=true

# Restart EdgeX
sudo systemctl restart edgex
```

When security is enabled:
- API Gateway on port 8000 (Kong)
- Secret Store (Vault) for credential management
- JWT tokens for authentication
- mTLS between services

#### 2. Configure Firewall

```bash
# Allow only necessary ports
sudo ufw allow 8500/tcp   # Consul UI (restrict to admin network)
sudo ufw allow 59880/tcp  # Core Data (restrict to internal network)
sudo ufw allow 59881/tcp  # Core Metadata (restrict to internal network)
sudo ufw allow 59882/tcp  # Core Command (restrict to internal network)

# Device protocol ports (as needed)
sudo ufw allow 502/tcp    # Modbus
sudo ufw allow 1883/tcp   # MQTT

# Enable firewall
sudo ufw enable
```

#### 3. Network Segmentation

Best practice: Separate networks for:
- **Management Network**: Consul UI, EdgeX APIs (admin access only)
- **Device Network**: Sensor/actuator communication (isolated)
- **Export Network**: Cloud connectivity (filtered egress)

---

## Troubleshooting

### Common Issues

#### Services Not Starting

```bash
# Check service status
sudo systemctl status edgex

# Check Docker logs
docker ps -a
docker logs edgex-core-data

# Verify Consul and Redis are healthy
docker ps | grep -E 'consul|redis'

# Check for port conflicts
sudo netstat -tlnp | grep -E '8500|59880|59881|59882'
```

#### Devices Not Sending Data

```bash
# Verify device is registered
curl http://localhost:59881/api/v3/device/all | jq

# Check device service logs
docker logs edgex-device-virtual

# Test device connectivity
# For Modbus device at 192.168.1.50:502
nc -zv 192.168.1.50 502

# For MQTT device
mosquitto_sub -h localhost -t edgex/# -v
```

#### High Memory Usage

```bash
# Check container resource usage
docker stats

# Configure data retention (default: 7 days)
# Edit /opt/edgex/compose/.env
EDGEX_DATA_RETENTION=24  # Reduce to 24 hours

# Clear old data manually
curl -X DELETE http://localhost:59880/api/v3/event/age/604800000000000
```

#### Consul Issues

```bash
# Check Consul health
curl http://localhost:8500/v1/health/state/any

# Restart Consul
docker restart edgex-core-consul

# Check service registrations
curl http://localhost:8500/v1/agent/services | jq
```

### Diagnostic Commands

```bash
# EdgeX CLI helper
/opt/edgex/edgex-cli.sh status    # Service status
/opt/edgex/edgex-cli.sh devices   # List devices
/opt/edgex/edgex-cli.sh readings  # Recent readings
/opt/edgex/edgex-cli.sh events    # Recent events

# Manual API checks
curl http://localhost:59880/api/v3/ping  # Core Data health
curl http://localhost:59881/api/v3/ping  # Core Metadata health
curl http://localhost:59882/api/v3/ping  # Core Command health

# Check data flow
watch -n 1 'curl -s http://localhost:59880/api/v3/event/count | jq'
```

---

## Production Best Practices

### 1. Resource Sizing

**Minimum Production Specs**:
- 8GB RAM
- 4 CPU cores
- 100GB SSD storage
- Gigabit network

**Expected Load**:
- 1000 events/second: 4GB RAM, 2 cores
- 10000 events/second: 16GB RAM, 8 cores

### 2. Data Retention

Configure appropriate data retention based on storage:

```bash
# /opt/edgex/compose/.env
EDGEX_DATA_RETENTION=168  # 7 days in hours
```

### 3. Backup Strategy

```bash
# Backup script
#!/bin/bash
BACKUP_DIR=/var/backups/edgex/$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# Export device profiles
curl http://localhost:59881/api/v3/deviceprofile/all > $BACKUP_DIR/profiles.json

# Export device configurations
curl http://localhost:59881/api/v3/device/all > $BACKUP_DIR/devices.json

# Backup Consul data
docker exec edgex-core-consul consul snapshot save /tmp/backup.snap
docker cp edgex-core-consul:/tmp/backup.snap $BACKUP_DIR/consul.snap

# Backup Redis (if persistence enabled)
docker exec edgex-redis redis-cli save
docker cp edgex-redis:/data/dump.rdb $BACKUP_DIR/redis.rdb
```

### 4. Monitoring Alerts

Configure alerts for:
- Service downtime (any EdgeX service unavailable)
- High event ingestion latency (> 1 second)
- Device disconnections
- Storage usage > 80%
- Memory usage > 90%

### 5. High Availability

For mission-critical deployments:
- Run EdgeX services in Kubernetes with 3+ replicas
- Use external Consul cluster (3+ nodes)
- Use Redis Sentinel or Redis Cluster
- Load balance API calls with Traefik/Nginx
- Deploy across multiple physical nodes

### 6. Updates and Maintenance

```bash
# Update to new EdgeX version
cd /opt/edgex/compose

# Backup first!
docker compose down
cp docker-compose.override.yml docker-compose.override.yml.backup

# Pull new images
docker compose pull

# Start updated services
docker compose up -d

# Verify
/opt/edgex/edgex-cli.sh status
```

---

## Next Steps

1. **Explore Device Services**: https://docs.edgexfoundry.org/3.1/microservices/device/
2. **Application Services**: https://docs.edgexfoundry.org/3.1/microservices/application/
3. **Rules Engine**: Configure data filtering and transformation
4. **Cloud Export**: Connect to AWS IoT, Azure IoT Hub, Google Cloud IoT
5. **Custom Device Services**: Build custom device services for proprietary protocols

---

## Additional Resources

- **Official Documentation**: https://docs.edgexfoundry.org
- **EdgeX GitHub**: https://github.com/edgexfoundry
- **Community Forum**: https://community.edgexfoundry.org
- **Slack Channel**: https://edgexfoundry.slack.com
- **Example Device Services**: https://github.com/edgexfoundry/device-sdk-go/tree/main/example

---

**Version**: EdgeX Foundry Jakarta 3.1
**Last Updated**: 2025-11-11
**Maintained By**: PicoCluster Team
