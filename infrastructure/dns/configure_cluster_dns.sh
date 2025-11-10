#!/bin/bash

################################################################################
# Configure PicoCluster Nodes to Use CoreDNS
#
# This script configures all cluster nodes to use CoreDNS as their primary DNS
# resolver, enabling service discovery and internal DNS resolution.
#
# Usage:
#   sudo ./configure_cluster_dns.sh <dns-server-ip> [domain]
#
#   ./configure_cluster_dns.sh 10.1.10.245
#   ./configure_cluster_dns.sh 10.1.10.245 cluster.local
#
# Prerequisites:
#   - CoreDNS installed on specified server
#   - Root/sudo access
#   - NetworkManager or systemd-resolved
#
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DNS_SERVER="${1:-}"
CLUSTER_DOMAIN="${2:-cluster.local}"
BACKUP_DIR="/etc/resolv.conf.backup.$(date +%s)"

# Functions
print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 <dns-server-ip> [cluster-domain]

Arguments:
    dns-server-ip       IP address of CoreDNS server (required)
    cluster-domain      Cluster domain name (default: cluster.local)

Examples:
    sudo $0 10.1.10.245
    sudo $0 10.1.10.245 cluster.local
    sudo $0 10.1.10.245 mylab.local

This script will:
1. Check if CoreDNS server is reachable
2. Backup current DNS configuration
3. Update DNS resolver configuration
4. Verify DNS resolution works
5. Configure persistent DNS settings

EOF
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

# Validate input
if [[ -z "$DNS_SERVER" ]]; then
    print_error "DNS server IP address is required"
    usage
    exit 1
fi

