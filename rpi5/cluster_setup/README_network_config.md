# RPI5 Network Configuration Guide

This directory contains scripts for configuring and managing network settings across your RPI5 cluster.

## Quick Start

For a 5-node RPI5 cluster with default IP range (10.1.10.240+):

```bash
# 1. Plan the configuration
ansible-playbook change_ips.ansible -e "cluster_size=5"

# 2. Apply to each node (run once per node)
ansible-playbook apply_network_config.ansible -l pc0 -e "node_ip=10.1.10.240"
ansible-playbook apply_network_config.ansible -l pc1 -e "node_ip=10.1.10.241"
ansible-playbook apply_network_config.ansible -l pc2 -e "node_ip=10.1.10.242"
ansible-playbook apply_network_config.ansible -l pc3 -e "node_ip=10.1.10.243"
ansible-playbook apply_network_config.ansible -l pc4 -e "node_ip=10.1.10.244"

# 3. Reboot nodes
ansible cluster -m shell -a "shutdown -r now" -b

# 4. Verify connectivity
ansible cluster -m ping
```

## Available Scripts

### change_ips.ansible

**Purpose**: Plan and display IP address configuration for your cluster

**Usage**:
```bash
ansible-playbook change_ips.ansible -e "cluster_size=5 start_ip_octet=240"
```

**Parameters**:
- `cluster_size`: Number of nodes in cluster (1-24, default: 5)
- `start_ip_octet`: Starting octet of IP address (default: 240)

**Example Configurations**:

```bash
# Pico3 (3 nodes, starts at 10.1.10.240)
ansible-playbook change_ips.ansible -e "cluster_size=3"
# Result: pc0=10.1.10.240, pc1=10.1.10.241, pc2=10.1.10.242

# Pico5 (5 nodes, starts at 10.1.10.240)
ansible-playbook change_ips.ansible -e "cluster_size=5"
# Result: pc0=10.1.10.240 through pc4=10.1.10.244

# Pico10 (10 nodes, starts at 10.1.10.240)
ansible-playbook change_ips.ansible -e "cluster_size=10"
# Result: pc0=10.1.10.240 through pc9=10.1.10.249

# Pico20 (20 nodes, first 10 at 10.1.10.230-239)
ansible-playbook change_ips.ansible -e "cluster_size=20 start_ip_octet=230"
# Result: pc0=10.1.10.230 through pc9=10.1.10.239, pc10=10.1.10.240 through pc19=10.1.10.249
```

### apply_network_config.ansible

**Purpose**: Apply network configuration to individual nodes

**Usage**:
```bash
ansible-playbook apply_network_config.ansible -l <node_name> -e "node_ip=10.1.10.X"
```

**Parameters**:
- `node_ip`: IP address to assign (required, format: 10.1.10.X)
- Host pattern (-l flag): Target node(s)

**What it does**:
1. Validates IP address format
2. Backs up current network configuration
3. Configures netplan for Ubuntu (if applicable)
4. Updates legacy interfaces file for Raspbian/Debian compatibility
5. Updates hostname
6. Updates /etc/hosts

**Example**:

```bash
# Configure pc0
ansible-playbook apply_network_config.ansible -l pc0 -e "node_ip=10.1.10.240"

# Configure pc1
ansible-playbook apply_network_config.ansible -l pc1 -e "node_ip=10.1.10.241"

# Configure multiple nodes at once (must have different IPs)
ansible-playbook apply_network_config.ansible -l pc[0:2] -e "node_ip=10.1.10.240"  # Only works if nodes differ
```

**Important Notes**:
- Configure each node individually with its specific IP
- Backup files are created with timestamp: `/etc/network/interfaces.backup.<timestamp>`
- Node hostname is automatically set to match inventory_hostname (pc0, pc1, etc.)

## Network Configuration Details

### Default Network Settings

- **Network**: 10.1.10.0/24
- **Gateway**: 10.1.10.1
- **DNS Servers**: 10.1.10.1 (gateway), 8.8.8.8 (Google)
- **Netmask**: 255.255.255.0

### Ubuntu vs Raspbian Network Configuration

**Ubuntu RPI5**:
- Uses netplan (YAML-based network configuration)
- File: `/etc/netplan/99-custom.yaml`
- Applied with: `netplan apply`

**Raspbian RPI5**:
- Uses traditional interfaces file (for compatibility)
- File: `/etc/network/interfaces`
- Can also use legacy interfaces.d directory

Both are supported by this script with automatic detection.

## Workflow

### Initial RPI5 Cluster Setup

