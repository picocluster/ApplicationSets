# CoreDNS Setup Guide for PicoCluster

Complete guide for setting up DNS service discovery in your PicoCluster.

## Overview

CoreDNS provides:
- **Service Discovery**: Resolve cluster services by name
- **Load Balancing**: DNS-based load distribution
- **Health Checking**: Failover for unhealthy services
- **Consul Integration**: Automatic service registration
- **Split-Horizon DNS**: Internal vs external name resolution

## Quick Start

### 1. Install CoreDNS on Dedicated Node

```bash
# Install on a dedicated DNS server node
ansible-playbook infrastructure/dns/install_coredns.ansible -l dns-server

# Or install on multiple nodes for redundancy
ansible-playbook infrastructure/dns/install_coredns.ansible
```

This installs:
- CoreDNS binary
- Systemd service
- Configuration files
- Zone files for cluster.local domain

### 2. Configure Cluster Nodes to Use CoreDNS

```bash
# Get DNS server IP
COREDNS_IP=$(host dns-server | awk '/has address/ {print $4}' | head -1)

# Configure all cluster nodes
ansible-playbook infrastructure/dns/configure_cluster_dns.ansible \
  -e coredns_server="$COREDNS_IP" \
  -e cluster_domain="cluster.local"

# Or manually on a single node
sudo ./infrastructure/dns/configure_cluster_dns.sh 10.1.10.245 cluster.local
```

### 3. Verify DNS Resolution

```bash
# Test DNS query
dig @<dns-server-ip> monitoring.cluster.local +short

# Verify cluster services
nslookup prometheus.cluster.local <dns-server-ip>
nslookup kubernetes.cluster.local <dns-server-ip>

# Check upstream DNS
nslookup google.com <dns-server-ip>
```

## Configuration

### Corefile (Main DNS Configuration)

**Location**: `/etc/coredns/Corefile`

Key sections:
```coredns
cluster.local:53 {
  # Consul service discovery
  consul {
    upstream 8.8.8.8 8.8.4.4
  }

  # Zone file for static entries
  file /etc/coredns/db.cluster.local

  # Kubernetes service discovery
  kubernetes cluster.local

  # Forward unknown queries to upstream
  forward . 8.8.8.8 8.8.4.4

  # Enable caching (30 second TTL)
  cache 30

  # Enable logging
  log

  # Prometheus metrics
  prometheus 0.0.0.0:5353
}
```

### Zone File

**Location**: `/etc/coredns/db.cluster.local`

Add cluster services:
```dns
; Internal cluster services
monitoring      IN      A       10.1.10.245
prometheus      IN      CNAME   monitoring.cluster.local
grafana         IN      CNAME   monitoring.cluster.local
kubernetes      IN      A       10.1.10.240

; Cluster nodes
pc0             IN      A       10.1.10.240
pc1             IN      A       10.1.10.241
pc2             IN      A       10.1.10.242
```

## Usage

### Query Cluster Services

```bash
# Resolve monitoring service
dig @<dns-server> monitoring.cluster.local
dig @<dns-server> prometheus.cluster.local
dig @<dns-server> grafana.cluster.local

# Resolve Kubernetes service
dig @<dns-server> kubernetes.cluster.local

# Resolve node by hostname
dig @<dns-server> pc0.cluster.local

# Use with nslookup
nslookup monitoring.cluster.local <dns-server>

# Use with host command
host monitoring.cluster.local <dns-server>
```

### Configure Applications

**In shell scripts:**
```bash
# Use cluster domain names
curl http://prometheus.cluster.local:9090/

# With service discovery
GRAFANA_HOST="grafana.cluster.local"
GRAFANA_PORT="3000"
```

**In application config:**
```yaml
# Kubernetes YAML
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: my-app
  clusterIP: None
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

**In DNS lookups:**
```bash
# Service discovery pattern
curl http://service-name.cluster.local:port/endpoint
```

## Service Discovery with Consul

### Enable Consul Integration

Edit `/etc/coredns/Corefile`:

```coredns
cluster.local:53 {
  consul {
    # Consul server address
    upstream consul.consul:8600

    # Only return healthy services
    only_healthy

    # Use specific token
    token "your-consul-token"
  }

  # ... rest of configuration
}
```

### Register Services in Consul

```bash
# Register a service
curl -X PUT http://localhost:8500/v1/agent/service/register -d @- << EOF
{
  "ID": "prometheus-1",
  "Name": "prometheus",
  "Address": "10.1.10.245",
  "Port": 9090,
  "Check": {
    "HTTP": "http://10.1.10.245:9090/-/healthy",
    "Interval": "10s"
  }
}
EOF

