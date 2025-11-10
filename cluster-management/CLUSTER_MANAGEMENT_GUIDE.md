# PicoCluster Management Tools Guide

Complete guide for all cluster management, operational, and administration tools.

## Overview

The cluster management toolkit provides 5 essential tools:

1. **Cluster Health Check** - Real-time cluster status
2. **Setup Validation** - Pre-deployment checklist
3. **Alert Rules** - Prometheus alerting configuration
4. **Automated Backups** - State and configuration backup
5. **Cluster Inventory Dashboard** - Hardware and software inventory

## 1. Cluster Health Check Script

### Purpose
Monitor real-time health and status of all cluster nodes and services.

### Usage

```bash
# Basic cluster health check
./cluster-management/cluster_health_check.sh

# Check specific node
./cluster-management/cluster_health_check.sh -n pc0

# Verbose output (detailed information)
./cluster-management/cluster_health_check.sh -v

# Verbose + specific node
./cluster-management/cluster_health_check.sh -v -n pc1
```

### What It Checks

✓ **Node Reachability**
- Ping connectivity
- SSH accessibility
- Response time

✓ **Services Status**
- Prometheus, Grafana, Node Exporter
- Docker, Containerd, Kubelet
- Custom service list

✓ **System Metrics**
- Disk usage (warning: 80%, critical: 90%)
- Memory usage (warning: 80%, critical: 90%)
- System load average
- Network interfaces

✓ **Advanced Checks**
- Certificate expiration dates
- NTP time synchronization
- Network packet loss
- Service restart loops

### Output Example

```
════════════════════════════════════════════════════════
PicoCluster Health Check
════════════════════════════════════════════════════════

──── Cluster Health Summary ────

✓ Cluster Status: HEALTHY

Checked Nodes: 4
  Healthy: 4
  Warnings: 0
  Critical: 0
```

### Configuration

Edit thresholds in script:
```bash
DISK_WARNING=80          # Disk space warning threshold
DISK_CRITICAL=90         # Disk space critical threshold
MEMORY_WARNING=80        # Memory warning threshold
MEMORY_CRITICAL=90       # Memory critical threshold
TIMEOUT=5                # SSH timeout in seconds
```

## 2. Cluster Setup Validation Script

### Purpose
Pre-flight validation before deploying to production.

### Usage

```bash
# Full validation
./cluster-management/validate_cluster_setup.sh

# Verbose with details
./cluster-management/validate_cluster_setup.sh -v

# Quick basic checks only
./cluster-management/validate_cluster_setup.sh --quick

# Attempt to fix issues
./cluster-management/validate_cluster_setup.sh --fix
```

### What It Validates

✓ **Required Tools**
- Ansible
- SSH
- jq, curl, python3

✓ **Ansible Configuration**
- ansible.cfg exists
- group_vars and host_vars
- Playbook syntax

✓ **SSH Setup**
- Private key exists
- SSH config file
- known_hosts

✓ **Node Connectivity**
- All nodes reachable
- SSH key-based auth
- Python 3 installed
- Sudo access

✓ **System Prerequisites**
- Adequate disk space (>20%)
- Sufficient memory (>2GB)
- Time synchronization (NTP)
- Network connectivity
- Firewall configuration

✓ **Security**
- SELinux status
- AppArmor status
- Firewall rules

### Output Levels

**Exit Code 0**: All checks passed ✓
**Exit Code 1**: Warnings (address before production)
**Exit Code 2**: Critical failures (must fix before deployment)

## 3. Alert Rules & Deployment

### Components

**Alert Rules File**: `monitoring/config/prometheus/alert_rules.yml`
- 31 pre-configured Prometheus alerts
- Critical, warning, and info severity levels

**Deployment Playbook**: `cluster-management/deploy_alert_rules.ansible`
- Automatic alert rules deployment
- AlertManager setup
- Slack/email integration

### Usage

```bash
# Deploy basic alert rules
ansible-playbook cluster-management/deploy_alert_rules.ansible

# Deploy with Slack notifications
ansible-playbook cluster-management/deploy_alert_rules.ansible \
  -e slack_webhook_url="https://hooks.slack.com/services/..."

# Deploy specific components only
ansible-playbook cluster-management/deploy_alert_rules.ansible \
  -e alert_categories="node,prometheus,docker"
```

### Alert Categories (31 Total)

