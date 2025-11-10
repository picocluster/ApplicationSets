#!/bin/bash

################################################################################
# PicoCluster Setup Validation Script
#
# Pre-flight checks before deploying to production:
# - Node reachability and SSH access
# - Ansible inventory and variables
# - Required software and tools
# - Network connectivity and time sync
# - Disk space and resources
# - Security configuration
#
# Usage:
#   ./validate_cluster_setup.sh                # Full validation
#   ./validate_cluster_setup.sh -v             # Verbose output
#   ./validate_cluster_setup.sh --quick        # Basic checks only
#   ./validate_cluster_setup.sh --fix          # Auto-fix issues
#
# Exit codes:
#   0 = All checks passed
#   1 = Some warnings
#   2 = Critical failures
#
################################################################################

set -o pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VERBOSE=false
QUICK_CHECK=false
AUTO_FIX=false
TIMEOUT=5
EXIT_CODE=0

# Check results
CHECKS_PASSED=0
CHECKS_WARNING=0
CHECKS_FAILED=0

# Utility functions
print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo -e "\n${BLUE}──── $1 ────${NC}"
}

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNING++))
    EXIT_CODE=1
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
    EXIT_CODE=2
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -v, --verbose           Verbose output with detailed information
    --quick                 Quick validation (basic checks only)
    --fix                   Attempt to auto-fix issues
    -h, --help              Show this help message

Examples:
    $0                      # Full validation
    $0 -v                   # Verbose mode
    $0 --quick              # Quick checks only

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --quick)
            QUICK_CHECK=true
            shift
            ;;
        --fix)
            AUTO_FIX=true
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

