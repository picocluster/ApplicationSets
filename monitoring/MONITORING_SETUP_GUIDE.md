# PicoCluster Monitoring Setup Guide

Complete guide for setting up centralized monitoring with Prometheus and Grafana for PicoCluster infrastructure.

## Overview

This monitoring solution provides:
- **Prometheus**: Time-series metrics database and alerting engine
- **Grafana**: Visualization and dashboarding platform
- **Node Exporter**: System metrics collection from all cluster nodes
- **Container Metrics**: Docker, Containerd, and Kubernetes metrics
- **Pre-configured Dashboards**: Immediate visibility into cluster health

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Node (RPI5)                   │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ Prometheus   │  │   Grafana    │  │  Node Exporter  │  │
│  │ :9090        │  │   :3000      │  │    :9100        │  │
│  └──────────────┘  └──────────────┘  └─────────────────┘  │
│                                                               │
│  Pre-configured Dashboards:                                 │
│  • Cluster Overview                                          │
│  • System Metrics (CPU, Memory, Disk, Network)              │
│  • Docker/Container Metrics                                  │
│  • Kubernetes Metrics                                        │
└─────────────────────────────────────────────────────────────┘
          ▲         ▲         ▲         ▲
          │         │         │         │
     Scrapes    Scrapes    Scrapes   Scrapes
     Metrics    Metrics    Metrics   Metrics
          │         │         │         │
┌─────────┴────┬────────────┬────────┬─────────┐
│              │            │        │         │
│ Cluster Node 1          Node 2   Node 3   Node N
│ (Odroid H4/RPI5/C5)
│
│  Node Exporter :9100
│  Container Metrics :9323 (Docker)
│  cAdvisor :8080 (Containerd)
│  Kubelet :10250 (Kubernetes)
```

## Quick Start

### 1. Set up Monitoring Node (RPI5)

Choose Ubuntu or Raspbian variant:

**Ubuntu:**
```bash
ansible-playbook monitoring/rpi5_ubuntu/install_prometheus_grafana.ansible -l monitoring-node
```

**Raspbian:**
```bash
ansible-playbook monitoring/rpi5_raspbian/install_prometheus_grafana.ansible -l monitoring-node
```

This installs:
- Prometheus with auto-discovery configuration
- Grafana with pre-configured dashboards
- Node Exporter (self-monitoring)

### 2. Deploy Metrics to All Cluster Nodes

```bash
# Install Node Exporter and metrics collectors on all nodes
ansible-playbook monitoring/metrics_collection/deploy_metrics_to_cluster.ansible
```

This playbook:
- Detects all nodes in Ansible inventory
- Installs Node Exporter on each node
- Configures container metrics (if Docker/Containerd installed)
- Auto-registers nodes with Prometheus

### 3. Access Monitoring Dashboards

After installation, access services at:
- **Prometheus**: http://\<monitoring-node-ip\>:9090
- **Grafana**: http://\<monitoring-node-ip\>:3000
- **Node Exporter**: http://\<monitoring-node-ip\>:9100/metrics

**Default Grafana Credentials:**
- Username: `admin`
- Password: `admin`

⚠️ **Change Grafana password immediately after first login!**

## Directory Structure

```
monitoring/
├── MONITORING_SETUP_GUIDE.md              # This file
├── rpi5_ubuntu/
│   └── install_prometheus_grafana.ansible # Prometheus+Grafana for RPI5 Ubuntu
├── rpi5_raspbian/
│   └── install_prometheus_grafana.ansible # Prometheus+Grafana for RPI5 Raspbian
├── metrics_collection/
│   ├── install_node_exporter.ansible      # Node Exporter for all nodes
│   ├── install_container_metrics.ansible  # Docker/Containerd/K8s metrics
│   └── deploy_metrics_to_cluster.ansible  # Complete cluster deployment
└── config/
    ├── prometheus/
    │   └── prometheus.yml.j2              # Prometheus config template
    └── grafana/
        ├── provisioning_datasources.yml   # Datasource config
        ├── dashboard_system_metrics.json   # System metrics dashboard
        ├── dashboard_docker_metrics.json   # Docker metrics dashboard
        ├── dashboard_kubernetes_metrics.json # Kubernetes dashboard
        └── dashboard_cluster_overview.json # Cluster overview dashboard
