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
