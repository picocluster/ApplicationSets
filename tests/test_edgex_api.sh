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