# Query service from DNS
dig @<dns-server> prometheus.service.consul
```

## Monitoring

### Prometheus Metrics

CoreDNS exposes Prometheus metrics on port 5353:

```bash
# View metrics
curl http://localhost:5353/metrics

# Add to Prometheus scrape config
- job_name: 'coredns'
  static_configs:
    - targets: ['<dns-server>:5353']
```

### Key Metrics

- `coredns_dns_requests_total` - Total DNS requests
- `coredns_dns_responses_total` - Total DNS responses
- `coredns_dns_request_duration_seconds` - Request latency
- `coredns_cache_hits_total` - Cache hit count
- `coredns_cache_misses_total` - Cache miss count

### Example Grafana Dashboard

Create a dashboard panel:

```promql
# Query requests per second
rate(coredns_dns_requests_total[5m])

# Cache hit rate
rate(coredns_cache_hits_total[5m]) / (rate(coredns_cache_hits_total[5m]) + rate(coredns_cache_misses_total[5m]))

# Average response time
rate(coredns_dns_request_duration_seconds_sum[5m]) / rate(coredns_dns_requests_total[5m])
```

## Troubleshooting

### DNS Not Resolving

```bash
# 1. Check CoreDNS is running
systemctl status coredns

# 2. Check it's listening
netstat -tlnp | grep coredns

# 3. Test directly on CoreDNS server
dig @localhost cluster.local

# 4. Check logs
journalctl -u coredns -f

# 5. Verify Corefile syntax
coredns -test -conf /etc/coredns/Corefile
```

### Slow DNS Resolution

```bash
# 1. Check upstream DNS
dig @8.8.8.8 google.com

# 2. Check cache metrics
curl http://localhost:5353/metrics | grep cache

# 3. Increase cache TTL in Corefile
cache 60  # Increase from 30s

# 4. Check for network issues
ping <upstream-dns>
```

### Service Not Found

```bash
# 1. Verify zone file has entry
cat /etc/coredns/db.cluster.local | grep service-name

# 2. Query directly
dig @<dns-server> service-name.cluster.local

# 3. Check Consul registration
curl http://localhost:8500/v1/catalog/service/service-name

# 4. Reload CoreDNS
systemctl restart coredns
```

## Integration with Other Tools

### With Consul

CoreDNS can automatically discover services from Consul:

```coredns
consul {
  upstream 8.8.8.8 8.8.4.4
  only_healthy
}
```

### With Kubernetes/K3s

CoreDNS integrates with Kubernetes service discovery:

```coredns
kubernetes cluster.local in-addr.arpa ip6.arpa {
  pods insecure
  upstream 8.8.8.8 8.8.4.4
}
```

### With Prometheus

Use DNS names in Prometheus targets:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus.cluster.local:9090']

  - job_name: 'coredns'
    static_configs:
      - targets: ['coredns.cluster.local:5353']
```

## Best Practices

1. **Use Redundancy**
   - Install CoreDNS on multiple nodes
   - Configure clients to use multiple DNS servers
   - Use round-robin for failover

2. **Monitor DNS**
   - Enable Prometheus metrics
   - Create Grafana dashboards
   - Alert on resolution failures

3. **Cache Management**
   - Set appropriate TTL (15-60 seconds)
   - Monitor cache hit rate
   - Adjust for your workload

4. **Security**
   - Restrict DNS port with firewall
   - Use DNSSEC if available
   - Log all queries for audit

5. **Naming Conventions**
   - Use consistent service names
   - Include tier in names (e.g., db.prod.cluster.local)
   - Document all registered services

## Advanced Features

### Load Balancing

DNS round-robin load balancing:

```dns
; Multiple A records for load balancing
api     IN      A       10.1.10.240
api     IN      A       10.1.10.241
api     IN      A       10.1.10.242
```

### Health Checking

CoreDNS monitors service health:

```coredns
consul {
  only_healthy  # Only return healthy services
}
```

### Split-Horizon DNS

Return different answers based on query source:

```coredns
cluster.local:53 {
  # Internal query (from cluster)
  file /etc/coredns/db.cluster.local
}

.:53 {
  # External query
  forward . 8.8.8.8 8.8.4.4
}
```

## See Also

- [CoreDNS Documentation](https://coredns.io/)
- [CoreDNS Plugin Reference](https://coredns.io/plugins/)
- [Consul DNS Integration](https://www.consul.io/docs/agent/dns)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