# Validate IP address format
if ! [[ "$DNS_SERVER" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP address format: $DNS_SERVER"
    exit 1
fi

print_header "PicoCluster DNS Configuration"
echo ""
echo "Configuration:"
echo "  DNS Server: $DNS_SERVER"
echo "  Cluster Domain: $CLUSTER_DOMAIN"
echo ""

# Step 1: Test DNS server connectivity
print_info "Testing DNS server connectivity..."
if timeout 3 bash -c "echo >/dev/tcp/$DNS_SERVER/53" 2>/dev/null; then
    print_ok "DNS server is reachable on TCP:53"
elif timeout 3 bash -c "echo >/dev/udp/$DNS_SERVER/53" 2>/dev/null; then
    print_ok "DNS server is reachable on UDP:53"
else
    print_error "Cannot reach DNS server at $DNS_SERVER:53"
    echo "  Make sure CoreDNS is running on $DNS_SERVER"
    exit 1
fi

# Step 2: Detect network management system
print_info "Detecting network management system..."

if command -v nmcli &> /dev/null && systemctl is-active NetworkManager &> /dev/null; then
    print_ok "NetworkManager detected"
    USE_NETWORKMANAGER=true
elif command -v systemctl &> /dev/null && systemctl is-active systemd-resolved &> /dev/null; then
    print_ok "systemd-resolved detected"
    USE_SYSTEMD_RESOLVED=true
else
    print_ok "Using static resolv.conf configuration"
    USE_RESOLV_CONF=true
fi

# Step 3: Backup current configuration
print_info "Backing up current DNS configuration..."
mkdir -p "$BACKUP_DIR"

if [[ -f /etc/resolv.conf ]]; then
    cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf"
    print_ok "Backed up /etc/resolv.conf"
fi

if [[ -f /etc/NetworkManager/conf.d/dns.conf ]]; then
    cp /etc/NetworkManager/conf.d/dns.conf "$BACKUP_DIR/nm-dns.conf"
    print_ok "Backed up NetworkManager DNS config"
fi

print_info "Backup location: $BACKUP_DIR"

# Step 4: Configure DNS
print_info "Configuring DNS resolver..."

if [[ "$USE_NETWORKMANAGER" == "true" ]]; then
    # Get active connection
    ACTIVE_CONN=$(nmcli -t -f NAME c show --active | head -1)

    if [[ -n "$ACTIVE_CONN" ]]; then
        print_info "Updating NetworkManager connection: $ACTIVE_CONN"

        # Update DNS servers
        nmcli connection modify "$ACTIVE_CONN" \
            ipv4.dns "$DNS_SERVER" \
            ipv4.dns-search "$CLUSTER_DOMAIN" \
            ipv4.dhcp-send-hostname yes

        # Apply changes
        nmcli connection up "$ACTIVE_CONN"

        print_ok "NetworkManager DNS updated"
    else
        print_error "No active NetworkManager connection found"
        exit 1
    fi

elif [[ "$USE_SYSTEMD_RESOLVED" == "true" ]]; then
    # Create systemd-resolved config
    mkdir -p /etc/systemd/resolved.conf.d

    cat > /etc/systemd/resolved.conf.d/picocluster.conf << EOF
[Resolve]
DNS=$DNS_SERVER
FallbackDNS=8.8.8.8 8.8.4.4
Domains=$CLUSTER_DOMAIN ~.
DNSSECNegativeTrustAnchors=cluster.local
EOF

    print_ok "Created systemd-resolved configuration"

    # Restart systemd-resolved
    systemctl restart systemd-resolved

    print_ok "systemd-resolved restarted"

else
    # Manual resolv.conf configuration
    # Create new resolv.conf
    cat > /etc/resolv.conf << EOF
# PicoCluster DNS Configuration
# Generated: $(date)
# DO NOT EDIT MANUALLY - This file will be overwritten

nameserver $DNS_SERVER
search $CLUSTER_DOMAIN
options ndots:2 timeout:2 attempts:3
EOF

    print_ok "Updated /etc/resolv.conf"

    # Make resolv.conf immutable if using dhcp
    if systemctl is-active dhclient &> /dev/null; then
        chattr +i /etc/resolv.conf
        print_ok "Made /etc/resolv.conf immutable"
    fi
fi

# Step 5: Verify DNS resolution
print_info "Verifying DNS resolution..."
sleep 2

# Test 1: Resolve cluster domain
if nslookup cluster.local $DNS_SERVER &> /dev/null; then
    print_ok "Successfully resolved cluster.local"
else
    print_error "Failed to resolve cluster.local"
    echo "  Make sure CoreDNS is running and configured"
fi

# Test 2: Resolve a service
if nslookup monitoring.$CLUSTER_DOMAIN $DNS_SERVER &> /dev/null 2>&1; then
    print_ok "Successfully resolved monitoring.$CLUSTER_DOMAIN"
else
    print_info "monitoring.$CLUSTER_DOMAIN not yet registered (expected on initial setup)"
fi

# Test 3: Test upstream DNS resolution
if nslookup google.com $DNS_SERVER &> /dev/null; then
    print_ok "Upstream DNS resolution working"
else
    print_error "Upstream DNS resolution failed"
fi

# Step 6: Display summary
echo ""
print_header "DNS Configuration Complete"

echo ""
echo "Configuration Summary:"
echo "  DNS Server: $DNS_SERVER"
echo "  Cluster Domain: $CLUSTER_DOMAIN"
echo "  Configuration Method: $([ "$USE_NETWORKMANAGER" = "true" ] && echo "NetworkManager" || [ "$USE_SYSTEMD_RESOLVED" = "true" ] && echo "systemd-resolved" || echo "resolv.conf")"
echo ""

echo "Testing DNS:"
echo "  nslookup cluster.local"
echo "  nslookup monitoring.$CLUSTER_DOMAIN"
echo "  dig @$DNS_SERVER monitoring.$CLUSTER_DOMAIN"
echo ""

echo "Backup Location:"
echo "  $BACKUP_DIR"
echo ""

if [[ "$USE_NETWORKMANAGER" == "true" ]]; then
    echo "To revert changes (if needed):"
    echo "  nmcli connection modify $ACTIVE_CONN -ipv4.dns"
    echo "  nmcli connection up $ACTIVE_CONN"
elif [[ "$USE_SYSTEMD_RESOLVED" == "true" ]]; then
    echo "To revert changes (if needed):"
    echo "  rm /etc/systemd/resolved.conf.d/picocluster.conf"
    echo "  systemctl restart systemd-resolved"
else
    echo "To revert changes (if needed):"
    echo "  chattr -i /etc/resolv.conf  (if immutable)"
    echo "  cp $BACKUP_DIR/resolv.conf /etc/resolv.conf"
fi

echo ""
print_ok "DNS configuration complete!"

exit 0
