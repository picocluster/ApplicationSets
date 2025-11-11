# Test Scripts

Automated validation scripts for ApplicationSets deployments.

## Quick Start

```bash
# Make scripts executable
chmod +x *.sh

# Run all tests
./run_all_tests.sh

# Run specific test
./test_edgex.sh
./test_proxmox.sh
```

## Available Tests

### EdgeX Foundry Tests

**test_edgex.sh** - Complete EdgeX validation
- Container status
- Service health (Consul, Core Data, Metadata, Command)
- Device registration
- Event ingestion
- Virtual device data generation

```bash
./test_edgex.sh [hostname]
```

**test_edgex_api.sh** - API endpoint validation
- Tests all REST API endpoints
- Validates JSON responses
- Checks device commands

```bash
./test_edgex_api.sh [hostname]
```

### Proxmox VE Tests

**test_proxmox.sh** - Proxmox validation
- Architecture check (x86-64 only)
- Proxmox kernel verification
- Service status (pveproxy, pvedaemon, pve-cluster)
- Web interface accessibility
- CLI command availability
- Virtualization support
- VM/Container management

```bash
./test_proxmox.sh [hostname]
```

### Kubernetes Tests

**test_kubernetes.sh** - Kubernetes cluster validation
- kubectl connectivity
- Node status
- System pod health
- Test deployment creation

```bash
./test_kubernetes.sh
```

### Monitoring Tests

**test_monitoring.sh** - Monitoring stack validation
- Prometheus health
- Grafana health
- Node Exporter
- Active targets

```bash
./test_monitoring.sh [prometheus_host] [prometheus_port] [grafana_host] [grafana_port]
```

### Integration Tests

**integration_test.sh** - Cross-service validation
- EdgeX → Prometheus integration
- Kubernetes → Prometheus integration
- Consul service discovery

```bash
./integration_test.sh
```

## Master Test Runner

**run_all_tests.sh** - Run all applicable tests
- Auto-detects deployed services
- Runs appropriate tests
- Generates summary report
- Saves results to timestamped directory

```bash
./run_all_tests.sh
```

Output:
```
test_results_YYYYMMDD_HHMMSS/
├── edgex.log
├── edgex_api.log
├── proxmox.log
├── kubernetes.log
├── monitoring.log
├── integration.log
└── SUMMARY.txt
```

## Test Output

### Success Indicators
- ✅ Green checkmark - Test passed
- ⏭️  Skipped - Component not installed
- ⚠️  Warning - Non-critical issue

### Failure Indicators
- ❌ Red X - Test failed
- Detailed error messages in logs

## Prerequisites

### All Tests
- `curl` - HTTP requests
- `jq` - JSON parsing

### EdgeX Tests
- Docker running
- EdgeX containers deployed
- Ports 8500, 59880-59882 accessible

### Proxmox Tests
- Proxmox VE installed
- Root or sudo access
- Ports 8006 accessible

### Kubernetes Tests
- kubectl installed and configured
- Cluster accessible

### Monitoring Tests
- Prometheus on port 9090
- Grafana on port 3000
- Node Exporter on port 9100

## Usage Examples

### Test After Deployment

```bash
# Deploy EdgeX
ansible-playbook -i inventory.ini odroid_h4/edgex/install_edgex_single.ansible

# Wait for services to start
sleep 30

# Run tests
cd tests
./test_edgex.sh

# Check API endpoints
./test_edgex_api.sh
```

### Continuous Monitoring

```bash
# Run tests every hour
*/60 * * * * /path/to/tests/run_all_tests.sh >> /var/log/picocluster-tests.log 2>&1
```

### Pre-Production Validation

```bash
# Full validation before go-live
./run_all_tests.sh

# Review results
cat test_results_*/SUMMARY.txt

# Check for any failures
grep -r "❌" test_results_*
```

## Troubleshooting

### Tests Fail with "Connection Refused"

**Issue**: Services not started or firewall blocking

**Solution**:
```bash
# Check service status
sudo systemctl status edgex
docker ps

# Check ports
sudo netstat -tlnp | grep -E '8500|59880|59881|59882'

# Check firewall
sudo ufw status
```

### jq Command Not Found

**Issue**: jq not installed

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# Raspbian
sudo apt install jq
```

### Permission Denied

**Issue**: Scripts not executable

**Solution**:
```bash
chmod +x *.sh
```

## Adding New Tests

Create a new test script:

```bash
#!/bin/bash
# test_myservice.sh

PASS=0
FAIL=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
        ((PASS++))
    else
        echo "❌ $2"
        ((FAIL++))
    fi
}

# Your tests here
test_result 0 "Service running"

# Report results
echo "Passed: $PASS, Failed: $FAIL"
exit $FAIL
```

Add to run_all_tests.sh:
```bash
if [ condition ]; then
    run_test "myservice" "./test_myservice.sh"
fi
```

## CI/CD Integration

### Jenkins

```groovy
stage('Test') {
    steps {
        sh 'cd tests && ./run_all_tests.sh'
    }
}
```

### GitHub Actions

```yaml
- name: Run Tests
  run: |
    cd tests
    chmod +x *.sh
    ./run_all_tests.sh
```

## Best Practices

1. **Run after deployment**: Validate immediately
2. **Test in isolation**: One service at a time
3. **Check logs**: Review detailed logs for failures
4. **Automate**: Use in CI/CD pipelines
5. **Update tests**: Keep in sync with deployments

## See Also

- [TESTING_GUIDE.md](../TESTING_GUIDE.md) - Comprehensive testing documentation
- [EDGEX_DEPLOYMENT_GUIDE.md](../EDGEX_DEPLOYMENT_GUIDE.md) - EdgeX deployment guide

---

**Last Updated**: 2025-11-11
**Test Scripts**: 6
**Coverage**: EdgeX, Proxmox, K8s, Monitoring
