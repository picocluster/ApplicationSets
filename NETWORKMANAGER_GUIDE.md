# NetworkManager Configuration Guide for PicoCluster

This guide covers using NetworkManager for static IP configuration across all PicoCluster platforms (Odroid H4, RPI5, Odroid C5).

## What is NetworkManager?

NetworkManager is a system service that manages network configurations and connections. It provides:
- **Automatic network detection and configuration**
- **Support for wired and wireless connections**
- **Easy command-line management via `nmcli`**
- **Persistent configuration storage** in `/etc/NetworkManager/`
- **No need for manual systemd networking** (though it can coexist)

### Why Use NetworkManager?

Advantages over netplan/interfaces files:
- ✅ More intuitive command-line interface (`nmcli`)
- ✅ Better WiFi support out of the box
- ✅ Live configuration without full systemd restart
- ✅ Automatic fallback to DHCP if static config fails
- ✅ Better compatibility across different Linux distributions

## Platform-Specific Scripts

### Odroid C5
```bash
# Plan IP assignments and view current network config
ansible-playbook odroid_c5/cluster_setup/change_ips_networkmanager.ansible

# Configure specific node
ansible-playbook odroid_c5/cluster_setup/change_ips_networkmanager.ansible -l pc0
```

### RPI5 Ubuntu
```bash
# Plan IP assignments
ansible-playbook rpi5/cluster_setup/change_ips_networkmanager_ubuntu.ansible

# Configure specific node
ansible-playbook rpi5/cluster_setup/change_ips_networkmanager_ubuntu.ansible -l pc0
```

### RPI5 Raspbian
```bash
# Plan IP assignments (includes dhcpcd disable)
ansible-playbook rpi5/cluster_setup/change_ips_networkmanager_raspbian.ansible

# Configure specific node
ansible-playbook rpi5/cluster_setup/change_ips_networkmanager_raspbian.ansible -l pc0
```

## Script Configuration

Before running, customize the network variables in the script:

```yaml
vars:
  network_interface: "eth0"              # Interface name (eth0, eth1, wlan0, etc.)
  gateway: "10.1.10.1"                  # Your gateway/router IP
  dns_servers: "8.8.8.8 8.8.4.4"        # DNS servers to use
  subnet_mask: "24"                      # CIDR notation (24 = /24 = 255.255.255.0)
  base_ip: "10.1.10"                    # Base network address
```

### IP Assignment Strategy

The scripts automatically assign IPs based on node order in Ansible inventory:
- Node 1 (index 0): `base_ip.240` → `10.1.10.240`
- Node 2 (index 1): `base_ip.241` → `10.1.10.241`
- Node 3 (index 2): `base_ip.242` → `10.1.10.242`
- And so on...

This provides a consistent 10-node range (240-249) before overlapping.

For larger clusters, adjust `base_ip` and the index calculation in the script.

## Manual NetworkManager Commands

### View Configuration

```bash
# List all connections
nmcli con show

# Show specific connection details
nmcli con show 'eth0'

# Show device status
nmcli dev status

# Show all devices
nmcli dev list
```

### Create Static IP Connection

```bash
# Create connection with static IP
nmcli con add type ethernet con-name eth0 \
  ifname eth0 \
  ipv4.method manual \
  ipv4.addresses "10.1.10.240/24" \
  ipv4.gateway "10.1.10.1" \
  ipv4.dns "8.8.8.8 8.8.4.4" \
  ipv4.ignore-auto-dns yes \
  autoconnect yes

# Activate the connection
nmcli con up eth0
```

### Modify Existing Connection

```bash
# Change IP address
nmcli con mod eth0 ipv4.addresses "10.1.10.241/24"

# Change gateway
nmcli con mod eth0 ipv4.gateway "10.1.10.1"

# Add additional DNS server
nmcli con mod eth0 +ipv4.dns "1.1.1.1"

# Apply changes
nmcli con down eth0
nmcli con up eth0
```

### Switch Between Static and DHCP

```bash
# Change to static IP
nmcli con mod eth0 ipv4.method manual
nmcli con mod eth0 ipv4.addresses "10.1.10.240/24"
nmcli con mod eth0 ipv4.gateway "10.1.10.1"
nmcli con up eth0

# Change to DHCP
nmcli con mod eth0 ipv4.method auto
nmcli con down eth0
nmcli con up eth0
```