```

## Installation Details

### Prometheus Setup

**Location:** `/etc/prometheus/`
**Data:** `/var/lib/prometheus/`
**Service:** `prometheus`
**Port:** 9090

**Features:**
- 30-day data retention
- Auto-scraping of all cluster nodes
- Console templates included
- Support for Docker and Kubernetes metrics

**Configuration:**
Edit `/etc/prometheus/prometheus.yml` to customize scrape intervals, targets, or alerts.

Reload after changes:
```bash
sudo systemctl reload prometheus
```

### Grafana Setup

**Location:** `/etc/grafana/`
**Data:** `/var/lib/grafana/`
**Service:** `grafana-server`
**Port:** 3000

**Features:**
- SQLite database (no external DB required)
- Pre-configured Prometheus datasource
- Pre-loaded dashboards
- User authentication enabled

**Default Credentials:**
- Username: `admin`
- Password: `admin`

### Node Exporter Setup

**Installed on:** All cluster nodes
**Port:** 9100
**Metrics URL:** http://\<node-ip\>:9100/metrics

**Collects:**
- CPU, Memory, Disk, Network metrics
- System load, uptime, processes
- Filesystem usage and I/O statistics
- Network interface counters

## Pre-configured Dashboards

### 1. Cluster Overview
High-level cluster status with:
- Node online/offline status
- Cluster average CPU, Memory, Disk
- Per-node resource utilization
- Network interface counts

### 2. System Metrics
Detailed system performance:
- CPU usage percentage
- Memory usage and availability
- Disk read/write activity
- Network input/output rates

### 3. Docker Metrics
Container-specific monitoring:
- Running container count
- Per-container CPU usage
- Per-container memory usage
- Container network in/out

### 4. Kubernetes Metrics
K3s/K8s cluster status:
- Total pods, nodes, running pods
- Pod distribution by namespace
- Per-node CPU and memory usage
- kube-state-metrics integration

## Adding New Nodes to Monitoring

### Option 1: Automatic (Recommended)

Re-run the cluster deployment playbook:
```bash
ansible-playbook monitoring/metrics_collection/deploy_metrics_to_cluster.ansible
```

This auto-detects new nodes in the inventory and updates Prometheus.

### Option 2: Manual

Edit Prometheus configuration on monitoring node:
```bash
sudo nano /etc/prometheus/prometheus.yml
```

Add under `scrape_configs`:
```yaml
- job_name: 'node-<node-name>'
  static_configs:
    - targets: ['<node-ip>:9100']
      labels:
        node: '<node-name>'
        role: 'cluster'
        arch: 'arm64'
```

Reload Prometheus:
```bash
sudo systemctl reload prometheus
```

## Verifying Installation

### Check Services Status

```bash
# On monitoring node
sudo systemctl status prometheus
sudo systemctl status grafana-server
sudo systemctl status node_exporter
```

### Verify Metrics Collection

**Prometheus Targets:**
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.'
```

**Check Node Exporter metrics:**
```bash
curl -s http://localhost:9100/metrics | head -20
```

**Check Prometheus scrape status:**
```bash
http://localhost:9090/targets
```

### Test Cluster Node Connectivity

From monitoring node:
```bash
# Test Node Exporter on all nodes
for node in pc0 pc1 pc2 pc3; do
  echo "Testing $node..."
  curl -s http://$node:9100/metrics | wc -l
done
```

## Troubleshooting

### Prometheus Won't Start

**Check logs:**
```bash
sudo journalctl -u prometheus -f
```

**Verify configuration:**
```bash
promtool check config /etc/prometheus/prometheus.yml
```

**Common issues:**
- Invalid YAML syntax in config
- Port 9090 already in use
- Insufficient disk space in `/var/lib/prometheus`

### Grafana Can't Connect to Prometheus

1. Verify Prometheus is running: `curl http://localhost:9090/-/healthy`
2. Check datasource in Grafana: Admin → Data Sources → Prometheus
3. Ensure URL is `http://localhost:9090` (not localhost:9100)

### No Metrics from Nodes

1. Verify Node Exporter is running on target node:
   ```bash
   curl http://<node-ip>:9100/metrics
   ```

2. Check Prometheus targets page: http://localhost:9090/targets

