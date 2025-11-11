#!/bin/bash
# test_monitoring.sh - Monitoring stack validation

PROMETHEUS_HOST="${1:-localhost}"
PROMETHEUS_PORT="${2:-9090}"
GRAFANA_HOST="${3:-localhost}"
GRAFANA_PORT="${4:-3000}"

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
echo "Monitoring Stack Test Suite"
echo "Prometheus: $PROMETHEUS_HOST:$PROMETHEUS_PORT"
echo "Grafana: $GRAFANA_HOST:$GRAFANA_PORT"
echo "========================================"
echo ""

# Test 1: Prometheus Health
echo "Test 1: Checking Prometheus..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$PROMETHEUS_HOST:$PROMETHEUS_PORT/-/healthy)
test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "Prometheus health endpoint (HTTP $HTTP_CODE)"

# Test 2: Prometheus Targets
echo ""
echo "Test 2: Checking Prometheus targets..."
TARGETS=$(curl -s http://$PROMETHEUS_HOST:$PROMETHEUS_PORT/api/v1/targets | jq '.data.activeTargets | length' 2>/dev/null)
if [ ! -z "$TARGETS" ] && [ "$TARGETS" -gt 0 ]; then
    test_result 0 "Active targets found ($TARGETS targets)"
else
    test_result 1 "No active targets"
fi

# Test 3: Prometheus Scraping
echo ""
echo "Test 3: Checking metrics scraping..."
UP_COUNT=$(curl -s "http://$PROMETHEUS_HOST:$PROMETHEUS_PORT/api/v1/query?query=up" | jq '.data.result | length' 2>/dev/null)
if [ ! -z "$UP_COUNT" ] && [ "$UP_COUNT" -gt 0 ]; then
    test_result 0 "Metrics being scraped ($UP_COUNT instances)"
else
    test_result 1 "No metrics found"
fi

# Test 4: Grafana Health
echo ""
echo "Test 4: Checking Grafana..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$GRAFANA_HOST:$GRAFANA_PORT/api/health)
test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "Grafana health endpoint (HTTP $HTTP_CODE)"

# Test 5: Grafana Datasources
echo ""
echo "Test 5: Checking Grafana datasources..."
# Note: This requires authentication, will return 401 but that's expected
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$GRAFANA_HOST:$GRAFANA_PORT/api/datasources)
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
    test_result 0 "Grafana API accessible (HTTP $HTTP_CODE)"
else
    test_result 1 "Grafana API error (HTTP $HTTP_CODE)"
fi

# Test 6: Node Exporter
echo ""
echo "Test 6: Checking Node Exporter..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9100/metrics)
test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "Node Exporter metrics (HTTP $HTTP_CODE)"

# Test 7: Prometheus Rules
echo ""
echo "Test 7: Checking Prometheus rules..."
RULES=$(curl -s http://$PROMETHEUS_HOST:$PROMETHEUS_PORT/api/v1/rules | jq '.data.groups | length' 2>/dev/null)
if [ ! -z "$RULES" ]; then
    test_result 0 "Prometheus rules loaded ($RULES rule groups)"
else
    test_result 1 "No rules loaded"
fi

# Test 8: Alertmanager (if available)
echo ""
echo "Test 8: Checking Alertmanager..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    test_result 0 "Alertmanager running (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "⏭️  Alertmanager not deployed (optional)"
else
    test_result 1 "Alertmanager error (HTTP $HTTP_CODE)"
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
