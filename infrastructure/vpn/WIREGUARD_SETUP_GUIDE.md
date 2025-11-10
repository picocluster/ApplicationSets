# WireGuard VPN Setup Guide for PicoCluster

Complete guide for setting up WireGuard VPN for secure access to your PicoCluster.

## Overview

WireGuard is a modern, lightweight VPN protocol offering excellent performance on embedded systems. It features:

- **Minimal code base**: 4,000 lines (vs 100,000+ for OpenVPN)
- **Modern cryptography**: Curve25519, ChaCha20, Poly1305
- **Better performance**: Lower latency, higher throughput
- **Stateless design**: Simpler debugging and troubleshooting
- **Built-in IP management**: No separate IPAM needed
- **Perfect forward secrecy**: Keys rotated automatically

## Architecture

```
VPN Clients (Laptops, Remote Servers)
            ↓
       UDP Port 51820
            ↓
    WireGuard Server
    (on one cluster node)
            ↓
    Cluster Network
    (other nodes accessible via VPN)
```

### Use Cases

- **Remote Management**: Access cluster from home/office
- **Developer Access**: Secure access for developers
- **Inter-cluster VPN**: Connect multiple clusters
- **Monitor Access**: Remote monitoring and logging
- **Secure Tunneling**: Encrypted site-to-site connectivity

## Quick Start

### Step 1: Install WireGuard Server

```bash
# Install on a cluster node (typically monitoring or dedicated VPN node)
ansible-playbook infrastructure/vpn/install_wireguard.ansible -l vpn-server
```

WireGuard server will:
- Listen on UDP port 51820
- Assign VPN IPs from 10.0.0.0/24
- Enable IP forwarding for client routing
- Create management scripts

### Step 2: Generate Client Configuration

```bash
# On VPN server, generate client config
wg-gen-client 10.1.10.245 laptop 10.0.0.2

# Arguments:
# - Server IP (external IP clients connect to)
# - Client name (identifier for this client)
# - Client VPN IP (unique IP within 10.0.0.0/24)
```

This generates:
- Client configuration file
- QR code for mobile scanning
- Instructions for installation

### Step 3: Install WireGuard on Client

```bash
# Install and configure on client machine
sudo ./configure_wireguard_client.sh client.conf

# Or with custom interface name
sudo ./configure_wireguard_client.sh client.conf work-vpn
```

### Step 4: Verify Connection

```bash
# On client machine
ping 10.0.0.1              # Ping VPN gateway
ssh user@10.1.10.245       # Access cluster via VPN
curl http://prometheus.cluster.local:9090  # Access internal services
```

## Server Configuration

### Installation Playbook

The `install_wireguard.ansible` playbook:

1. Installs WireGuard kernel module and tools
2. Generates server public/private keys
3. Creates configuration file
4. Enables IP forwarding (IPv4 and optionally IPv6)
5. Creates systemd service
6. Generates management scripts

### Configuration File (`/etc/wireguard/wg0.conf`)

Key sections:

```ini
[Interface]
# VPN IP for this server
Address = 10.0.0.1/24

# Private key (keep secret!)
PrivateKey = <server-private-key>

# Listen port and interface
ListenPort = 51820

# Enable IP forwarding for VPN traffic
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Optional: Provide DNS to clients
# DNS = 1.1.1.1,1.0.0.1

# Peers are added dynamically (see client management below)
```

### Firewall Configuration

Allow WireGuard port:

```bash
# With UFW (Ubuntu)
sudo ufw allow 51820/udp

# With iptables
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -j ACCEPT
sudo iptables -A FORWARD -o wg0 -j ACCEPT

# With firewalld
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --reload
```

## Client Management

### Generate Client Configuration

```bash
# Syntax: wg-gen-client <server-ip> <client-name> <client-vpn-ip>

# Example 1: Laptop
wg-gen-client 10.1.10.245 laptop 10.0.0.2

# Example 2: Desktop
wg-gen-client 10.1.10.245 desktop 10.0.0.3

# Example 3: Phone (mobile VPN)
wg-gen-client 10.1.10.245 iphone 10.0.0.4
```

Output includes:
- Configuration file content
- QR code for mobile clients
- Public key for server records

### Configure Multiple Clients

```bash
# Generate configs for different clients
wg-gen-client 10.1.10.245 alice 10.0.0.2
wg-gen-client 10.1.10.245 bob 10.0.0.3
wg-gen-client 10.1.10.245 charlie 10.0.0.4
```