| Category | Count | Severity | Examples |
|----------|-------|----------|----------|
| **Node Health** | 3 | Critical | NodeDown, MultipleNodesDown |
| **CPU** | 2 | Critical/Warning | HighCPU, CriticalCPU |
| **Memory** | 3 | Critical/Warning | HighMemory, OutOfMemory |
| **Disk** | 4 | Critical/Warning | DiskFull, LowInodes |
| **Network** | 2 | Warning | PacketLoss, InterfaceDown |
| **Prometheus** | 3 | Critical/Warning | PrometheusDown, ConfigReloadFailure |
| **Grafana** | 1 | Critical | GrafanaDown |
| **Docker** | 2 | Warning | DockerDown, HighRestarts |
| **Kubernetes** | 5 | Critical/Warning | KubeletDown, PodCrashLooping |
| **System** | 2 | Warning | HighLoad, TooManyOpenFiles |
| **Services** | 2 | Warning | NodeExporterDown, TargetDown |

### Slack Integration

#### Create Webhook

1. Open Slack workspace
2. Settings → Apps & Integrations
3. Create incoming webhook
4. Copy webhook URL

#### Deploy with Slack

```bash
WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
ansible-playbook cluster-management/deploy_alert_rules.ansible \
  -e slack_webhook_url="$WEBHOOK"
```

#### Verify Alerts

```bash
# Check alert rules loaded
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups'

# View active alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts'
```

### Testing Alerts

**Trigger NodeDown Alert:**
```bash
# Stop Node Exporter
sudo systemctl stop node_exporter

# Wait 5 minutes
# Check: http://localhost:9090/alerts

# Restart
sudo systemctl start node_exporter
```

**Trigger High CPU Alert:**
```bash
# Install stress tool
sudo apt install stress-ng

# Generate load
stress-ng --cpu 4 --timeout 5m

# Monitor: http://localhost:9090/alerts
```

### Alert Customization

Edit `/etc/prometheus/alert_rules.yml`:

```yaml
# Change threshold from 85% to 80%
- alert: HighCPUUsage
  expr: ... > 80  # Modified from 85
  for: 5m
```

Reload:
```bash
sudo systemctl reload prometheus
```

## 4. Automated Backup Playbook

### Purpose
Automated backup of all critical cluster state and configuration.

### Usage

```bash
# Full cluster backup
ansible-playbook cluster-management/backup_cluster_state.ansible

# Backup specific components
ansible-playbook cluster-management/backup_cluster_state.ansible \
  -e backup_components="prometheus,grafana"

# Backup to external location
ansible-playbook cluster-management/backup_cluster_state.ansible \
  -e backup_destination="/mnt/nfs/backups"

# Daily automated backup (cron)
0 2 * * * /usr/bin/ansible-playbook /path/to/backup_cluster_state.ansible
```

### What Gets Backed Up

**Prometheus** (monitoring node only)
- Configuration files: `/etc/prometheus/`
- Time-series data: `/var/lib/prometheus/`
- Last 7 days of metrics

**Grafana** (monitoring node only)
- Configuration: `/etc/grafana/`
- Database: `/var/lib/grafana/grafana.db`
- All dashboards (JSON export)

**Consul** (if running)
- Service discovery state snapshot

**Kubernetes/K3s** (if installed)
- Cluster configuration
- Manifests and resources
- etcd state (K3s)

**All Nodes**
- SSH host keys
- Network configuration
- System files
- Node-specific configuration

### Backup Locations

```
/backups/
├── prometheus-backup-20251110T170000.tar.gz
├── prometheus-data-20251110T170000.tar.gz
├── grafana-backup-20251110T170000.tar.gz
├── grafana-dashboards-20251110T170000.tar.gz
├── k3s-backup-20251110T170000.tar.gz
└── BACKUP-20251110T170000-README.txt
```

### Retention Policy

- Default: 7-day rolling backups
- Configure: `-e backup_retention_days=14`
- Old backups auto-deleted

### Restore Operations

**Full Restore:**
```bash
# Extract all components
tar -xzf /backups/prometheus-backup-*.tar.gz -C /
tar -xzf /backups/grafana-backup-*.tar.gz -C /
```

**Restore Specific Files:**
```bash
# Restore only Prometheus config
tar -xzf /backups/prometheus-backup-*.tar.gz -C / \
  --wildcards "etc/prometheus/*"

# Restore K3s
tar -xzf /backups/k3s-backup-*.tar.gz -C /
systemctl restart k3s
```

**Consul Restore:**
```bash
consul snapshot restore /backups/consul-snapshot-*.snap
```

### Backup Verification

```bash
# Test backup integrity
tar -tzf /backups/prometheus-backup-*.tar.gz > /dev/null && echo "✓ OK"

# List backup contents
tar -tzf /backups/prometheus-backup-*.tar.gz | head

# Calculate backup size
du -sh /backups/
```

