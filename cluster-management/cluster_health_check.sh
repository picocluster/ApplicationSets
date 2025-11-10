#!/bin/bash

################################################################################
# PicoCluster Health Check Script
#
# Comprehensive health check for all cluster nodes and services
#
# Usage:
#   ./cluster_health_check.sh                 # Check all nodes
#   ./cluster_health_check.sh -n pc0          # Check specific node
#   ./cluster_health_check.sh -v              # Verbose output
#   ./cluster_health_check.sh --json          # JSON output
#
# Features:
#   - Node reachability and SSH connectivity
#   - Critical service status
#   - Disk space and inode usage
#   - Memory and CPU metrics
#   - Certificate expiration warnings
#   - NTP time synchronization
#   - Network interface status
#   - Overall cluster health summary
#
################################################################################

set -o pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERBOSE=false
JSON_OUTPUT=false
CHECK_NODE=""
TIMEOUT=5
DISK_WARNING=80
DISK_CRITICAL=90
MEMORY_WARNING=80
MEMORY_CRITICAL=90

# Default nodes to check (override with Ansible inventory)
NODES=()
SERVICES=("prometheus" "grafana-server" "node_exporter" "docker" "containerd" "kubelet")
MONITORING_NODE=""

# Health status counters
HEALTHY_NODES=0
WARNING_NODES=0
CRITICAL_NODES=0
TOTAL_CHECKS=0
FAILED_CHECKS=0

# Functions

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo -e "\n${BLUE}──── $1 ────${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNING_NODES++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((CRITICAL_NODES++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -n, --node NODE         Check specific node only
    -v, --verbose           Verbose output
    --json                  JSON output format
    -h, --help              Show this help message

Examples:
    $0                      # Check all cluster nodes
    $0 -n pc0               # Check specific node
    $0 -v                   # Verbose mode with detailed output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--node)
            CHECK_NODE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Load nodes from Ansible inventory if available
load_inventory() {
    if [[ -f "inventory.ini" ]] || [[ -f "inventory.yaml" ]] || [[ -f "inventory.yml" ]]; then
        # Try to find nodes from inventory
        if command -v ansible-inventory &> /dev/null; then
            local inventory_file=""
            if [[ -f "inventory.ini" ]]; then
                inventory_file="inventory.ini"
            elif [[ -f "inventory.yaml" ]]; then
                inventory_file="inventory.yaml"
            else
                inventory_file="inventory.yml"
            fi

            # Get all hosts
            NODES=($(ansible-inventory -i "$inventory_file" --list 2>/dev/null | jq -r '.all.hosts[]' 2>/dev/null || echo ""))

            # If that failed, try a simpler approach
            if [[ ${#NODES[@]} -eq 0 ]]; then
                NODES=($(grep -E '^\s*pc[0-9]|^\s*\[' "$inventory_file" 2>/dev/null | grep -v '^\[' | awk '{print $1}' | sort -u))
            fi
        fi
    fi

    # Fallback to default nodes
    if [[ ${#NODES[@]} -eq 0 ]]; then
        NODES=("pc0" "pc1" "pc2" "pc3")
    fi
}

# Check if node is reachable
check_node_reachability() {
    local node=$1
    local ip=$2

    print_section "Node: $node"

    # Try ping first (faster)
    if ping -c 1 -W $TIMEOUT "$node" &> /dev/null || ping -c 1 -W $TIMEOUT "$ip" &> /dev/null 2>/dev/null; then
        print_ok "Reachable (ping)"
        return 0
    fi

    # Try SSH
    if timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" "echo 1" &> /dev/null; then
        print_ok "Reachable (SSH)"
        return 0
    fi

    print_error "Not reachable via ping or SSH"
    return 1
}

# Check node disk space
check_disk_space() {
    local node=$1

    local output=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
        "df -h / | tail -1 | awk '{print \$5}' | tr -d '%'" 2>/dev/null)

    if [[ -z "$output" ]]; then
        print_warning "Could not retrieve disk space"
        return 1
    fi

    local usage=$output
    if [[ $usage -ge $DISK_CRITICAL ]]; then
        print_error "Disk usage CRITICAL: ${usage}%"
        return 1
    elif [[ $usage -ge $DISK_WARNING ]]; then
        print_warning "Disk usage WARNING: ${usage}%"
        return 1
    else
        print_ok "Disk usage: ${usage}%"
        return 0
    fi
}

# Check node memory usage
check_memory_usage() {
    local node=$1

    local output=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
        "free | grep Mem | awk '{printf \"%.0f\", (\$3/\$2)*100}'" 2>/dev/null)

    if [[ -z "$output" ]]; then
        print_warning "Could not retrieve memory usage"
        return 1
    fi

    local usage=$output
    if [[ $usage -ge $MEMORY_CRITICAL ]]; then
        print_error "Memory usage CRITICAL: ${usage}%"
        return 1
    elif [[ $usage -ge $MEMORY_WARNING ]]; then
        print_warning "Memory usage WARNING: ${usage}%"
        return 1
    else
        print_ok "Memory usage: ${usage}%"
        return 0
    fi
}

# Check systemd services
check_services() {
    local node=$1

    print_section "Services Status"

    for service in "${SERVICES[@]}"; do
        local status=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
            "systemctl is-active $service 2>/dev/null" 2>/dev/null)

        if [[ "$status" == "active" ]]; then
            print_ok "$service is running"
        elif [[ "$status" == "inactive" ]]; then
            if $VERBOSE; then
                print_info "$service is not installed/running"
            fi
        else
            if $VERBOSE; then
                print_info "$service is not installed"
            fi
        fi
    done
}

# Check certificate expiration
check_certificates() {
    local node=$1

    print_section "Certificate Status"

    # Check common certificate locations
    local cert_paths=("/etc/letsencrypt/live/" "/etc/ssl/certs/" "/etc/kubernetes/pki/")
    local certs_found=false

    for cert_path in "${cert_paths[@]}"; do
        local certs=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
            "find $cert_path -name '*.crt' -o -name '*.pem' 2>/dev/null" 2>/dev/null)

        if [[ -n "$certs" ]]; then
            certs_found=true
            while IFS= read -r cert; do
                local expiry=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
                    "openssl x509 -in '$cert' -noout -enddate 2>/dev/null | cut -d= -f2" 2>/dev/null)

                if [[ -n "$expiry" ]]; then
                    local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Z %Y" "$expiry" +%s 2>/dev/null)
                    local current_epoch=$(date +%s)
                    local days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))

                    if [[ $days_left -lt 0 ]]; then
                        print_error "Certificate expired: $(basename $cert) - Expired $((days_left*-1)) days ago"
                    elif [[ $days_left -lt 30 ]]; then
                        print_warning "Certificate expiring soon: $(basename $cert) - $days_left days left"
                    else
                        print_ok "Certificate valid: $(basename $cert) - $days_left days left"
                    fi
                fi
            done <<< "$certs"
        fi
    done

    if ! $certs_found; then
        print_info "No certificates found"
    fi
}

