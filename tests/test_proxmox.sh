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