### Connection Management

```bash
# Activate a connection
nmcli con up eth0

# Deactivate a connection
nmcli con down eth0

# Delete a connection
nmcli con delete eth0

# Edit connection interactively
nmcli con edit eth0

# Reload all connections from disk
nmcli con reload
```

## Configuration File Location

NetworkManager stores connection profiles in:
```bash
/etc/NetworkManager/system-connections/eth0.nmconnection
```

### Example Connection File

```ini
[connection]
id=eth0
uuid=12345678-1234-1234-1234-123456789012
type=802-3-ethernet
autoconnect=yes

[ipv4]
method=manual
addresses=10.1.10.240/24;10.1.10.1;
dns=8.8.8.8;8.8.4.4;
ignore-auto-dns=true

[802-3-ethernet]
mac-address=00:1A:2B:3C:4D:5E

[proxy]
```

### Manual File Editing

```bash
# Edit connection file directly
sudo nano /etc/NetworkManager/system-connections/eth0.nmconnection

# After editing, reload NetworkManager
sudo systemctl reload NetworkManager

# Verify changes
nmcli con show eth0
nmcli con up eth0
```

## Troubleshooting

### NetworkManager Service Issues

```bash
# Check service status
systemctl status NetworkManager

# Enable and start service
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# View real-time logs
sudo journalctl -u NetworkManager -f

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

### Connection Won't Activate

```bash
# Check for errors
nmcli con show eth0

# Try deactivating and reactivating
nmcli con down eth0
sleep 2
nmcli con up eth0

# Check physical device status
nmcli dev status

# If interface is unmanaged, enable it:
sudo nmcli dev set eth0 managed yes
```

### DNS Not Resolving

```bash
# Check DNS configuration in connection
nmcli con show eth0 | grep dns

# Check /etc/resolv.conf
cat /etc/resolv.conf

# Flush DNS cache and restart NetworkManager
sudo systemctl restart NetworkManager

# Verify DNS is working
nslookup google.com
dig google.com
```

### WiFi Connection (RPI5)

```bash
# List available WiFi networks
nmcli dev wifi list

# Connect to WiFi with password
nmcli dev wifi connect 'SSID' password 'password'

# Create WiFi connection profile
nmcli con add type wifi con-name my-wifi \
  ssid 'SSID' \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk 'password'
```

### Conflicting Network Services

On some systems, dhcpcd or systemd-networkd may conflict:

```bash
# Disable dhcpcd (RPI5 Raspbian)
sudo systemctl disable dhcpcd
sudo systemctl stop dhcpcd

# Disable systemd-networkd (if present)
sudo systemctl disable systemd-networkd
sudo systemctl stop systemd-networkd

# Ensure only NetworkManager manages interfaces
sudo systemctl enable NetworkManager
sudo systemctl restart NetworkManager
```

## Common Issues and Solutions

### Issue: "Connection activation failed"

**Solution**: Ensure the interface is managed by NetworkManager:
```bash
sudo nmcli dev set eth0 managed yes
sudo systemctl restart NetworkManager
```

### Issue: "Cannot find device 'eth0'"

**Solution**: Verify interface name:
```bash
# List all interfaces
ip link show
nmcli dev

# Use correct interface name in commands
nmcli con add type ethernet con-name wlan0 ifname wlan0 ...
```

### Issue: "Ignoring invalid autoconnect value 'yes'"

**Solution**: Use boolean values in command line:
```bash
# WRONG: autoconnect 'yes'
# CORRECT: autoconnect yes
nmcli con mod eth0 connection.autoconnect yes
```

### Issue: Static IP not persisting after reboot

**Solution**: Ensure autoconnect is enabled:
```bash
nmcli con mod eth0 connection.autoconnect yes
nmcli con up eth0
reboot
```

### Issue: Gateway/DNS not being used

**Solution**: Verify ignore-auto-dns is set correctly:
```bash
nmcli con mod eth0 ipv4.ignore-auto-dns yes
nmcli con down eth0
nmcli con up eth0