```bash
# 1. Bootstrap nodes (user creation, SSH keys, etc.)
# Use bootstrap.ansible for Raspbian or bootstrap_ubuntu.ansible for Ubuntu
ansible-playbook bootstrap.ansible

# 2. Plan network configuration
ansible-playbook change_ips.ansible -e "cluster_size=5"

# 3. Apply network config to each node
for i in {0..4}; do
  ansible-playbook apply_network_config.ansible -l pc$i -e "node_ip=10.1.10.$((240+i))"
done

# 4. Reboot all nodes
ansible cluster -b -m shell -a "shutdown -r now"

# 5. Verify connectivity after 2-3 minutes
ansible cluster -m ping

# 6. Install Kubernetes
cd ../kubernetes
# Choose one based on your OS:
# Ubuntu: ansible-playbook install_kubernetes_containerd_cluster_ubuntu.ansible
# Raspbian: ansible-playbook install_kubernetes_containerd_cluster_raspbian.ansible
```

## Verifying Network Configuration

```bash
# Check IP configuration on a node
ansible pc0 -m shell -a "ip addr show eth0"

# Check hostname
ansible pc0 -m shell -a "hostname"

# Check hosts file
ansible pc0 -m shell -a "cat /etc/hosts | grep pc"

# Test inter-node connectivity
ansible pc0 -m shell -a "ping -c 3 pc1"

# Check default gateway
ansible pc0 -m shell -a "ip route"
```

## Troubleshooting

### Network not coming up after apply

```bash
# Check netplan configuration (Ubuntu)
ansible pc0 -m shell -a "netplan get" -b

# Check network interface status
ansible pc0 -m shell -a "ip link show eth0" -b

# Check for netplan errors (Ubuntu)
ansible pc0 -m shell -a "netplan validate" -b

# Force reapply (Ubuntu)
ansible pc0 -m shell -a "netplan apply" -b

# Restart networking (Raspbian)
ansible pc0 -m shell -a "systemctl restart networking" -b
```

### Can't reach node after reboot

1. Check physical connections
2. Verify IP assignment: `ansible pc0 -m shell -a "ip addr"`
3. Check gateway route: `ansible pc0 -m shell -a "ip route"`
4. Ping gateway: `ansible pc0 -m shell -a "ping 10.1.10.1"`
5. Check systemd-networkd (Ubuntu) or networking service (Raspbian)

### DNS resolution not working

```bash
# Check resolv.conf
ansible pc0 -m shell -a "cat /etc/resolv.conf"

# Test DNS resolution
ansible pc0 -m shell -a "nslookup google.com"
ansible pc0 -m shell -a "ping google.com"

# Check netplan DNS config (Ubuntu)
ansible pc0 -m shell -a "cat /etc/netplan/99-custom.yaml"
```

### Hostname not updating

```bash
# Manually set hostname
ansible pc0 -b -m shell -a "hostnamectl set-hostname pc0"

# Verify
ansible pc0 -m shell -a "hostname"

# Also update /etc/hosts
ansible pc0 -b -m lineinfile -a "path=/etc/hosts regexp='^127.0.0.1' line='127.0.0.1 localhost pc0'"
```

## Advanced Configuration

### Custom DNS Servers

Edit the playbook and modify:

```yaml
dns_servers: ["10.1.10.1", "8.8.8.8"]
```

To use custom DNS:
```yaml
dns_servers: ["1.1.1.1", "1.0.0.1"]  # Cloudflare
```

### Static Route Configuration

For nodes needing access to other networks:

```bash
# Add static route
ansible pc0 -b -m shell -a "ip route add 192.168.1.0/24 via 10.1.10.1"

# Make persistent by editing apply_network_config.ansible and adding:
# - name: Configure static routes
#   lineinfile:
#     path: /etc/network/interfaces
#     line: "up route add -net 192.168.1.0 netmask 255.255.255.0 gw 10.1.10.1"
```

## File Locations

- Network config scripts: `/home/user/ApplicationSets/rpi5/cluster_setup/`
- Configuration backups: `/etc/network/interfaces.backup.*` (on each node)
- Netplan configs: `/etc/netplan/99-custom.yaml` (Ubuntu only)
- interfaces file: `/etc/network/interfaces` (Raspbian/all systems)

## Network Architecture

```
Internet
   |
   v
[Gateway: 10.1.10.1]
   |
   +------ eth0 ------+
   |                  |
   v                  v
[pc0: 10.1.10.240]   [pc1: 10.1.10.241]
   |                  |
   +---- RPI5 Cluster ----+
   |
   v
[pc2: 10.1.10.242] ... [pcN: 10.1.10.X+N]
```

## Performance Tips

1. **Use Gigabit Ethernet**: RPI5 supports GbE, ensuring fast inter-node communication
2. **Power Supply**: Ensure adequate power - cluster networking is demanding
3. **Network Switch**: Use a managed switch for better control and monitoring
4. **VLAN Support**: Can configure VLANs for network segmentation

## Additional Resources

- Interface configuration: `man interfaces`
- Netplan documentation: `man netplan` (Ubuntu)
- Ubuntu networking: https://ubuntu.com/server/docs/networking
- Raspbian networking: https://www.raspberrypi.org/documentation/configuration/tcpip/

## Next Steps

After network configuration:
1. Run Kubernetes installation scripts
2. Configure container networking
3. Set up monitoring and logging
4. Deploy applications to your cluster
