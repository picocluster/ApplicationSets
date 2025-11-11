#!/bin/bash
# run_all_tests.sh - Run all test suites

RESULTS_DIR="test_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p $RESULTS_DIR

echo "========================================"
echo "PicoCluster Test Suite Runner"
echo "Results directory: $RESULTS_DIR"
echo "========================================"
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0

# Function to run a test and capture results
run_test() {
    local test_name=$1
    local test_script=$2

    echo "Running $test_name..."
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        "$test_script" | tee "$RESULTS_DIR/${test_name}.log"

        # Count pass/fail
        PASSED=$(grep -c "✅" "$RESULTS_DIR/${test_name}.log" || echo 0)
        FAILED=$(grep -c "❌" "$RESULTS_DIR/${test_name}.log" || echo 0)

        TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
        TOTAL_FAILED=$((TOTAL_FAILED + FAILED))

        echo "  Passed: $PASSED, Failed: $FAILED"
    else
        echo "  ⚠️  Test script not found: $test_script"
    fi
    echo ""
}

# Run EdgeX tests (if EdgeX is deployed)
if docker ps 2>/dev/null | grep -q edgex; then
    run_test "edgex" "./test_edgex.sh"
    run_test "edgex_api" "./test_edgex_api.sh"
else
    echo "⏭️  Skipping EdgeX tests (not deployed)"
fi

# Run Proxmox tests (if Proxmox is installed)
if command -v pvesm &> /dev/null; then
    run_test "proxmox" "./test_proxmox.sh"
else
    echo "⏭️  Skipping Proxmox tests (not installed)"
fi

# Run Kubernetes tests (if kubectl is available)
if command -v kubectl &> /dev/null; then
    run_test "kubernetes" "./test_kubernetes.sh"
else
    echo "⏭️  Skipping Kubernetes tests (not available)"
fi

# Run monitoring tests
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    run_test "monitoring" "./test_monitoring.sh"
else
    echo "⏭️  Skipping monitoring tests (not available)"
fi

# Generate summary report
cat > "$RESULTS_DIR/SUMMARY.txt" <<EOF
======================================
PicoCluster Test Suite Summary
======================================

Test Run: $(date)
Results Directory: $RESULTS_DIR

Total Checks: $((TOTAL_PASSED + TOTAL_FAILED))
Passed: $TOTAL_PASSED
Failed: $TOTAL_FAILED

Pass Rate: $(echo "scale=2; $TOTAL_PASSED * 100 / ($TOTAL_PASSED + $TOTAL_FAILED)" | bc)%

======================================
EOF

cat "$RESULTS_DIR/SUMMARY.txt"

echo ""
echo "Detailed results saved to: $RESULTS_DIR/"
echo ""

# Exit with appropriate code
if [ $TOTAL_FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed - check logs in $RESULTS_DIR/"
    exit 1
fi
