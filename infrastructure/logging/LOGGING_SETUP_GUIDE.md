# Loki Log Aggregation Setup Guide for PicoCluster

Complete guide for setting up centralized log aggregation with Loki and Promtail in your PicoCluster.

## Overview

Loki provides lightweight log aggregation without traditional indexing, making it ideal for resource-constrained clusters. Combined with Promtail (log shipper) and Grafana (visualization), it creates a complete logging stack.

### Architecture

```
Cluster Nodes
    ↓
Promtail (log shipper)
    ↓
Loki (log aggregator)
    ↓
Grafana (visualization)
```

### Key Features

- **Lightweight**: No full indexing, just label-based log management
- **LogQL**: Query language similar to PromQL for flexible searching
- **Multi-tenant**: Support for multiple log streams
- **Scalable**: Horizontal scaling with multi-target configuration
- **Integrated**: Native Grafana support for visualization
- **Retention Policies**: Automatic log cleanup after configurable period (default: 7 days)

## Quick Start

### Step 1: Install Loki on Logging/Monitoring Node

```bash
# Install on dedicated logging node
ansible-playbook infrastructure/logging/install_loki.ansible -l logging-node

# Or on your monitoring node
ansible-playbook infrastructure/logging/install_loki.ansible -l monitoring
```

Loki will:
- Install to `/usr/local/bin/loki`
- Configure at `/etc/loki/loki-config.yml`
- Store logs at `/var/lib/loki/chunks`
- Run on port 3100 (HTTP API)
- Expose metrics on port 3101

### Step 2: Deploy Promtail to All Cluster Nodes

```bash
# Deploy log shipper to all nodes
ansible-playbook infrastructure/logging/install_promtail.ansible

# Or to specific nodes
ansible-playbook infrastructure/logging/install_promtail.ansible -l worker-nodes
```

Promtail will:
- Auto-detect Loki server from 'logging' or 'monitoring' inventory group
- Ship logs from:
  - Systemd journal (last 24 hours)
  - Syslog logs
  - Application logs from `/var/log/applications/*.log`
  - Kubernetes pods (if K3s detected)
  - Docker containers (if Docker detected)
- Run on port 9080

### Step 3: Verify Installation

```bash
# Check Loki is running
sudo systemctl status loki

# Check Promtail on each node
sudo systemctl status promtail

# Test Loki health
curl http://localhost:3100/ready

# Test Promtail health
curl http://localhost:9080/metrics | head -20
```

### Step 4: Add Loki to Grafana