# Check DNS
nmcli con show eth0 | grep dns
cat /etc/resolv.conf
```

## Ansible Playbook Customization

To customize the provided scripts:

### Change Network Interface

```bash
# For wireless
ansible-playbook odroid_c5/cluster_setup/change_ips_networkmanager.ansible \
  -e "network_interface=wlan0"

# For secondary wired interface
ansible-playbook odroid_c5/cluster_setup/change_ips_networkmanager.ansible \
  -e "network_interface=eth1"
```

### Change Network Range

```bash
# Use different network (192.168.1.x)
ansible-playbook odroid_c5/cluster_setup/change_ips_networkmanager.ansible \
  -e "base_ip=192.168.1 gateway=192.168.1.1"
```

### Skip Connectivity Testing

Modify the script to skip the ping test if your network doesn't allow ICMP:
```yaml
# Comment out or remove the 'Test network connectivity' task
# Then run the playbook
```

## Advanced NetworkManager Configuration

### Multiple Connections per Device

```bash
# Create connection for wired (eth0)
nmcli con add type ethernet con-name "eth0-static" ifname eth0 \
  ipv4.method manual ipv4.addresses "10.1.10.240/24"

# Create alternative DHCP connection for same device
nmcli con add type ethernet con-name "eth0-dhcp" ifname eth0 \
  ipv4.method auto

# Switch between profiles
nmcli con down eth0-static
nmcli con up eth0-dhcp
```

### Connection Priorities

```bash
# Set connection autoconnect priority (0-999)
nmcli con mod eth0 connection.autoconnect-priority 100
```

### IPv6 Configuration

```bash
# Enable IPv6 with static address
nmcli con mod eth0 ipv6.method manual \
  ipv6.addresses "2001:db8::1/64" \
  ipv6.gateway "2001:db8::ff"
```

## Integration with Cluster Scripts

Once NetworkManager is configured with static IPs:

### Run Cluster Setup

```bash
# Network is ready for cluster software installation
ansible-playbook odroid_c5/kubernetes/install_k3s_single.ansible -l pc0

# Or full cluster deployment
ansible-playbook odroid_c5/kubernetes/install_k3s_cluster.ansible
```

### Verify Network Before Installation

```bash
# Ping all cluster nodes
for node in pc0 pc1 pc2; do
  echo "Testing $node:"
  ping -c 1 $node || echo "  FAILED"
done

# Check DNS resolution
nslookup pc0.local

# Verify connectivity to gateway
ping -c 1 10.1.10.1
```

## Best Practices

1. **Plan your network first**: Decide IP range, gateway, DNS servers before running scripts
2. **Document your setup**: Keep notes of network configuration for future reference
3. **Test before cluster setup**: Verify all nodes have connectivity before installing cluster software
4. **Use consistent naming**: Keep hostname and DNS names consistent (pc0, pc1, pc2, etc.)
5. **Monitor logs**: Check `journalctl -u NetworkManager` for issues
6. **Backup configurations**: Copy `/etc/NetworkManager/system-connections/` before major changes
7. **Use automation**: Keep scripts in version control for reproducible deployments

## Migration from Netplan/Interfaces

If converting from netplan or interfaces file configuration:

```bash
# 1. Check current configuration
cat /etc/netplan/99-custom.yaml  # netplan
cat /etc/network/interfaces       # interfaces

# 2. Delete old configuration files (after backup)
sudo cp -r /etc/netplan /etc/netplan.backup
sudo rm /etc/netplan/99-custom.yaml

# 3. Disable conflicting services
sudo systemctl disable systemd-networkd
sudo systemctl stop systemd-networkd

# 4. Run NetworkManager configuration script
ansible-playbook odroid_c5/cluster_setup/change_ips_networkmanager.ansible

# 5. Verify new configuration
nmcli con show
ip addr show
```

## References

- [NetworkManager Official Documentation](https://networkmanager.dev/)
- [nmcli Command Line Reference](https://networkmanager.dev/docs/api/latest/nmcli-examples.html)
- [NetworkManager Connection Profile Format](https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html)
- [Fedora NetworkManager Guide](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/networking/NetworkManager/)
- [Ubuntu NetworkManager Guide](https://ubuntu.com/core/docs/networkmanager)

