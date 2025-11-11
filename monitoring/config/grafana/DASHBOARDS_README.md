# PicoCluster Grafana Dashboards

Comprehensive dashboard suite for complete cluster visibility and troubleshooting.

## Dashboard Summary

### 1. **Cluster Overview** (`dashboard_cluster_overview.json`)
**Purpose**: High-level cluster status at a glance

**Shows**:
- Node online/offline status (pie chart)
- Cluster average CPU, Memory, Disk (gauges)
- Node uptime tracking
- Network interface count
- Per-node CPU and memory usage trends

**Best For**: Daily check-in, quick status verification

**Key Metrics**:
- 4 status gauges (CPU, Memory, Disk, Node Status)
- Uptime trends
- Resource utilization by node

---

### 2. **System Metrics** (`dashboard_system_metrics.json`)
**Purpose**: Detailed system performance metrics

**Shows**:
- CPU usage percentage per node
- Memory utilization per node
- Disk read/write activity
- Network input/output rates

**Best For**: Performance tuning, bottleneck identification

**Key Panels**:
- CPU Usage by Node (line graph)
- Memory Usage by Node (line graph)
- Disk Read Activity (time series)
- Disk Write Activity (time series)
- Network In (bytes/sec)
- Network Out (bytes/sec)

---

### 3. **Docker & Container Metrics** (`dashboard_docker_metrics.json`)
**Purpose**: Container runtime performance

**Shows**:
- Running container count over time
- Per-container CPU usage
- Per-container memory usage
- Container network I/O

**Best For**: Docker/container troubleshooting, resource allocation

**Best For**: Container orchestration teams

**Key Panels**:
- Container Count Over Time
- Container CPU Usage (per container)
- Container Memory Usage (per container)
- Container Network In/Out

---

### 4. **Kubernetes Metrics** (`dashboard_kubernetes_metrics.json`)
**Purpose**: K3s/Kubernetes cluster health

**Shows**:
- Total pods and nodes (stat cards)
- Running pod count
- CPU usage by node
- Memory usage by node
- Pods per namespace (stacked bar)

**Best For**: Kubernetes cluster operations

**Key Panels**:
- Total Pods stat
- Total Nodes stat
- Running Pods stat
- CPU Usage by Node
- Memory Usage by Node
- Pods per Namespace

---

### 5. **Cluster Inventory** (`dashboard_cluster_inventory.json`)
**Purpose**: Hardware and software inventory

**Shows**:
- Node inventory table (hostname, IP, OS, arch)
- Total cluster resources (cores, RAM, disk)
- CPU specifications
- Memory capacity by node
- Disk capacity by node

**Best For**: Capacity planning, infrastructure overview

**Key Components**:
- Node Inventory Table
- CPU Details
- Memory by Node
- Disk Size by Node

---

### 6. **Service Health** (`dashboard_service_health.json`)
**Purpose**: Cluster service status and performance

**Shows**:
- Prometheus, Grafana, Consul, Traefik, Harbor, Ceph status
- Service request rates
- Service error rates
- Response latency (p95)

**Best For**: Infrastructure service monitoring

**Services Monitored**:
- Prometheus
- Grafana
- Consul
- Traefik
- Harbor
- Ceph
- HTTP services (if available)

---

### 7. **Network Performance** (`dashboard_network_performance.json`)
**Purpose**: Network utilization and health

**Shows**:
- Inbound bandwidth by node (Mbps)
- Outbound bandwidth by node (Mbps)
- Network packet rates
- Network errors
- TCP connection states

**Best For**: Network troubleshooting, bandwidth monitoring

**Key Metrics**:
- Network Inbound Bandwidth
- Network Outbound Bandwidth
- Packet Rate (In)
- Network Errors
- TCP Connection States

---

### 8. **Capacity Planning** (`dashboard_capacity_planning.json`)
**Purpose**: Resource utilization trends and projections