1. Open Grafana (http://monitoring.cluster.local:3000 or http://your-grafana-ip:3000)
2. Navigate to **Configuration → Data Sources**
3. Click **Add data source**
4. Select **Loki**
5. Set URL: `http://logging-node-ip:3100` or `http://loki.cluster.local:3100`
6. Click **Save & Test**

## Configuration

### Loki Configuration (`/etc/loki/loki-config.yml`)

Key sections:

```yaml
# Authentication
auth_enabled: false

# Ingestion settings
ingester:
  chunk_idle_period: 3m        # How long before chunks are flushed
  chunk_max_age: 1h            # Maximum chunk age
  max_chunk_age: 2h            # Hard limit on chunk age
  chunk_retain_period: 1m      # Retention after flush

# Limits and quotas
limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h    # Reject logs older than 7 days
  ingestion_rate_mb: 50               # Rate limiting
  ingestion_burst_size_mb: 100
  max_streams_per_user: 1000          # Max distinct label combinations

# Storage
storage_config:
  boltdb_shipper:
    active_index_directory: /var/lib/loki/boltdb-shipper-active
    cache_location: /var/lib/loki/boltdb-shipper-cache
  filesystem:
    directory: /var/lib/loki/chunks

# Retention
table_manager:
  retention_deletes_enabled: true
  retention_period: 168h        # 7 days
```

### Promtail Configuration (`/etc/promtail/config.yml`)

Key sections:

```yaml
# Server settings
server:
  http_listen_port: 9080
  log_level: info

# Loki target
clients:
  - url: http://loki-server:3100/loki/api/v1/push

# Log sources
scrape_configs:
  - job_name: systemd
    journal:
      max_age: 24h              # Only last 24 hours
      labels:
        job: systemd-journal

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          __path__: /var/log/syslog

  - job_name: applications
    static_configs:
      - targets:
          - localhost
        labels:
          job: applications
          __path__: /var/log/applications/*.log
```

## Usage

### Querying Logs in Grafana

Access logs through Grafana's Explore view:

1. Click **Explore** in left sidebar
2. Select **Loki** as datasource
3. Use LogQL queries:

### Basic LogQL Queries

```logql
# All logs on a specific host
{hostname="pc0"}

# Systemd journal logs
{job="systemd-journal", hostname="pc1"}

# Application error logs
{job="applications"} | json level="error"

# Kubernetes logs in default namespace
{namespace="default"} | json

# Combine multiple conditions
{job="systemd-journal"} | json priority="err"

# Regex filtering
{unit="docker.service"} | regex "error|failed"

# String matching
{job="syslog"} |= "error"

# Multi-line logs
{job="applications"} | json | line_format "{{.timestamp}} {{.level}} {{.message}}"
```

### Advanced Queries

```logql
# Count logs per unit
sum by(unit) (count_over_time({job="systemd-journal"}[5m]))

# Average response time from application logs
avg by(endpoint) (
  count_over_time(
    {job="applications"}
    | json response_time="latency_ms"
    [1m]
  )
)

# Error rate in Kubernetes pods
sum by(pod, namespace) (
  rate({namespace="default"} | json level="error" [5m])
)
```

### Creating Dashboards with Logs

1. Create a new dashboard
2. Add a Logs panel
3. Write LogQL query
4. Configure display options

Example dashboard setup:

```
Panel 1: System Errors
  Query: {job="systemd-journal"} | json level="err"

Panel 2: Application Activity
  Query: {job="applications"} | json

Panel 3: Container Logs
  Query: {job="containers"}
```

## Service Discovery with Loki

### Automatic Loki Discovery

Promtail automatically detects Loki server in this order:
1. Use `-e loki_server` parameter if provided
2. Use 'logging' inventory group from Ansible
3. Use 'monitoring' inventory group
4. Fall back to localhost

### Setting Custom Loki Server

```bash
# Deploy to specific Loki server
ansible-playbook infrastructure/logging/install_promtail.ansible \
  -e loki_server="10.1.10.245" \
  -e loki_port=3100
```

## Monitoring Loki

### Health Checks

```bash
# Check Loki is ready
curl http://localhost:3100/ready

# View Loki metrics (Prometheus format)
curl http://localhost:3101/metrics

# Check stored chunks
ls -lah /var/lib/loki/chunks/

# View current disk usage
du -sh /var/lib/loki/
```

### Prometheus Integration

Add to Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'loki'
    static_configs:
      - targets: ['loki-server:3101']

  - job_name: 'promtail'
    static_configs:
      - targets: ['node1:9080', 'node2:9080', 'node3:9080']
```

### Key Metrics

- `loki_ingester_chunks_created_total` - Total chunks created
- `loki_distributor_bytes_received_total` - Bytes ingested
- `loki_distributor_lines_received_total` - Lines ingested
- `loki_request_duration_seconds` - Request latency
- `promtail_read_bytes_total` - Bytes read by Promtail

## Storage Management

### Checking Storage Usage

```bash
# Total Loki storage
du -sh /var/lib/loki/

# Size by component
du -sh /var/lib/loki/chunks/
du -sh /var/lib/loki/boltdb-shipper-*

# Most recent chunks
ls -laht /var/lib/loki/chunks/ | head -20
```

### Adjusting Retention Policy

Edit `/etc/loki/loki-config.yml`:

```yaml
table_manager:
  retention_deletes_enabled: true
  retention_period: 504h        # 21 days (instead of 7)
```

Then restart Loki:

```bash
sudo systemctl restart loki
```

### Manual Cleanup

```bash
# List chunks older than 7 days
find /var/lib/loki/chunks/ -mtime +7 -type f

# Delete chunks older than 7 days (use with caution!)
find /var/lib/loki/chunks/ -mtime +7 -type f -delete
```

## Troubleshooting

### Loki Not Accepting Logs

```bash
# 1. Check Loki is running
sudo systemctl status loki

# 2. Check if listening on port 3100
sudo netstat -tlnp | grep 3100

# 3. Test connectivity
curl http://localhost:3100/ready

# 4. Check logs
sudo journalctl -u loki -f

# 5. Verify configuration syntax
loki -validate-config -config.file=/etc/loki/loki-config.yml
```

### Promtail Not Shipping Logs

```bash
# 1. Check Promtail is running
sudo systemctl status promtail

# 2. Check if listening on port 9080
sudo netstat -tlnp | grep 9080

# 3. Check Promtail logs
sudo journalctl -u promtail -f

# 4. Test Loki connectivity
curl http://loki-server:3100/ready

# 5. Verify configuration
cat /etc/promtail/config.yml | head -30
```

### High Disk Usage

```bash
# 1. Check current usage
du -sh /var/lib/loki/

# 2. Check retention settings
grep retention_period /etc/loki/loki-config.yml

# 3. Check ingestion rate
curl http://localhost:3101/metrics | grep "loki_distributor_bytes"

# 4. Reduce retention period temporarily
systemctl stop loki
# Edit /etc/loki/loki-config.yml, change retention_period
systemctl start loki
```

### Slow Log Queries

```bash
# 1. Check Loki metrics
curl http://localhost:3101/metrics | grep request_duration

# 2. Check disk I/O
iostat -x 1 5

# 3. Check filesystem cache
free -h

# 4. Monitor Loki resources
ps aux | grep loki
```

### Logs Not Appearing in Grafana

```bash
# 1. Verify Grafana datasource
curl http://localhost:3000/api/datasources

# 2. Check Loki is in datasources
curl http://localhost:3000/api/datasources | jq '.[] | select(.type=="loki")'

# 3. Test LogQL query directly
curl 'http://loki-server:3100/loki/api/v1/query?query={job="systemd-journal"}'

# 4. Check logs exist
curl 'http://loki-server:3100/loki/api/v1/label'
```

## Best Practices

### 1. Label Strategy

Use consistent, hierarchical labels:

```yaml
labels:
  job: systemd-journal        # Log source
  hostname: pc0               # Which node
  instance: 10.1.10.240       # Node IP
  environment: production      # Environment
```

Avoid high-cardinality labels (too many unique values):
- ❌ Don't use: Timestamp, Request IDs, User IDs as labels
- ✓ Do use: Job name, Hostname, Service, Environment

### 2. Retention Policy

- **Development**: 3 days
- **Staging**: 7 days
- **Production**: 14-30 days

Consider disk space: 50GB SSD can hold ~30 days of moderate logging (100MB/day).

### 3. Log Parsing

Always use appropriate parsing:

```yaml
pipeline_stages:
  - json:           # If logs are JSON
      expressions:
        level: level
        message: message
  - regex:          # If logs are text with patterns
      expression: '(?P<timestamp>.*?) (?P<level>\w+) (?P<message>.*)'
  - labels:         # Extract labels from parsed fields
      level: ""
```

### 4. Monitoring Loki Itself

Create Grafana dashboard for Loki:

```promql
# Ingestion rate (MB/s)
rate(loki_distributor_bytes_received_total[5m]) / 1024 / 1024

# Error rate
rate(loki_distributor_errors_total[5m])

# Disk usage
disk_usage{path="/var/lib/loki"}
```

### 5. Backup Loki Configuration

```bash
# Backup Loki config and recent data
tar -czf loki-backup-$(date +%Y%m%d).tar.gz \
  /etc/loki/loki-config.yml \
  /var/lib/loki/

# Keep offsite backups
```

### 6. Resource Allocation

For 10-node cluster:
- **CPU**: Loki ~500m, Promtail ~100m per node
- **Memory**: Loki ~512MB, Promtail ~64MB per node
- **Disk**: 50GB for 7 days at 100MB/day

## Integration with Other Tools

### With Prometheus

Scrape Loki metrics:

```yaml
scrape_configs:
  - job_name: 'loki'
    static_configs:
      - targets: ['loki.cluster.local:3101']
```

Alert on Loki health:

```yaml
- alert: LokiDown
  expr: up{job="loki"} == 0
  for: 5m
```

### With Alertmanager

Send Grafana alerts to Slack when log patterns detected:

1. Create Grafana alert rule: `{level="error"}` appears
2. Configure notification channel: Slack webhook
3. Set alert threshold: > 100 errors in 5 minutes

### With Consul

Register Loki and Promtail services:

```bash
curl -X PUT http://localhost:8500/v1/agent/service/register -d @- << EOF
{
  "ID": "loki-1",
  "Name": "loki",
  "Address": "10.1.10.245",
  "Port": 3100,
  "Check": {
    "HTTP": "http://10.1.10.245:3100/ready",
    "Interval": "10s"
  }
}
EOF
```

### With Kubernetes

Scrape K3s logs:

```yaml
scrape_configs:
  - job_name: kubernetes
    kubernetes_sd_configs:
      - role: pod
    pipeline_stages:
      - docker: {}
      - json:
          expressions:
            message: log
            stream: stream
```

## Advanced Configuration

### Multi-Tenant Setup

For multiple environments on same Loki:

```yaml
# Loki config for multi-tenant
auth_enabled: true
auth_config:
  clients:
    prod-tenant:
      basic_auth:
        username: prod
        password: prod-secret
    dev-tenant:
      basic_auth:
        username: dev
        password: dev-secret
```

### S3 Storage Backend

Instead of filesystem:

```yaml
storage_config:
  aws:
    s3: s3://my-bucket/loki
    endpoint: s3.amazonaws.com
    region: us-east-1
    access_key_id: AKIAIOSFODNN7EXAMPLE
    secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### GCS Storage Backend

```yaml
storage_config:
  gcs:
    bucket_name: my-bucket
    key_file: /path/to/key.json
```

## Performance Tuning

### Increase Ingestion Limits

For high-volume clusters:

```yaml
limits_config:
  ingestion_rate_mb: 100      # Increase from 50
  ingestion_burst_size_mb: 200 # Increase from 100
  max_streams_per_user: 2000   # Increase from 1000
```

### Optimize Chunk Settings

```yaml
ingester:
  chunk_idle_period: 5m        # Higher = fewer flushes
  max_chunk_age: 2h            # Match retention needs
  chunk_max_age: 3h            # Hard limit
```

### Enable WAL (Write-Ahead Log)

For data durability:

```yaml
ingester:
  wal:
    enabled: true
    dir: /var/lib/loki/wal
    checkpoint_duration: 5m
```

## See Also

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Grafana Logging Guide](https://grafana.com/docs/grafana/latest/datasources/loki/)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