Each client gets:
- Unique VPN IP (10.0.0.2, 10.0.0.3, 10.0.0.4)
- Unique private key
- Server's public key
- Connection endpoint (server IP/port)

### Remove Client

```bash
# Get client's public key from wg show output
wg show wg0 peers

# Remove the client
wg-remove-client <client-public-key>

# Verify removal
wg show wg0 peers
```

## Client Configuration

### Linux Client

1. **Install WireGuard**:
   ```bash
   sudo apt-get install wireguard wireguard-tools
   ```

2. **Copy configuration**:
   ```bash
   sudo ./configure_wireguard_client.sh client.conf
   ```

3. **Verify connection**:
   ```bash
   sudo wg show
   ping 10.0.0.1
   ```

### macOS Client

1. **Install WireGuard**:
   ```bash
   brew install wireguard-tools
   ```

2. **Or use GUI**:
   - Download WireGuard from App Store
   - Import configuration file
   - Activate connection

3. **Command line**:
   ```bash
   sudo wg-quick up ./client.conf
   sudo wg show
   ```

### Windows Client

1. Download WireGuard installer from [wireguard.com](https://www.wireguard.com/install/)
2. Install application
3. Import configuration file (copy client.conf)
4. Activate connection from GUI

### iOS/Android

1. Install WireGuard app
2. Create configuration from QR code or file
3. Activate VPN connection
4. Verify connectivity

## Configuration Management

### View Server Status

```bash
# Full WireGuard status
sudo wg show

# Show connected peers
sudo wg show wg0 peers

# Show interface details
ip addr show wg0
ip route show

# Show statistics
sudo wg show wg0 statistics
```

### Edit Configuration

```bash
# Edit server config
sudo nano /etc/wireguard/wg0.conf

# Edit client config
sudo nano /etc/wireguard/client.conf

# Reload after changes
sudo systemctl restart wg-quick@wg0
```

### Save Client as Permanent

```bash
# Copy to permanent location
sudo cp client.conf /etc/wireguard/work.conf

# Enable at boot
sudo systemctl enable wg-quick@work
sudo systemctl start wg-quick@work

# Manage
sudo systemctl status wg-quick@work
```

## Service Management

### Start/Stop WireGuard

```bash
# Start service
sudo systemctl start wg-quick@wg0

# Stop service
sudo systemctl stop wg-quick@wg0

# Restart service
sudo systemctl restart wg-quick@wg0

# Check status
sudo systemctl status wg-quick@wg0

# View logs
sudo journalctl -u wg-quick@wg0 -f

# Enable at boot
sudo systemctl enable wg-quick@wg0
```

### Manual Interface Management

```bash
# Bring up VPN interface
sudo wg-quick up wg0

# Bring down VPN interface
sudo wg-quick down wg0

# List active interfaces
wg show all
```

## Networking

### Routing Configuration

Default routes with WireGuard:

```bash
# View routes (client)
ip route show

# Example output:
# default via 10.0.0.1 dev wg0
# 10.0.0.0/24 dev wg0 proto kernel scope link src 10.0.0.2
# 10.1.10.0/24 via 10.0.0.1 dev wg0  # Cluster network through VPN
```

### Split Tunneling (Route Specific Networks)

By default, all cluster networks route through VPN. For split tunneling:

Edit client config:

```ini
[Peer]
AllowedIPs = 10.0.0.0/24, 10.1.10.0/24  # Only cluster networks
```

Default internet traffic uses local connection.

### Full Tunneling

To route all traffic through VPN:

```ini
[Peer]
AllowedIPs = 0.0.0.0/0  # All IPv4 traffic through VPN
```

## Security

### Key Management

```bash
# Server keys
/etc/wireguard/privatekey    # Keep secret!
/etc/wireguard/publickey     # Share with clients

# Client keys (in configuration file)
# PrivateKey = ...  # Keep secret!
```

**Never share private keys!**

### IP Forwarding Security

```bash
# Only forward VPN traffic
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

### Firewall Rules

```bash
# Allow only VPN port
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 51820/udp
sudo ufw allow ssh

# Restrict to specific sources
sudo ufw allow from 192.168.1.0/24 to any port 51820 proto udp
```

### Monitoring Access

```bash
# Check connected clients
wg show wg0 peers

# Check client IP
wg show wg0 allowed-ips

# View transfer statistics
wg show wg0 statistics
```

## Troubleshooting

### Client Cannot Connect

```bash
# 1. Check server is running
sudo systemctl status wg-quick@wg0

# 2. Check port is accessible
nc -zv <server-ip> 51820

# 3. Check firewall
sudo ufw status
sudo iptables -L -n | grep 51820

# 4. Check client config
cat /etc/wireguard/client.conf

# 5. Try manual connection
sudo wg-quick up ./client.conf

# 6. Check logs
sudo journalctl -u wg-quick@wg0 -n 50
```

### No Internet Access

```bash
# 1. Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# 2. Check routing
ip route show

# 3. Check NAT rules
sudo iptables -t nat -L -n

# 4. Check DNS
cat /etc/resolv.conf
nslookup google.com
```

### Low Performance

```bash
# 1. Check MTU size (should be 1420)
ip link show wg0

# 2. Adjust if needed
ip link set wg0 mtu 1420

# 3. Check packet loss
ping -c 10 <remote-ip>

# 4. Check bandwidth
iperf3 -c <server-ip> -R
```

### Interface Drops

```bash
# 1. Check keepalive setting
grep PersistentKeepalive /etc/wireguard/client.conf

# 2. Increase keepalive (for NAT traversal)
# PersistentKeepalive = 25

# 3. Check system logs
sudo journalctl -b | grep -i wireguard

# 4. Monitor connection
sudo watch -n 1 'wg show wg0'
```

## Integration with Cluster Services

### Access Prometheus via VPN

```bash
# On client, connected to VPN
curl http://prometheus.cluster.local:9090
# or
curl http://10.1.10.245:9090  # Direct cluster IP
```

### SSH through VPN

```bash
# Connect to cluster node via VPN IP
ssh ubuntu@10.1.10.241

# Or use cluster hostname (if DNS configured)
ssh ubuntu@pc1.cluster.local
```

### Remote Kubernetes Administration

```bash
# Export kubeconfig
kubectl --kubeconfig=/path/to/config get pods

# Connect through VPN
kubectl cluster-info
kubectl get nodes
```

### Monitoring via VPN

```bash
# Access Grafana
http://10.1.10.245:3000

# Access AlertManager
http://10.1.10.245:9093

# Access Loki
http://10.1.10.245:3100
```

## Advanced Configuration

### Multiple VPN Networks

For larger deployments, create separate VPN interfaces:

```bash
# Create second VPN interface
sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg1.conf

# Edit wg1.conf with different subnet
# Address = 10.1.0.0/24
# ListenPort = 51821

# Enable
sudo systemctl start wg-quick@wg1
```

### Site-to-Site VPN

Connect two clusters:

```ini
# Cluster 1 to Cluster 2
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820

[Peer]
# Cluster 2 gateway
PublicKey = <cluster2-pubkey>
Endpoint = <cluster2-ip>:51820
AllowedIPs = 10.1.0.0/24  # Cluster 2 network
```

### VPN with Load Balancing

Multiple VPN servers for redundancy:

1. Deploy WireGuard on multiple nodes
2. Use same private/public keys
3. Load balance UDP port 51820
4. Clients connect to VIP/Load Balancer

## Useful Commands

```bash
# Server management
wg-gen-client <ip> <name> <vpn-ip>
wg-remove-client <pubkey>
wg-status

# WireGuard tools
wg show [interface] [peers|public-keys|...)
wg set <interface> peer <pubkey> allowed-ips <ips>
wg-quick up/down <interface>

# Testing
ping <vpn-ip>
traceroute <vpn-ip>
iperf3 -c <vpn-ip>

# Troubleshooting
sudo journalctl -u wg-quick@wg0 -f
ip addr show wg0
ip route show
netstat -tulpn | grep 51820
```

## Performance Tips

1. **Use UDP (native)**: WireGuard uses UDP natively
2. **MTU size**: Ensure MTU 1420+ for optimal throughput
3. **Keepalive**: Set PersistentKeepalive=25 for NAT traversal
4. **Threading**: WireGuard uses efficient single-threaded design
5. **Kernel module**: Ensures best performance on Linux

## See Also

- [WireGuard Official Docs](https://www.wireguard.com/)
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [WireGuard Whitepaper](https://www.wireguard.com/papers/wireguard.pdf)
- [WireGuard Git Repository](https://git.zx2c4.com/wireguard)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