**Shows**:
- Cluster-wide utilization gauges (4)
- Memory capacity by node (total vs available)
- Disk capacity by node (total vs available)
- Projected days until disk full

**Best For**: Capacity planning, growth forecasting

**Key Panels**:
- Memory Utilization Gauge
- Disk Utilization Gauge
- CPU Utilization Gauge
- Inode Utilization Gauge
- Memory Capacity Trends
- Disk Capacity Trends
- Disk Growth Projection

---

### 9. **Workload Performance** (`dashboard_workload_performance.json`)
**Purpose**: System workload and I/O performance

**Shows**:
- Running and blocked processes
- System load average (1m, 5m, 15m)
- Disk read operations per second
- Disk write operations per second
- Disk I/O time

**Best For**: Workload analysis, I/O bottleneck detection

**Key Panels**:
- Running & Blocked Processes
- System Load Average
- Disk Read Operations
- Disk Write Operations
- Disk I/O Time

---

### 10. **EdgeX Foundry Monitoring** (`dashboard_edgex_monitoring.json`)
**Purpose**: IoT edge platform monitoring and device management

**Shows**:
- Total events ingested (24h)
- Event ingestion rate (events/second)
- Active device count
- Service health status
- Event ingestion trends
- Reading count by device
- Service response times
- Error rates by service
- Consul health checks
- Redis memory usage
- Device status table
- Data export throughput

**Best For**: IoT edge computing, device monitoring, EdgeX operations

**Key Components**:
- Event Metrics (total, rate)
- Device Monitoring
- Service Performance
- Infrastructure Health (Consul, Redis)
- Export Analytics

**Requires**:
- EdgeX Foundry deployed
- Prometheus metrics enabled
- EdgeX services exposing /api/v3/metrics

---

### 11. **Proxmox VE Monitoring** (`dashboard_proxmox_monitoring.json`)
**Purpose**: Virtualization platform monitoring for VMs and containers

**Shows**:
- Proxmox host status
- Running VMs and containers count
- Host CPU, memory, storage usage
- Per-VM CPU and memory usage
- Network traffic
- Disk I/O
- VM/Container status table
- Storage pool usage
- Container resource usage

**Best For**: Virtualization management, VM performance, capacity planning

**Key Components**:
- Host Health (status, resources)
- VM Metrics (CPU, memory per VM)
- Container Metrics (LXC resources)
- Storage Monitoring
- Network & I/O Performance
- Guest Status Table

**Requires**:
- Proxmox VE deployed (x86-64 only)
- pve-exporter or similar Prometheus exporter
- Node Exporter on Proxmox host

**Note**: Proxmox VE is x86-64 only (Odroid H4), not available on ARM64 platforms

---

## Dashboard Usage Patterns

### Morning Briefing
1. Open **Cluster Overview**
2. Verify node status and resource usage
3. Check for any warnings or issues

### Performance Investigation
1. Start with **Cluster Overview** for high-level view
2. Drill into **System Metrics** for node-level details
3. Check **Workload Performance** for I/O issues
4. Look at **Network Performance** if network-related

### Container Troubleshooting
1. Open **Docker & Container Metrics**
2. Find problematic container
3. Check its CPU/memory/network usage
4. Correlate with host metrics from **System Metrics**

### Capacity Planning
1. Review **Capacity Planning** dashboard
2. Check growth trends over 30 days
3. Note "Days until Full" projections
4. Plan upgrades based on trends

### Service Health Check
1. Open **Service Health** dashboard
2. Verify all services are UP (green)
3. Check request rates and error rates
4. Monitor latency trends

### Kubernetes Operations
1. Open **Kubernetes Metrics** dashboard
2. Check total pods and nodes
3. Verify pod distribution
4. Monitor per-node resource usage

---

## Dashboard Access

**URL Format**:
```
http://<monitoring-node>:3000/d/<dashboard-uid>
```

