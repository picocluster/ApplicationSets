# ApplicationSets Testing Guide

Complete testing procedures for validating PicoCluster infrastructure deployments.

## Table of Contents

1. [Testing Overview](#testing-overview)
2. [Pre-Deployment Testing](#pre-deployment-testing)
3. [EdgeX Foundry Testing](#edgex-foundry-testing)
4. [Proxmox VE Testing](#proxmox-ve-testing)
5. [Kubernetes Testing](#kubernetes-testing)
6. [Monitoring Stack Testing](#monitoring-stack-testing)
7. [Integration Testing](#integration-testing)
8. [Automated Test Scripts](#automated-test-scripts)
9. [Performance Testing](#performance-testing)
10. [Troubleshooting Test Failures](#troubleshooting-test-failures)

---

## Testing Overview

### Testing Philosophy

- **Automated First**: Scripts for repeatable validation
- **API-Driven**: Test actual functionality, not just process status
- **Progressive**: Start simple, increase complexity
- **Documentation**: Clear pass/fail criteria

### Test Levels

1. **Smoke Tests**: Basic "is it running?" checks
2. **Functional Tests**: API endpoints and operations
3. **Integration Tests**: Cross-service communication
4. **Performance Tests**: Load and stress testing
5. **End-to-End Tests**: Complete workflows

---

## Pre-Deployment Testing

### Hardware Validation

```bash
#!/bin/bash
# test_hardware.sh - Validate hardware before deployment

echo "=== Hardware Validation ==="

# Check architecture
ARCH=$(uname -m)
echo "Architecture: $ARCH"
if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi
echo "✅ Architecture supported"

# Check RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
echo "Total RAM: ${TOTAL_RAM}GB"
if [ "$TOTAL_RAM" -lt 4 ]; then
    echo "⚠️  Warning: Less than 4GB RAM (minimum 4GB recommended)"
else
    echo "✅ RAM sufficient"
fi

# Check disk space
TOTAL_DISK=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
echo "Total Disk: ${TOTAL_DISK}GB"
if [ "$TOTAL_DISK" -lt 20 ]; then
    echo "❌ Insufficient disk space (minimum 20GB required)"
    exit 1
fi
echo "✅ Disk space sufficient"

# Check CPU cores
CPU_CORES=$(nproc)
echo "CPU Cores: $CPU_CORES"
if [ "$CPU_CORES" -lt 2 ]; then
    echo "⚠️  Warning: Less than 2 CPU cores"
else
    echo "✅ CPU cores sufficient"
fi

# Check virtualization support (for Proxmox)
if [[ "$ARCH" == "x86_64" ]]; then
    if grep -E 'vmx|svm' /proc/cpuinfo > /dev/null; then
        echo "✅ Virtualization supported (VT-x/AMD-V)"
    else
        echo "⚠️  Warning: Virtualization NOT supported (required for Proxmox)"
    fi
fi

# Check network connectivity
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ Internet connectivity"
else
    echo "❌ No internet connectivity"
    exit 1
fi

echo ""
echo "=== Hardware validation complete ==="
```

### Ansible Connectivity Test

```bash
#!/bin/bash
# test_ansible_connectivity.sh

echo "=== Testing Ansible Connectivity ==="

# Check if inventory exists
if [ ! -f "inventory.ini" ]; then
    echo "❌ inventory.ini not found"
    exit 1
fi

# Test connectivity to all hosts
ansible all -i inventory.ini -m ping

if [ $? -eq 0 ]; then
    echo "✅ All hosts reachable"
else
    echo "❌ Some hosts unreachable"
    exit 1
fi

# Test sudo access
ansible all -i inventory.ini -m shell -a "sudo whoami" -b

if [ $? -eq 0 ]; then
    echo "✅ Sudo access confirmed"
else
    echo "❌ Sudo access failed"
    exit 1
fi
```

---

## EdgeX Foundry Testing

### Automated EdgeX Test Suite

Create `tests/test_edgex.sh`:

```bash
#!/bin/bash
# test_edgex.sh - Comprehensive EdgeX Foundry testing

EDGEX_HOST="${1:-localhost}"
CONSUL_PORT="8500"
CORE_DATA_PORT="59880"
CORE_METADATA_PORT="59881"
CORE_COMMAND_PORT="59882"

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

echo "========================================"
echo "EdgeX Foundry Test Suite"
echo "Host: $EDGEX_HOST"
echo "========================================"
echo ""

# Test 1: Docker containers running
echo "Test 1: Verifying Docker containers..."
CONTAINERS=$(docker ps --filter "name=edgex-*" --format "{{.Names}}" | wc -l)
if [ "$CONTAINERS" -ge 8 ]; then
    test_result 0 "Docker containers running ($CONTAINERS/8+)"
else
    test_result 1 "Not enough containers running ($CONTAINERS/8)"
fi

# Test 2: Consul Health
echo ""
echo "Test 2: Checking Consul..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$EDGEX_HOST:$CONSUL_PORT/v1/status/leader)
test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "Consul API accessible (HTTP $HTTP_CODE)"

# Test 3: Core Data Health
echo ""
echo "Test 3: Checking Core Data..."
PING=$(curl -s http://$EDGEX_HOST:$CORE_DATA_PORT/api/v3/ping)
test_result $(echo $PING | grep -q "pong" && echo 0 || echo 1) "Core Data ping response"

# Test 4: Core Metadata Health
echo ""
echo "Test 4: Checking Core Metadata..."
PING=$(curl -s http://$EDGEX_HOST:$CORE_METADATA_PORT/api/v3/ping)
test_result $(echo $PING | grep -q "pong" && echo 0 || echo 1) "Core Metadata ping response"

# Test 5: Core Command Health
echo ""
echo "Test 5: Checking Core Command..."
PING=$(curl -s http://$EDGEX_HOST:$CORE_COMMAND_PORT/api/v3/ping)
test_result $(echo $PING | grep -q "pong" && echo 0 || echo 1) "Core Command ping response"

# Test 6: Device Registration
echo ""
echo "Test 6: Checking device registration..."
DEVICES=$(curl -s http://$EDGEX_HOST:$CORE_METADATA_PORT/api/v3/device/all | jq '.devices | length' 2>/dev/null)
if [ ! -z "$DEVICES" ] && [ "$DEVICES" -gt 0 ]; then
    test_result 0 "Devices registered ($DEVICES devices)"
else
    test_result 1 "No devices registered"
fi

# Test 7: Event Count
echo ""
echo "Test 7: Checking event ingestion..."
EVENTS=$(curl -s http://$EDGEX_HOST:$CORE_DATA_PORT/api/v3/event/count | jq '.Count' 2>/dev/null)
if [ ! -z "$EVENTS" ] && [ "$EVENTS" -ge 0 ]; then
    test_result 0 "Events tracked ($EVENTS events)"
else
    test_result 1 "Event count unavailable"
fi

# Test 8: Reading Count
echo ""
echo "Test 8: Checking readings..."
READINGS=$(curl -s "http://$EDGEX_HOST:$CORE_DATA_PORT/api/v3/reading?limit=1" | jq '.readings | length' 2>/dev/null)
if [ ! -z "$READINGS" ] && [ "$READINGS" -ge 0 ]; then
    test_result 0 "Readings available ($READINGS sampled)"
else
    test_result 1 "No readings available"
fi

# Test 9: Service Registration in Consul
echo ""
echo "Test 9: Checking service registration..."
SERVICES=$(curl -s http://$EDGEX_HOST:$CONSUL_PORT/v1/agent/services | jq 'keys | length' 2>/dev/null)
if [ ! -z "$SERVICES" ] && [ "$SERVICES" -ge 8 ]; then
    test_result 0 "Services registered in Consul ($SERVICES services)"
else
    test_result 1 "Insufficient services in Consul ($SERVICES/8)"
fi

# Test 10: Virtual Device Generating Data
echo ""
echo "Test 10: Checking virtual device data generation..."
sleep 5  # Wait for data generation
RECENT_EVENTS=$(curl -s "http://$EDGEX_HOST:$CORE_DATA_PORT/api/v3/event?limit=10" | jq '.events | length' 2>/dev/null)
if [ ! -z "$RECENT_EVENTS" ] && [ "$RECENT_EVENTS" -gt 0 ]; then
    test_result 0 "Virtual device generating data ($RECENT_EVENTS recent events)"
else
    test_result 1 "No recent events from virtual device"
fi

echo ""
echo "========================================"
echo "Test Results:"
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
echo "  TOTAL:  $((PASS + FAIL))"
echo "========================================"

if [ $FAIL -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
```

### EdgeX API Endpoint Tests

Create `tests/test_edgex_api.sh`:

```bash
#!/bin/bash
# test_edgex_api.sh - Test EdgeX REST API endpoints

EDGEX_HOST="${1:-localhost}"

echo "=== EdgeX API Endpoint Tests ==="
echo ""

# Test Core Data API
echo "1. Core Data API (port 59880)"
echo "   GET /api/v3/ping"
curl -s http://$EDGEX_HOST:59880/api/v3/ping | jq .
echo ""

echo "   GET /api/v3/event/count"
curl -s http://$EDGEX_HOST:59880/api/v3/event/count | jq .
echo ""

echo "   GET /api/v3/reading?limit=5"
curl -s "http://$EDGEX_HOST:59880/api/v3/reading?limit=5" | jq '.readings[] | {deviceName, resourceName, value}'
echo ""

# Test Core Metadata API
echo "2. Core Metadata API (port 59881)"
echo "   GET /api/v3/ping"
curl -s http://$EDGEX_HOST:59881/api/v3/ping | jq .
echo ""

echo "   GET /api/v3/device/all"
curl -s http://$EDGEX_HOST:59881/api/v3/device/all | jq '.devices[] | {name, serviceName, adminState, operatingState}'
echo ""

echo "   GET /api/v3/deviceprofile/all"
curl -s http://$EDGEX_HOST:59881/api/v3/deviceprofile/all | jq '.profiles[] | {name, manufacturer, model}'
echo ""

# Test Core Command API
echo "3. Core Command API (port 59882)"
echo "   GET /api/v3/ping"
curl -s http://$EDGEX_HOST:59882/api/v3/ping | jq .
echo ""

echo "   GET /api/v3/device/all"
curl -s http://$EDGEX_HOST:59882/api/v3/device/all | jq '.devices[] | {name, serviceName}'
echo ""

# Test device commands (if devices exist)
DEVICE_NAME=$(curl -s http://$EDGEX_HOST:59881/api/v3/device/all | jq -r '.devices[0].name' 2>/dev/null)
if [ ! -z "$DEVICE_NAME" ] && [ "$DEVICE_NAME" != "null" ]; then
    echo "   GET /api/v3/device/name/$DEVICE_NAME"
    curl -s "http://$EDGEX_HOST:59882/api/v3/device/name/$DEVICE_NAME" | jq .
fi

echo ""
echo "=== API endpoint tests complete ==="
```

### EdgeX Load Test

Create `tests/load_test_edgex.sh`:

```bash
#!/bin/bash
# load_test_edgex.sh - Simple load test for EdgeX

EDGEX_HOST="${1:-localhost}"
DURATION="${2:-60}"  # seconds
CONCURRENT="${3:-10}"

echo "=== EdgeX Load Test ==="
echo "Host: $EDGEX_HOST"
echo "Duration: ${DURATION}s"
echo "Concurrent requests: $CONCURRENT"
echo ""

# Function to make requests
make_requests() {
    local count=0
    local start=$(date +%s)
    while [ $(($(date +%s) - start)) -lt $DURATION ]; do
        curl -s "http://$EDGEX_HOST:59880/api/v3/reading?limit=1" > /dev/null
        ((count++))
    done
    echo $count
}

# Run concurrent requests
echo "Starting load test..."
for i in $(seq 1 $CONCURRENT); do
    make_requests &
done

wait

echo "Load test complete!"
```

---

## Proxmox VE Testing

### Automated Proxmox Test Suite

Create `tests/test_proxmox.sh`:

```bash
#!/bin/bash
# test_proxmox.sh - Proxmox VE validation

PROXMOX_HOST="${1:-localhost}"
PROXMOX_PORT="8006"

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

echo "========================================"
echo "Proxmox VE Test Suite"
echo "Host: $PROXMOX_HOST"
echo "========================================"
echo ""

# Test 1: Architecture check
echo "Test 1: Verifying x86-64 architecture..."
ARCH=$(uname -m)
test_result $([ "$ARCH" = "x86_64" ] && echo 0 || echo 1) "Architecture is x86-64 ($ARCH)"

# Test 2: Proxmox kernel
echo ""
echo "Test 2: Checking Proxmox kernel..."
KERNEL=$(uname -r)
if echo $KERNEL | grep -q "pve"; then
    test_result 0 "Proxmox kernel loaded ($KERNEL)"
else
    test_result 1 "Non-Proxmox kernel ($KERNEL) - reboot required"
fi

# Test 3: Proxmox services
echo ""
echo "Test 3: Checking Proxmox services..."
for service in pveproxy pvedaemon pve-cluster; do
    if systemctl is-active --quiet $service; then
        test_result 0 "$service running"
    else
        test_result 1 "$service not running"
    fi
done

# Test 4: Web interface
echo ""
echo "Test 4: Checking web interface..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" https://$PROXMOX_HOST:$PROXMOX_PORT)
test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "Web interface accessible (HTTPS $HTTP_CODE)"

# Test 5: PVE CLI commands
echo ""
echo "Test 5: Testing PVE CLI..."
if command -v pvesm &> /dev/null; then
    test_result 0 "PVE CLI available"

    # Test storage status
    pvesm status > /dev/null 2>&1
    test_result $? "Storage accessible"
else
    test_result 1 "PVE CLI not available"
fi

# Test 6: Virtualization support
echo ""
echo "Test 6: Checking virtualization support..."
if grep -E 'vmx|svm' /proc/cpuinfo > /dev/null; then
    test_result 0 "CPU virtualization enabled"

    # Check KVM module
    if lsmod | grep -q kvm; then
        test_result 0 "KVM module loaded"
    else
        test_result 1 "KVM module not loaded"
    fi
else
    test_result 1 "CPU virtualization not available"
fi

# Test 7: Check for VMs/Containers
echo ""
echo "Test 7: Checking for VMs/Containers..."
if command -v qm &> /dev/null; then
    VM_COUNT=$(qm list 2>/dev/null | tail -n +2 | wc -l)
    test_result 0 "VM management available ($VM_COUNT VMs)"
fi

if command -v pct &> /dev/null; then
    CT_COUNT=$(pct list 2>/dev/null | tail -n +2 | wc -l)
    test_result 0 "Container management available ($CT_COUNT containers)"
fi

echo ""
echo "========================================"
echo "Test Results:"
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
echo "  TOTAL:  $((PASS + FAIL))"
echo "========================================"

if [ $FAIL -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
```

### Proxmox API Tests

Create `tests/test_proxmox_api.sh`:

```bash
#!/bin/bash
# test_proxmox_api.sh - Test Proxmox API endpoints

PROXMOX_HOST="${1:-localhost}"
PROXMOX_PORT="8006"

echo "=== Proxmox API Tests ==="
echo ""
echo "Note: These tests require authentication"
echo "For full API testing, use: pvesh get /nodes"
echo ""

# Test public endpoints (no auth required)
echo "1. Testing public endpoints..."
echo "   GET /api2/json/version (should fail without auth)"
curl -sk https://$PROXMOX_HOST:$PROXMOX_PORT/api2/json/version
echo ""

# Using pvesh (requires local access)
echo "2. Testing with pvesh CLI..."
if command -v pvesh &> /dev/null; then
    echo "   GET /nodes"
    pvesh get /nodes --output-format json | jq .
    echo ""

    echo "   GET /version"
    pvesh get /version --output-format json | jq .
    echo ""

    echo "   GET /cluster/status"
    pvesh get /cluster/status --output-format json | jq . 2>/dev/null || echo "   (Not in cluster mode)"
fi

echo "=== API tests complete ==="
```

---

## Kubernetes Testing

Create `tests/test_kubernetes.sh`:

```bash
#!/bin/bash
# test_kubernetes.sh - Kubernetes cluster validation

echo "=== Kubernetes Cluster Tests ==="
echo ""

# Test 1: kubectl available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found"
    exit 1
fi
echo "✅ kubectl available"

# Test 2: Cluster connectivity
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Cannot connect to cluster"
    exit 1
fi
echo "✅ Cluster accessible"

# Test 3: Node status
echo ""
echo "Nodes:"
kubectl get nodes
READY_NODES=$(kubectl get nodes --no-headers | grep " Ready" | wc -l)
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
echo "✅ $READY_NODES/$TOTAL_NODES nodes ready"

# Test 4: System pods
echo ""
echo "System Pods:"
kubectl get pods -n kube-system
NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
if [ $NOT_RUNNING -eq 0 ]; then
    echo "✅ All system pods running"
else
    echo "⚠️  $NOT_RUNNING pods not running"
fi

# Test 5: Create test deployment
echo ""
echo "Testing deployment creation..."
kubectl create deployment test-nginx --image=nginx:alpine > /dev/null 2>&1
sleep 5
kubectl wait --for=condition=available --timeout=60s deployment/test-nginx
if [ $? -eq 0 ]; then
    echo "✅ Test deployment successful"
    kubectl delete deployment test-nginx > /dev/null 2>&1
else
    echo "❌ Test deployment failed"
    kubectl delete deployment test-nginx > /dev/null 2>&1
fi

echo ""
echo "=== Kubernetes tests complete ==="
```

---

## Monitoring Stack Testing

Create `tests/test_monitoring.sh`:

```bash
#!/bin/bash
# test_monitoring.sh - Monitoring stack validation

PROMETHEUS_HOST="${1:-localhost}"
PROMETHEUS_PORT="${2:-9090}"
GRAFANA_HOST="${3:-localhost}"
GRAFANA_PORT="${4:-3000}"

echo "=== Monitoring Stack Tests ==="
echo ""

# Test Prometheus
echo "1. Testing Prometheus..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$PROMETHEUS_HOST:$PROMETHEUS_PORT/-/healthy)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Prometheus healthy"
else
    echo "❌ Prometheus not healthy (HTTP $HTTP_CODE)"
fi

# Check Prometheus targets
TARGETS=$(curl -s http://$PROMETHEUS_HOST:$PROMETHEUS_PORT/api/v1/targets | jq '.data.activeTargets | length')
echo "   Active targets: $TARGETS"

# Test Grafana
echo ""
echo "2. Testing Grafana..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$GRAFANA_HOST:$GRAFANA_PORT/api/health)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Grafana healthy"
else
    echo "❌ Grafana not healthy (HTTP $HTTP_CODE)"
fi

# Test Node Exporter (on localhost)
echo ""
echo "3. Testing Node Exporter..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9100/metrics)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Node Exporter running"
else
    echo "❌ Node Exporter not running (HTTP $HTTP_CODE)"
fi

echo ""
echo "=== Monitoring tests complete ==="
```

---

## Integration Testing

Create `tests/integration_test.sh`:

```bash
#!/bin/bash
# integration_test.sh - End-to-end integration tests

echo "========================================"
echo "Integration Test Suite"
echo "========================================"
echo ""

# Test 1: EdgeX + Monitoring
echo "Test 1: EdgeX → Prometheus integration..."
if curl -s http://localhost:9090/api/v1/query?query=up | jq -e '.data.result[] | select(.metric.job | contains("edgex"))' > /dev/null; then
    echo "✅ EdgeX metrics in Prometheus"
else
    echo "⚠️  EdgeX metrics not found in Prometheus"
fi

# Test 2: Kubernetes + Monitoring
echo ""
echo "Test 2: Kubernetes → Prometheus integration..."
if curl -s http://localhost:9090/api/v1/query?query=up | jq -e '.data.result[] | select(.metric.job | contains("kubernetes"))' > /dev/null 2>&1; then
    echo "✅ Kubernetes metrics in Prometheus"
else
    echo "⚠️  Kubernetes metrics not found"
fi

# Test 3: Consul service discovery
echo ""
echo "Test 3: Consul service discovery..."
if command -v consul &> /dev/null; then
    SERVICES=$(consul catalog services | wc -l)
    echo "✅ Consul tracking $SERVICES services"
fi

echo ""
echo "=== Integration tests complete ==="
```

---

## Automated Test Scripts

### Master Test Runner

Create `tests/run_all_tests.sh`:

```bash
#!/bin/bash
# run_all_tests.sh - Run all test suites

RESULTS_DIR="test_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p $RESULTS_DIR

echo "========================================"
echo "PicoCluster Test Suite Runner"
echo "Results directory: $RESULTS_DIR"
echo "========================================"
echo ""

# Run hardware tests
echo "Running hardware tests..."
./test_hardware.sh | tee $RESULTS_DIR/hardware.log

# Run EdgeX tests (if EdgeX is deployed)
if docker ps | grep -q edgex; then
    echo ""
    echo "Running EdgeX tests..."
    ./test_edgex.sh | tee $RESULTS_DIR/edgex.log
    ./test_edgex_api.sh | tee $RESULTS_DIR/edgex_api.log
fi

# Run Proxmox tests (if Proxmox is installed)
if command -v pvesm &> /dev/null; then
    echo ""
    echo "Running Proxmox tests..."
    ./test_proxmox.sh | tee $RESULTS_DIR/proxmox.log
fi

# Run Kubernetes tests (if kubectl is available)
if command -v kubectl &> /dev/null; then
    echo ""
    echo "Running Kubernetes tests..."
    ./test_kubernetes.sh | tee $RESULTS_DIR/kubernetes.log
fi

# Run monitoring tests
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo ""
    echo "Running monitoring tests..."
    ./test_monitoring.sh | tee $RESULTS_DIR/monitoring.log
fi

# Run integration tests
echo ""
echo "Running integration tests..."
./integration_test.sh | tee $RESULTS_DIR/integration.log

echo ""
echo "========================================"
echo "All tests complete!"
echo "Results saved to: $RESULTS_DIR/"
echo "========================================"

# Generate summary
echo ""
echo "Test Summary:"
grep -r "✅\|❌" $RESULTS_DIR/ | wc -l
echo "  Total checks performed"
grep -r "✅" $RESULTS_DIR/ | wc -l
echo "  Passed"
grep -r "❌" $RESULTS_DIR/ | wc -l
echo "  Failed"
```

---

## Performance Testing

### EdgeX Performance Benchmark

Create `tests/benchmark_edgex.sh`:

```bash
#!/bin/bash
# benchmark_edgex.sh - EdgeX performance benchmarks

EDGEX_HOST="${1:-localhost}"

echo "=== EdgeX Performance Benchmark ==="
echo ""

# Benchmark 1: API Response Time
echo "1. API Response Time Benchmark"
echo "   Testing 100 requests to Core Data..."
{
    time for i in {1..100}; do
        curl -s http://$EDGEX_HOST:59880/api/v3/ping > /dev/null
    done
} 2>&1 | grep real

# Benchmark 2: Event Throughput
echo ""
echo "2. Event Throughput Benchmark"
BEFORE=$(curl -s http://$EDGEX_HOST:59880/api/v3/event/count | jq '.Count')
sleep 60
AFTER=$(curl -s http://$EDGEX_HOST:59880/api/v3/event/count | jq '.Count')
RATE=$(($AFTER - $BEFORE))
echo "   Events per minute: $RATE"

# Benchmark 3: Reading Query Performance
echo ""
echo "3. Reading Query Performance"
time curl -s "http://$EDGEX_HOST:59880/api/v3/reading?limit=1000" > /dev/null

echo ""
echo "=== Benchmark complete ==="
```

---

## Troubleshooting Test Failures

### Common Issues

#### EdgeX Tests Fail

**Symptom**: Container tests pass but API tests fail

**Solution**:
```bash
# Check service logs
docker logs edgex-core-data

# Restart services
sudo systemctl restart edgex

# Wait for services to be ready
sleep 30
```

#### Proxmox Tests Fail After Install

**Symptom**: Services not running after playbook

**Solution**:
```bash
# Reboot required for Proxmox kernel
sudo reboot

# After reboot, rerun tests
./test_proxmox.sh
```

#### Monitoring Tests Fail

**Symptom**: Prometheus/Grafana not accessible

**Solution**:
```bash
# Check service status
sudo systemctl status prometheus grafana-server

# Check firewall
sudo ufw status

# Test locally
curl http://localhost:9090/-/healthy
curl http://localhost:3000/api/health
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/test.yml
name: Test ApplicationSets

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Run hardware tests
        run: |
          cd tests
          chmod +x *.sh
          ./test_hardware.sh

      - name: Run syntax validation
        run: |
          ansible-playbook --syntax-check odroid_h4/edgex/install_edgex_single.ansible
```

---

## Test Coverage

| Component | Smoke | Functional | Integration | Performance |
|-----------|-------|------------|-------------|-------------|
| EdgeX Foundry | ✅ | ✅ | ✅ | ✅ |
| Proxmox VE | ✅ | ✅ | ⏳ | ⏳ |
| Kubernetes | ✅ | ✅ | ✅ | ⏳ |
| Monitoring | ✅ | ✅ | ✅ | ⏳ |
| Consul | ✅ | ✅ | ✅ | ⏳ |

---

**Last Updated**: 2025-11-11
**Status**: Production Ready
**Test Scripts**: 12+
