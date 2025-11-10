# PicoCluster Alert Rules Guide

Comprehensive guide for Prometheus alert rules in PicoCluster monitoring.

## Quick Start

### Deploy Alert Rules

```bash
# Basic deployment (no notifications)
ansible-playbook cluster-management/deploy_alert_rules.ansible

# With Slack notifications
ansible-playbook cluster-management/deploy_alert_rules.ansible \
  -e slack_webhook_url="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### View Active Alerts

- **Prometheus UI**: http://localhost:9090/alerts
- **Grafana**: Alerts → Alert Rules

## Alert Categories & Rules

### 1. Node Health Alerts

#### NodeDown
- **Severity**: CRITICAL
- **Threshold**: Node up status == 0 for 5 minutes
- **What it means**: A cluster node is unreachable
- **Action**:
  1. SSH into node or check physical connection
  2. Verify network connectivity
  3. Check node logs: `journalctl -n 50`
  4. Restart node if necessary

#### NodeUnreachableFor30Minutes
- **Severity**: CRITICAL
- **Threshold**: Node down for 30 minutes
- **What it means**: Node has been offline for extended period
- **Action**:
  1. Check if node is powered off
  2. Check if OS crashed
  3. Review recent changes/updates
  4. Consider removing from cluster if dead

#### MultipleNodesDown
- **Severity**: CRITICAL
- **Threshold**: 2+ nodes down for 5 minutes
- **What it means**: Potential network issue affecting multiple nodes
- **Action**:
  1. Check cluster network switch/router
  2. Check main node network interface
  3. Investigate any recent network changes
  4. Check for IP conflicts

### 2. CPU Usage Alerts

#### HighCPUUsage
- **Severity**: WARNING
- **Threshold**: CPU > 85% for 5 minutes
- **What it means**: A node is heavily loaded
- **Metrics**: `100 - (rate(node_cpu_seconds_total{mode="idle"}[5m]) * 100)`
- **Action**:
  1. Identify resource-consuming processes: `top` or `htop`
  2. Check if expected workload or runaway process
  3. Consider load balancing if expected
  4. Stop/scale down services if unexpected

#### CriticalCPUUsage
- **Severity**: CRITICAL
- **Threshold**: CPU > 95% for 2 minutes
- **What it means**: Node is at near-maximum capacity
- **Action**:
  1. Immediate investigation required
  2. Kill runaway processes if identified
  3. Migrate workloads to other nodes
  4. Consider adding more compute capacity

### 3. Memory Usage Alerts

#### HighMemoryUsage
- **Severity**: WARNING
- **Threshold**: Memory > 85% for 5 minutes
- **What it means**: Limited memory headroom available
- **Action**:
  1. Identify memory-consuming processes
  2. Check for memory leaks
  3. Review Grafana dashboard for trends
  4. Plan capacity upgrade if persistently high

#### CriticalMemoryUsage
- **Severity**: CRITICAL
- **Threshold**: Memory > 95% for 2 minutes
- **What it means**: Node running out of memory
- **Action**:
  1. Check if services are crashing
  2. Increase swap space temporarily
  3. Stop non-critical services
  4. Plan immediate upgrade

#### OutOfMemory
- **Severity**: CRITICAL
- **Threshold**: < 100MB available memory
- **What it means**: Node has critical memory shortage
- **Action**:
  1. Node likely experiencing OOM killer
  2. Restart services to free memory
  3. Add more RAM immediately
  4. Monitor `/var/log/syslog` for OOM kills

### 4. Disk Space Alerts

#### DiskSpaceWarning
- **Severity**: WARNING
- **Threshold**: Disk > 80% for 5 minutes
- **What it means**: Limited disk space remaining
- **Action**:
  1. Identify large files: `du -sh /*`
  2. Clean up old logs: `journalctl --vacuum=7d`
  3. Remove old container images
  4. Clean temporary files: `/tmp`, `/var/tmp`

#### DiskSpaceCritical
- **Severity**: CRITICAL
- **Threshold**: Disk > 90% for 2 minutes
- **What it means**: Very little disk space left
- **Action**:
  1. Immediate cleanup required
  2. Check system logs for errors
  3. Prometheus may stop accepting data
  4. Add more disk space

#### DiskFull
- **Severity**: CRITICAL
- **Threshold**: Disk >= 98%
- **What it means**: Disk is essentially full
- **Action**:
  1. Emergency cleanup immediately
  2. Services will likely fail
  3. Consider read-only filesystem
  4. Add storage urgently

#### InodeSpaceWarning
- **Severity**: WARNING
- **Threshold**: Inodes > 80% for 5 minutes
- **What it means**: Too many files/directories
- **Action**:
  1. Find directories with many files: `find / -type f | wc -l`
  2. Check for excessive logging
  3. Clean old temporary files
  4. Consider increasing inode count

### 5. Network Alerts

#### HighNetworkPacketLoss
- **Severity**: WARNING
- **Threshold**: > 100 errors/sec for 5 minutes
- **What it means**: Network connection quality degraded
- **Action**:
  1. Check network interface: `ethtool <interface>`
  2. Check for cable issues
  3. Review switch port statistics
  4. Check for duplex/speed mismatches

#### NetworkInterfaceDown
- **Severity**: WARNING
- **Threshold**: Interface is down for 5 minutes
- **What it means**: Network interface not active
- **Action**:
  1. Bring interface up: `sudo ip link set <iface> up`
  2. Check NetworkManager status
  3. Verify IP configuration
  4. Check physical cable connection

### 6. Prometheus Alerts

#### PrometheusDown
- **Severity**: CRITICAL
- **Threshold**: Prometheus not responding for 5 minutes
- **What it means**: Monitoring system offline
- **Action**:
  1. Check Prometheus service: `sudo systemctl status prometheus`
  2. Check disk space on monitoring node
  3. Check logs: `sudo journalctl -u prometheus -f`
  4. Restart service: `sudo systemctl restart prometheus`

#### PrometheusHighScrapeErrorRate
- **Severity**: WARNING
- **Threshold**: Error rate > 5% for 10 minutes
- **What it means**: Prometheus can't scrape targets properly
- **Action**:
  1. Check target status: http://localhost:9090/targets
  2. Verify target nodes are reachable
  3. Check Node Exporter on targets
  4. Review Prometheus logs

#### PrometheusConfigReloadFailure
- **Severity**: CRITICAL
- **Threshold**: Config reload failed
- **What it means**: Configuration has syntax error
- **Action**:
  1. Validate config: `promtool check config /etc/prometheus/prometheus.yml`
  2. Check recent changes to config
  3. Review Prometheus logs for error details
  4. Revert to last known good config if needed

### 7. Grafana Alerts

#### GrafanaDown
- **Severity**: CRITICAL
- **Threshold**: Not responding for 5 minutes
- **What it means**: Dashboard system offline
- **Action**:
  1. Check Grafana service: `sudo systemctl status grafana-server`
  2. Check port 3000: `sudo netstat -tlnp | grep 3000`
  3. Check logs: `sudo journalctl -u grafana-server -f`
  4. Restart service: `sudo systemctl restart grafana-server`

### 8. Docker Alerts

#### DockerDaemonDown
- **Severity**: WARNING
- **Threshold**: Not responding for 5 minutes
- **What it means**: Docker daemon not accessible
- **Action**:
  1. Check Docker status: `sudo systemctl status docker`
  2. Verify Docker socket: `ls -la /var/run/docker.sock`
  3. Check logs: `sudo journalctl -u docker -f`
  4. Restart: `sudo systemctl restart docker`

#### HighContainerRestarts
- **Severity**: WARNING
- **Threshold**: > 10 restarts in 5 minutes
- **What it means**: Containers repeatedly crashing
- **Action**:
  1. Check container logs: `docker logs <container_id>`
  2. Identify unhealthy containers
  3. Review application logs for errors
  4. Consider resource limits

### 9. Kubernetes Alerts

#### KubeletDown
- **Severity**: CRITICAL
- **Threshold**: Not responding for 5 minutes
- **What it means**: Kubernetes node agent offline
- **Action**:
  1. SSH to node and check kubelet: `systemctl status kubelet`
  2. Check K3s/K8s: `kubectl get nodes`
  3. Check logs: `journalctl -u kubelet -f`
  4. Restart: `systemctl restart kubelet`

#### KubePodCrashLooping
- **Severity**: WARNING
- **Threshold**: Pod restarting frequently
- **What it means**: Application keeps crashing
- **Action**:
  1. Check pod status: `kubectl describe pod <pod_name>`
  2. View logs: `kubectl logs <pod_name> --previous`
  3. Check events: `kubectl get events --sort-by='.lastTimestamp'`
  4. Fix application or resource limits

#### KubeNodeNotReady
- **Severity**: CRITICAL
- **Threshold**: Node not in Ready state
- **What it means**: Kubernetes reports node unhealthy
- **Action**:
  1. Check node status: `kubectl get nodes`
  2. Describe node: `kubectl describe node <node_name>`
  3. Check kubelet logs
  4. May need node restart or remediation

#### KubeMemoryPressure
- **Severity**: WARNING
- **Threshold**: Node has memory pressure
- **What it means**: Kubernetes detected low available memory
- **Action**:
  1. Drain and reboot node
  2. Review memory allocations
  3. Evict pods if necessary
  4. Check for memory leaks

#### KubeDiskPressure
- **Severity**: WARNING
- **Threshold**: Node has disk pressure
- **What it means**: Low disk space detected by kubelet
- **Action**:
  1. Check disk space: `df -h`
  2. Clean up old images: `crictl rmi --prune`
  3. Review container logs
  4. Add disk space if persistent

### 10. System Alerts

#### SystemLoadHigh
- **Severity**: WARNING
- **Threshold**: 5-minute load > CPU count
- **What it means**: System load exceeds capacity
- **Action**:
  1. Check load: `uptime`
  2. Identify heavy processes: `top`
  3. Check I/O: `iostat -x 1 5`
  4. Balance load or upgrade hardware

#### TooManyOpenFiles
- **Severity**: WARNING
- **Threshold**: File descriptors > 90%
- **What it means**: Approaching system limit on open files
- **Action**:
  1. Check limits: `ulimit -a`
  2. Identify process with many files: `lsof | wc -l`
  3. Increase limits in `/etc/security/limits.conf`
  4. Restart affected services

## Alert Severity Levels

| Severity | Response Time | Action Required | Example |
|----------|---------------|-----------------|---------|
| **critical** | Immediate | Yes, urgent | Node down, Disk full, Out of memory |
| **warning** | Soon (hours) | Yes, planned | High CPU, Disk warning, Pod crashing |
| **info** | As time allows | Optional | Info alerts, trends |

## Configuring Alert Thresholds

All thresholds are defined in `/etc/prometheus/alert_rules.yml`. To adjust:

```bash
# Edit alert rules
sudo nano /etc/prometheus/alert_rules.yml

# Change threshold, e.g., CPU from 85% to 80%
# From: expr: ... > 85
# To:   expr: ... > 80

# Validate configuration
promtool check rules /etc/prometheus/alert_rules.yml

# Reload Prometheus
sudo systemctl reload prometheus
```

### Common Threshold Adjustments

**Stricter (more alerts):**
- CPU: 85% → 75%
- Memory: 85% → 75%
- Disk: 80% → 70%

**Lenient (fewer false positives):**
- CPU: 85% → 90%
- Memory: 85% → 90%
- Disk: 80% → 85%

## Setting Up Notifications

### Slack Integration

1. **Create Slack Webhook:**
   - Go to Slack workspace settings
   - Create incoming webhook
   - Copy webhook URL

2. **Deploy with Slack:**
   ```bash
   ansible-playbook cluster-management/deploy_alert_rules.ansible \
     -e slack_webhook_url="https://hooks.slack.com/services/..."
   ```

3. **Verify:**
   - Check AlertManager: `sudo systemctl status alertmanager`
   - View config: `sudo cat /etc/alertmanager/alertmanager.yml`

### Email Notifications

Edit `/etc/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'email'
    email_configs:
      - to: 'ops@example.com'
        from: 'prometheus@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'prometheus@example.com'
        auth_password: 'password'
        send_resolved: true
```

### PagerDuty Integration

```yaml
receivers:
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR-SERVICE-KEY'
        description: '{{ .GroupLabels.alertname }}'
```

## Testing Alerts

### Test by Stopping a Service

```bash
# Stop Node Exporter to trigger NodeDown alert
sudo systemctl stop node_exporter

# Wait 5 minutes for alert to fire
# Check Prometheus UI: http://localhost:9090/alerts

# Restart to clear alert
sudo systemctl start node_exporter
```

### Test by Creating High Load

```bash
# Trigger CPU alert
stress-ng --cpu 4 --timeout 10m

# Trigger Memory alert
stress-ng --vm 1 --vm-bytes 80% --timeout 10m

# Monitor in Grafana/Prometheus
```

## Viewing Alert History

```bash
# All alerts (firing and resolved)
curl -s http://localhost:9090/api/v1/alerts | jq '.'

# Specific alert
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname=="NodeDown")'

# Using PromQL
# expr: ALERTS_FOR_STATE{alertname="NodeDown"}
```

## Alert Best Practices

1. **Alert on symptoms, not causes**
   - Alert on "high CPU" not "many processes"

2. **Set appropriate thresholds**
   - Too low = alert fatigue
   - Too high = missing real issues

3. **Include runbook links**
   - Each alert has `runbook_url` annotation

4. **Monitor alert quality**
   - Track false positive rate
   - Adjust thresholds based on experience

5. **Escalation strategy**
   - Critical → immediate page
   - Warning → ticket/email
   - Info → dashboard only

## Troubleshooting

### Alerts Not Firing

1. Check if rules loaded:
   ```bash
   curl -s http://localhost:9090/api/v1/rules | jq '.data.groups'
   ```

2. Verify alert expression:
   ```bash
   # Query the alert condition in Prometheus UI
   # If it returns 0, alert won't fire
   ```

3. Check Prometheus logs:
   ```bash
   sudo journalctl -u prometheus | grep -i alert
   ```

### Too Many False Positives

1. Increase threshold
2. Increase `for` duration
3. Review historical data

### Notifications Not Sending

1. Check AlertManager:
   ```bash
   sudo systemctl status alertmanager
   sudo journalctl -u alertmanager -f
   ```

2. Test webhook:
   ```bash
   curl -X POST https://hooks.slack.com/services/... \
     -d '{"text":"Test message"}'
   ```

3. Verify configuration syntax

## See Also

- [Prometheus Alerting](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [AlertManager Configuration](https://prometheus.io/docs/alertmanager/latest/configuration/)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