**Direct Links**:
- **Cluster Overview**: `/d/picocluster-cluster-overview`
- **System Metrics**: `/d/picocluster-system-metrics`
- **Docker Metrics**: `/d/picocluster-docker-metrics`
- **Kubernetes**: `/d/picocluster-kubernetes-metrics`
- **Inventory**: `/d/picocluster-inventory`
- **Service Health**: `/d/picocluster-service-health`
- **Network Performance**: `/d/picocluster-network-performance`
- **Capacity Planning**: `/d/picocluster-capacity-planning`
- **Workload Performance**: `/d/picocluster-workload-performance`

---

## Pre-requisites for Each Dashboard

### All Dashboards
- Node Exporter installed on all nodes (port 9100)
- Prometheus scraping Node Exporter metrics

### Docker & Container Metrics
- Docker with metrics enabled (port 9323)
- Docker Node Exporter or cAdvisor

### Kubernetes Metrics
- K3s or Kubernetes installed
- kube-state-metrics deployed
- Prometheus access to kubelet

### Service Health
- Service-specific Prometheus exporters
- Consul, Traefik, Harbor metrics endpoints

---

## Customizing Dashboards

### Change Time Range
Click time picker in top-right (default: last 6 hours)

### Add New Panels
1. Click **+** or **Add Panel**
2. Select Prometheus as datasource
3. Enter PromQL query
4. Configure visualization

### Export Dashboard
1. Click dashboard settings (gear icon)
2. Click **Export**
3. Choose with or without data

### Import Dashboard
1. Click **+** → **Import**
2. Paste JSON or upload file
3. Confirm datasource

---

## Dashboard Performance Tips

### For Large Clusters (20+ nodes)
- Reduce time range to last 1-2 hours
- Aggregate metrics using PromQL
- Use recording rules for expensive queries

### For Small Clusters (4-8 nodes)
- Use longer time ranges (24h, 7d) for trend analysis
- All dashboards work without optimization

### For High-Frequency Metrics
- Prometheus scrape interval: 30s (instead of 15s)
- Metrics retention: 7d (instead of 30d)

---

## Common Queries by Dashboard

### System Metrics
```promql
# CPU usage
100 - (avg by (node) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
100 * (1 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)))

# Disk usage
100 * (1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}))
```

### Network Performance
```promql
# Inbound bandwidth (Mbps)
rate(node_network_receive_bytes_total[5m]) * 8 / 1000000

# Network errors
rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m])
```

### Workload
```promql
# System load average
node_load5

# Disk I/O operations
rate(node_disk_reads_completed_total[5m])
rate(node_disk_writes_completed_total[5m])
```

---

## Troubleshooting Dashboard Issues

### Dashboard Shows "No Data"
1. Verify Node Exporter is running: `systemctl status node_exporter`
2. Check Prometheus targets: `http://localhost:9090/targets`
3. Verify PromQL query in Prometheus UI

### Dashboard is Slow
1. Reduce time range
2. Check Prometheus performance
3. Review dashboard query count

### Missing Panels
1. Verify required metrics are available
2. Check Prometheus datasource connection
3. Review dashboard JSON for errors

---

## Next Dashboard Ideas

Future dashboards to consider:
- **Application Performance**: Request latency, throughput, error rates
- **Security Events**: SSH logins, failed auth, firewall blocks
- **Storage Performance**: Ceph cluster, volume usage, throughput
- **Log Analytics**: Structured logs, error patterns
- **Cost Analysis**: Resource utilization vs cost

---

## See Also

- [Monitoring Setup Guide](../MONITORING_SETUP_GUIDE.md)
- [Prometheus Documentation](https://prometheus.io/docs)
- [Grafana Documentation](https://grafana.com/docs)

---

**Last Updated**: 2025-11-11
**Status**: Production Ready
**Total Dashboards**: 11
**Metrics Covered**: 75+