# Load Ansible inventory
load_inventory() {
    local inventory_file=""

    if [[ -f "inventory.ini" ]]; then
        inventory_file="inventory.ini"
    elif [[ -f "inventory.yaml" ]]; then
        inventory_file="inventory.yaml"
    elif [[ -f "inventory.yml" ]]; then
        inventory_file="inventory.yml"
    fi

    if [[ -z "$inventory_file" ]]; then
        print_fail "No Ansible inventory file found (inventory.ini/yaml/yml)"
        return 1
    fi

    if $VERBOSE; then
        print_info "Using inventory: $inventory_file"
    fi

    # Load hosts from inventory
    if command -v ansible-inventory &> /dev/null; then
        NODES=($(ansible-inventory -i "$inventory_file" --list 2>/dev/null | jq -r '.all.hosts[]' 2>/dev/null))
    fi

    # Fallback simple parsing
    if [[ ${#NODES[@]} -eq 0 ]]; then
        NODES=($(grep -E '^\s*pc[0-9]|^\[' "$inventory_file" 2>/dev/null | grep -v '^\[' | awk '{print $1}' | sort -u))
    fi

    if [[ ${#NODES[@]} -eq 0 ]]; then
        print_fail "Could not load nodes from inventory"
        return 1
    fi

    return 0
}

# Check required tools
check_required_tools() {
    print_section "Required Tools"

    local required_tools=("ansible" "ssh" "jq" "curl" "python3")

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version=$(command -v "$tool" &> /dev/null && $tool --version 2>/dev/null | head -1 || echo "installed")
            print_pass "$tool is installed"
            if $VERBOSE; then
                echo "  → $version"
            fi
        else
            print_fail "$tool is not installed"
        fi
    done
}

# Check Ansible configuration
check_ansible_config() {
    print_section "Ansible Configuration"

    # Check for ansible.cfg
    if [[ -f "ansible.cfg" ]]; then
        print_pass "ansible.cfg exists"
    else
        print_warning "ansible.cfg not found in current directory"
    fi

    # Check for group_vars
    if [[ -d "group_vars" ]]; then
        print_pass "group_vars directory exists"
        if $VERBOSE; then
            find group_vars -type f | while read f; do
                echo "  → $f"
            done
        fi
    else
        print_warning "No group_vars directory found"
    fi

    # Check for host_vars
    if [[ -d "host_vars" ]]; then
        print_pass "host_vars directory exists"
    fi

    # Check Ansible syntax
    if ansible-syntax-check -i "$(find . -name 'inventory.*' 2>/dev/null | head -1)" -q 2>/dev/null; then
        print_pass "Ansible playbook syntax is valid"
    else
        print_warning "Could not validate Ansible syntax (check manually)"
    fi
}

# Check SSH keys
check_ssh_keys() {
    print_section "SSH Configuration"

    # Check SSH key exists
    if [[ -f ~/.ssh/id_rsa ]] || [[ -f ~/.ssh/id_ed25519 ]]; then
        print_pass "SSH key exists"
    else
        print_warning "No SSH private key found (~/.ssh/id_rsa or id_ed25519)"
        if $AUTO_FIX; then
            print_info "Generating SSH key..."
            ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" 2>/dev/null
        fi
    fi

    # Check SSH config
    if [[ -f ~/.ssh/config ]]; then
        print_pass "SSH config file exists"
    else
        print_info "No SSH config file (~/.ssh/config)"
    fi

    # Check known_hosts
    if [[ -f ~/.ssh/known_hosts ]]; then
        print_pass "SSH known_hosts file exists"
    fi
}

# Check node connectivity
check_node_connectivity() {
    print_section "Node Connectivity"

    if [[ ${#NODES[@]} -eq 0 ]]; then
        print_fail "No nodes to check (inventory empty)"
        return 1
    fi

    local reachable=0
    local unreachable=0

    for node in "${NODES[@]}"; do
        if timeout $TIMEOUT ping -c 1 "$node" &> /dev/null; then
            print_pass "$node is reachable (ping)"
            ((reachable++))
        elif timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$node" "echo 1" &> /dev/null; then
            print_pass "$node is reachable (SSH)"
            ((reachable++))
        else
            print_fail "$node is unreachable"
            ((unreachable++))
        fi
    done

    print_info "Reachable: $reachable/${#NODES[@]}"
    [[ $unreachable -eq 0 ]] && return 0 || return 1
}

# Check node prerequisites
check_node_prerequisites() {
    print_section "Node Prerequisites"

    if [[ $QUICK_CHECK == true ]]; then
        print_info "Skipping detailed node checks (--quick mode)"
        return 0
    fi

    local sample_node="${NODES[0]}"

    if timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no "$sample_node" true &> /dev/null; then
        # Check Python
        if timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT "$sample_node" "which python3" &> /dev/null; then
            print_pass "Python 3 installed on nodes"
        else
            print_warning "Python 3 not found on $sample_node"
        fi

        # Check sudo access
        if timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT "$sample_node" "sudo whoami" &> /dev/null; then
            print_pass "Sudo access available"
        else
            print_warning "Sudo access may be restricted"
        fi

        # Check disk space
        local disk_usage=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT "$sample_node" \
            "df -h / | tail -1 | awk '{print \$5}' | tr -d '%'" 2>/dev/null)

        if [[ -n "$disk_usage" ]] && [[ $disk_usage -lt 80 ]]; then
            print_pass "Adequate disk space on nodes (${disk_usage}%)"
        elif [[ -n "$disk_usage" ]]; then
            print_warning "Limited disk space on nodes (${disk_usage}% used)"
        fi

        # Check memory
        local mem_total=$(timeout $TIMEOUT ssh -o ConnectTimeout=$TIMEOUT "$sample_node" \
            "free -h | grep Mem | awk '{print \$2}'" 2>/dev/null)

        if [[ -n "$mem_total" ]]; then
            print_pass "Available memory on nodes: $mem_total"
        fi

    else
        print_warning "Could not connect to $sample_node for detailed checks"
    fi
}

# Check network connectivity
check_network() {
    print_section "Network Configuration"

    # Check default gateway
    if ip route show | grep -q default; then
        local gateway=$(ip route show | grep default | awk '{print $3}')
        print_pass "Default gateway configured: $gateway"
    else
        print_warning "No default gateway configured"
    fi

    # Check DNS
    if grep -q "nameserver" /etc/resolv.conf; then
        local dns=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')
        print_pass "DNS configured: $dns"
    else
        print_warning "No DNS servers configured"
    fi

    # Check network interfaces
    local active_interfaces=$(ip link show | grep "^[0-9]" | grep "UP" | wc -l)
    if [[ $active_interfaces -gt 0 ]]; then
        print_pass "Active network interfaces: $active_interfaces"
    else
        print_fail "No active network interfaces"
    fi

    # Test external connectivity
    if timeout 3 curl -s -I https://github.com 2>&1 | grep -q "HTTP"; then
        print_pass "External connectivity available"
    else
        print_warning "Cannot reach external network (https://github.com)"
    fi
}

# Check time synchronization
check_time_sync() {
    print_section "Time Synchronization"

    if command -v timedatectl &> /dev/null; then
        if timedatectl status | grep -q "synchronized: yes"; then
            print_pass "System time is synchronized"
        else
            print_warning "System time is not synchronized"
        fi
    else
        print_info "timedatectl not available (NTP may still be working)"
    fi

    # Check NTP service
    if systemctl is-active chrony &> /dev/null || systemctl is-active ntp &> /dev/null || systemctl is-active systemd-timesyncd &> /dev/null; then
        print_pass "Time synchronization service is running"
    else
        print_warning "No time synchronization service detected"
    fi
}

# Check disk space
check_disk_space() {
    print_section "Local Disk Space"

    local usage=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')

    if [[ $usage -lt 70 ]]; then
        print_pass "Adequate disk space: ${usage}%"
    elif [[ $usage -lt 85 ]]; then
        print_warning "Limited disk space: ${usage}%"
    else
        print_fail "Critical disk space: ${usage}%"
    fi

    # Check specific directories
    if [[ -d "/var/lib/docker" ]]; then
        local docker_size=$(du -sh /var/lib/docker 2>/dev/null | awk '{print $1}')
        print_info "Docker storage: $docker_size"
    fi
}

# Check firewall
check_firewall() {
    print_section "Firewall Configuration"

    if systemctl is-active ufw &> /dev/null || systemctl is-active firewalld &> /dev/null; then
        print_warning "Firewall is active - ensure ports are open"
        print_info "Required ports: 22 (SSH), 6443 (K3s), 9090 (Prometheus), 3000 (Grafana)"
    else
        print_pass "No firewall blocking traffic"
    fi

    # Check ports
    local required_ports=(22 6443 9090 3000)
    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_info "Port $port is in use"
        fi
    done
}

# Check selinux/apparmor
check_security() {
    print_section "Security Configuration"

    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce 2>/dev/null)
        if [[ "$selinux_status" == "Enforcing" ]]; then
            print_warning "SELinux is enforcing - may affect cluster operations"
        else
            print_pass "SELinux is not enforcing"
        fi
    fi

    if command -v aa-status &> /dev/null; then
        if systemctl is-active apparmor &> /dev/null; then
            print_warning "AppArmor is active - may affect cluster operations"
        fi
    fi
}

# Check systemd
check_systemd() {
    print_section "SystemD Configuration"

    if systemctl is-system-running | grep -q "running"; then
        print_pass "SystemD is running normally"
    else
        local status=$(systemctl is-system-running 2>/dev/null)
        print_warning "SystemD status: $status"
    fi

    # Check failed units
    local failed_units=$(systemctl list-units --failed --no-pager 2>/dev/null | grep -c "failed")
    if [[ $failed_units -eq 0 ]]; then
        print_pass "No failed systemd units"
    else
        print_warning "$failed_units systemd units have failed"
    fi
}

# Generate report
print_summary() {
    print_section "Validation Summary"

    local total=$((CHECKS_PASSED + CHECKS_WARNING + CHECKS_FAILED))

    if [[ $CHECKS_FAILED -eq 0 ]]; then
        if [[ $CHECKS_WARNING -eq 0 ]]; then
            echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}✓ All checks passed! Cluster is ready for deployment.${NC}"
            echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        else
            echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}⚠ Some warnings found. Review before production.${NC}"
            echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
        fi
    else
        echo -e "${RED}════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}✗ Critical issues found. Fix before deployment.${NC}"
        echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    fi

    echo ""
    echo "Results:"
    echo -e "  ${GREEN}Passed:  $CHECKS_PASSED${NC}"
    echo -e "  ${YELLOW}Warnings: $CHECKS_WARNING${NC}"
    echo -e "  ${RED}Failed:  $CHECKS_FAILED${NC}"
    echo -e "  Total:   $total"
    echo ""

    if [[ $CHECKS_WARNING -gt 0 ]]; then
        echo "Recommendations:"
        echo "  1. Review warning items above"
        echo "  2. Fix non-critical issues"
        echo "  3. Re-run validation to confirm"
        echo ""
    fi

    echo "Next steps:"
    echo "  1. Deploy monitoring: ansible-playbook monitoring/*/install_prometheus_grafana.ansible"
    echo "  2. Deploy metrics: ansible-playbook monitoring/metrics_collection/deploy_metrics_to_cluster.ansible"
    echo "  3. Deploy alert rules: ansible-playbook cluster-management/deploy_alert_rules.ansible"
    echo "  4. Verify cluster: ./cluster-management/cluster_health_check.sh"
}

# Main execution
main() {
    print_header "PicoCluster Setup Validation"

    if ! load_inventory; then
        exit 2
    fi

    check_required_tools
    check_ansible_config
    check_ssh_keys

    if ! check_node_connectivity; then
        print_fail "Node connectivity issues detected - fix before proceeding"
        print_summary
        exit 2
    fi

    check_node_prerequisites
    check_network
    check_time_sync
    check_disk_space
    check_firewall
    check_security
    check_systemd

    print_summary
}

# Run validation
main

exit $EXIT_CODE