## 5. Cluster Inventory Dashboard

### Purpose
Hardware and software inventory visualization in Grafana.

### Features

- **Node Inventory Table**
  - Hostname, IP address
  - OS and kernel version
  - CPU architecture
  - Online/offline status

- **Resource Summary**
  - Total CPU cores
  - Total memory (GB)
  - Total disk space (GB)
  - Network interfaces

- **Hardware Details**
  - CPU model and stepping
  - Memory per node
  - Disk size per node

- **Utilization Charts**
  - Memory usage by node
  - Disk usage by node
  - CPU core count comparison

### Access

```
http://<monitoring-node-ip>:3000
→ Dashboards → PicoCluster Inventory
```

### Pre-requisites

- Node Exporter running on all nodes
- Prometheus collecting `node_uname_info` and other metrics

## Operational Workflows

### Daily Operations

```bash
# Morning health check
./cluster-management/cluster_health_check.sh

# Weekly validation
./cluster-management/validate_cluster_setup.sh --quick

# Check alerts in Prometheus
# http://localhost:9090/alerts

# Review inventory dashboard
# http://localhost:3000/d/picocluster-inventory
```

### Maintenance

```bash
# Backup before changes
ansible-playbook cluster-management/backup_cluster_state.ansible

# Update configurations
# ... make changes ...

# Validate changes didn't break anything
./cluster-management/cluster_health_check.sh -v

# Roll back if needed
# tar -xzf /backups/prometheus-backup-*.tar.gz -C /
```

### Incident Response

```bash
# 1. Check what's wrong
./cluster-management/cluster_health_check.sh -v

# 2. Check alerts
# http://localhost:9090/alerts

# 3. Look at system metrics in Grafana
# http://localhost:3000/d/picocluster-cluster-overview

# 4. Review logs
journalctl -u prometheus -f
journalctl -u grafana-server -f

# 5. Restore from backup if needed
# See backup restore instructions above
```

### Scaling

```bash
# Add new nodes
# 1. Add to Ansible inventory

# 2. Validate setup
./cluster-management/validate_cluster_setup.sh

# 3. Deploy monitoring to new nodes
ansible-playbook monitoring/metrics_collection/install_node_exporter.ansible -l new_node

# 4. Check health
./cluster-management/cluster_health_check.sh -n new_node
```

## Troubleshooting

### Cluster Health Check Issues

**"Node is unreachable"**
- Check SSH connectivity: `ssh node_name`
- Verify network connectivity: `ping node_name`
- Check firewall rules
- Look at system logs on the node

**"Service not responding"**
- Check if service is running: `sudo systemctl status service_name`
- Restart service: `sudo systemctl restart service_name`
- Check service logs: `sudo journalctl -u service_name -f`

### Validation Script Issues

**"Python 3 not found"**
- Install: `sudo apt install python3`
- Required for Ansible

**"No SSH key found"**
- Generate: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519`
- Copy to nodes: `ssh-copy-id node_name`

### Alert Rules Issues

**"Alerts not firing"**
- Check rules loaded: `curl -s http://localhost:9090/api/v1/rules`
- Verify alert expression returns data
- Check Prometheus logs

**"Too many false alerts"**
- Increase threshold: edit `/etc/prometheus/alert_rules.yml`
- Increase `for` duration: `for: 10m` (instead of 5m)
- Reload: `sudo systemctl reload prometheus`

### Backup Issues

**"Backup failed"**
- Check disk space: `df -h /backups`
- Verify permissions: `ls -la /backups`
- Check Ansible logs for details

**"Can't restore"**
- Verify backup is intact: `tar -tzf backup-file.tar.gz`
- Check target directory permissions
- Ensure service is stopped before restore

## Integration with Monitoring

These tools integrate with:

- **Prometheus** - Alert rules, health checks feed into metrics
- **Grafana** - Dashboards for inventory and status
- **Node Exporter** - Provides metrics for health checks
- **Ansible** - Deployment, validation, backups

## See Also

- [Monitoring Setup Guide](../monitoring/MONITORING_SETUP_GUIDE.md)
- [Alert Rules Guide](./ALERT_RULES_GUIDE.md)
- [Cluster Integration Guide](../CLUSTER_INTEGRATION_GUIDE.md)

## Support

For issues or questions:

1. Check script logs: `script.sh -v`
2. Review documentation: `*_GUIDE.md`
3. Check GitHub issues: github.com/picocluster/ApplicationSets/issues
4. Review system logs: `journalctl -n 100`

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
**Version**: 1.0