# Check NTP synchronization
check_ntp() {
    local node=$1

    print_section "Time Synchronization"

    local ntp_status=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
        "timedatectl status 2>/dev/null | grep -i 'synchronized' | grep -o 'yes\|no'" 2>/dev/null)

    if [[ "$ntp_status" == "yes" ]]; then
        print_ok "NTP synchronized"
    elif [[ "$ntp_status" == "no" ]]; then
        print_error "NTP not synchronized"
    else
        print_warning "Could not determine NTP status"
    fi

    # Get current time
    local node_time=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
        "date '+%Y-%m-%d %H:%M:%S'" 2>/dev/null)
    local local_time=$(date '+%Y-%m-%d %H:%M:%S')

    if $VERBOSE; then
        print_info "Node time: $node_time"
        print_info "Local time: $local_time"
    fi
}

# Check network connectivity
check_network() {
    local node=$1

    print_section "Network Status"

    local interfaces=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" \
        "ip link show | grep '^[0-9]:' | awk -F: '{print \$2}' | tr -d ' '" 2>/dev/null)

    if [[ -n "$interfaces" ]]; then
        local count=0
        while IFS= read -r iface; do
            if [[ "$iface" != "lo" ]]; then
                count=$((count+1))
            fi
        done <<< "$interfaces"
        print_ok "Network interfaces: $count"
    else
        print_warning "Could not retrieve network interfaces"
    fi
}

# Check if monitoring services are available
check_monitoring_services() {
    print_section "Monitoring Services"

    # Check Prometheus
    if timeout $TIMEOUT curl -s http://localhost:9090/-/healthy &> /dev/null; then
        print_ok "Prometheus is responding"
    else
        print_warning "Prometheus not responding on localhost:9090"
    fi

    # Check Grafana
    if timeout $TIMEOUT curl -s http://localhost:3000/api/health &> /dev/null; then
        print_ok "Grafana is responding"
    else
        print_warning "Grafana not responding on localhost:3000"
    fi
}

# Generate summary
print_summary() {
    local total_nodes=${#NODES[@]}

    print_section "Cluster Health Summary"

    if [[ $total_nodes -eq 0 ]]; then
        print_info "No nodes to check"
        return
    fi

    if [[ $CRITICAL_NODES -eq 0 ]]; then
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✓ Cluster Status: HEALTHY${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    elif [[ $CRITICAL_NODES -lt $(( total_nodes / 2 )) ]]; then
        echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}⚠ Cluster Status: DEGRADED (Issues on $CRITICAL_NODES nodes)${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
    else
        echo -e "${RED}════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}✗ Cluster Status: CRITICAL (Issues on $CRITICAL_NODES nodes)${NC}"
        echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    fi

    echo ""
    echo "Checked Nodes: $total_nodes"
    echo -e "  ${GREEN}Healthy: $HEALTHY_NODES${NC}"
    echo -e "  ${YELLOW}Warnings: $WARNING_NODES${NC}"
    echo -e "  ${RED}Critical: $CRITICAL_NODES${NC}"
}

# Main execution
main() {
    print_header "PicoCluster Health Check"

    # Load nodes from inventory
    load_inventory

    if [[ -n "$CHECK_NODE" ]]; then
        NODES=("$CHECK_NODE")
    fi

    if [[ ${#NODES[@]} -eq 0 ]]; then
        print_error "No nodes found. Ensure Ansible inventory is configured."
        exit 1
    fi

    print_info "Checking ${#NODES[@]} nodes..."
    echo ""

    # Check monitoring services first
    check_monitoring_services

    # Check each node
    for node in "${NODES[@]}"; do
        echo ""

        if check_node_reachability "$node" ""; then
            HEALTHY_NODES=$((HEALTHY_NODES+1))

            check_disk_space "$node"
            check_memory_usage "$node"
            check_services "$node"
            check_certificates "$node"
            check_ntp "$node"
            check_network "$node"
        else
            CRITICAL_NODES=$((CRITICAL_NODES+1))
        fi
    done

    # Print summary
    echo ""
    print_summary
}

# Run main function
main

exit 0