3. Look for errors in Prometheus logs:
   ```bash
   sudo journalctl -u prometheus | grep error
   ```

### High Memory Usage

If Prometheus is using too much memory:

1. Reduce retention time in `/etc/prometheus/prometheus.yml`:
   ```bash
   --storage.tsdb.retention.time=7d  # Instead of 30d
   ```

2. Reduce scrape interval:
   ```yaml
   global:
     scrape_interval: 30s  # Instead of 15s
   ```

3. Restart Prometheus:
   ```bash
   sudo systemctl restart prometheus
   ```

## Advanced Configuration

### Adding Alerting Rules

Create `/etc/prometheus/rules.yml`:
```yaml
groups:
  - name: cluster_alerts
    rules:
      - alert: NodeDown
        expr: up{job="node"} == 0
        for: 5m
        annotations:
          summary: "Node {{ $labels.node }} is down"
```

Add to `prometheus.yml`:
```yaml
rule_files:
  - /etc/prometheus/rules.yml
```

### Custom Dashboards

1. Open Grafana: http://\<ip\>:3000
2. Create → Dashboard
3. Add panels with PromQL queries
4. Save dashboard (appears in PicoCluster folder automatically)

Example queries:
```promql
# CPU usage per node
100 - (avg by (node) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory utilization
100 * (1 - ((node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes))

# Network traffic
rate(node_network_receive_bytes_total[5m])
```

### Integration with Existing Stacks

**With K3s/Kubernetes:**
```bash
# Deploy kube-state-metrics
ansible-playbook monitoring/metrics_collection/install_container_metrics.ansible
```

**With Docker:**
- Automatically configured when installed
- Metrics available at http://\<node\>:9323/metrics

**With Nomad:**
- Add Nomad metrics scrape job to `prometheus.yml`
- Use Consul service discovery integration

## Security Considerations

### Securing Grafana

1. Change default admin password immediately
2. Disable user signup: Settings → Security → Sign-up
3. Enable HTTPS (use reverse proxy like Traefik)

### Securing Prometheus

1. Don't expose port 9090 externally
2. Use firewall rules to restrict access
3. Place behind reverse proxy with authentication if needed

### Securing Node Exporter

1. Runs as non-root `node_exporter` user
2. No authentication by default (runs on internal network)
3. Consider restricting port 9100 with firewall

## Performance Tuning

### For Large Clusters (10+ nodes)

Increase Prometheus resources:

Edit `/etc/systemd/system/prometheus.service`:
```ini
[Service]
...
--storage.tsdb.max-block-duration=2h
--query.max-samples=100000
--query.timeout=2m
```

### For Long-term Storage

Replace SQLite with Cortex or Thanos for distributed storage.

## Backup and Recovery

### Backup Prometheus Data

```bash
# Stop Prometheus
sudo systemctl stop prometheus

# Backup data
sudo tar -czf prometheus-backup-$(date +%Y%m%d).tar.gz /var/lib/prometheus

# Restart
sudo systemctl start prometheus
```

### Backup Grafana Dashboards

```bash
# Export all dashboards
curl -s http://localhost:3000/api/search?query=% -H "Authorization: Bearer $(grep admin_password /etc/grafana/grafana.ini)" | jq
```

Or use Grafana UI: Dashboards → Manage → Export All

## Integration with PicoCluster Services

### Monitor Traefik Load Balancer

Add to `prometheus.yml`:
```yaml
- job_name: 'traefik'
  static_configs:
    - targets: ['localhost:8080']
```

### Monitor Consul Service Discovery

```yaml
- job_name: 'consul'
  consul_sd_configs:
    - server: 'localhost:8500'
```

### Monitor Ceph Storage

```yaml
- job_name: 'ceph'
  static_configs:
    - targets: ['<ceph-node>:9283']
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs)
- [Grafana Documentation](https://grafana.com/docs)
- [Node Exporter Docs](https://github.com/prometheus/node_exporter)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet)

## Support

For issues:

1. Check service logs: `sudo journalctl -u prometheus -f`
2. Review Prometheus targets: http://localhost:9090/targets
3. Test node connectivity: `curl http://<node>:9100/metrics`
4. Check Grafana data sources: Admin → Data Sources

---

**Last Updated:** 2025-11-08
**Status:** Production Ready
