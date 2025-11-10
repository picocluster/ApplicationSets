# Automated Security Updates Setup Guide

Complete guide for configuring automated security updates on your PicoCluster nodes using unattended-upgrades.

## Overview

Unattended-upgrades automates the installation of critical security patches while maintaining system stability. It provides:

- **Automatic security patching**: Security updates install without manual intervention
- **Stability**: Only security patches, not major version upgrades
- **Customization**: Full control over update schedule and reboot policies
- **Notifications**: Optional email alerts on updates
- **Audit trail**: Complete logging of all updates applied
- **Safe reboots**: Intelligent reboot scheduling only when necessary

### Why Automated Updates?

- **Security**: Reduces exposure to known vulnerabilities
- **Compliance**: Meets security standards (CIS, PCI, HIPAA)
- **Operations**: Reduces manual maintenance work
- **Consistency**: All nodes stay synchronized
- **Transparency**: Full audit trail of changes

## Quick Start

### Step 1: Deploy Automated Updates

```bash
# Deploy to all cluster nodes
ansible-playbook infrastructure/security/install_unattended_upgrades.ansible

# Deploy with auto-reboot enabled (careful with production!)
ansible-playbook infrastructure/security/install_unattended_upgrades.ansible \
  -e enable_auto_reboot=true \
  -e reboot_time="03:00" \
  -e reboot_day="Sunday"

# Deploy with email notifications
ansible-playbook infrastructure/security/install_unattended_upgrades.ansible \
  -e enable_notifications=true \
  -e notification_email="admin@example.com"
```

### Step 2: Verify Installation

```bash
# Check status
sudo systemctl status unattended-upgrades

# View configuration
cat /etc/apt/apt.conf.d/50unattended-upgrades

# Run dry-run to see what would be updated
sudo unattended-upgrade --dry-run
```

### Step 3: Monitor Updates

```bash
# Check for available security updates
apt list --upgradable | grep security

# View recent updates
security-update-status

# Check if reboot required
check-reboot-required
```

## Configuration

### Main Configuration File

Location: `/etc/apt/apt.conf.d/50unattended-upgrades`

Key settings:

```ini
# Allow reboot with users logged in
Unattended-Upgrade::AllowRebootWithUsers "false";

# Automatic reboot (only if updates require it)
Unattended-Upgrade::Automatic-Reboot "false";  # Set to "true" for auto-reboot
Unattended-Upgrade::Automatic-Reboot-Time "03:00";  # Reboot time (3 AM)

# Limit to security updates
Unattended-Upgrade::Origins-Pattern {
    "origin=Ubuntu,archive=${distro_codename}-security,label=Ubuntu";
};

# Email notifications
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";  # Only email on errors

# Remove unused dependencies
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
```

### APT Periodic Configuration

Location: `/etc/apt/apt.conf.d/02periodic`

Configures how often updates are checked:

```ini
# Daily checks
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";

# Weekly autoclean
APT::Periodic::AutocleanInterval "7";
```

## Update Types

### Security Updates (Automatic)

Critical security patches that fix vulnerabilities:

```bash
# Example: Security fix for OpenSSL vulnerability
# Version 1.2.3-4ubuntu1.1 → 1.2.3-4ubuntu1.2 (security patch)
```

These are:
- ✅ Installed automatically
- ✅ Low risk
- ✅ Tagged as security patches in APT repositories

### Major Updates (Manual Review)

Version upgrades like major kernel or OS updates:

```bash
# Example: Major version upgrade
# Ubuntu 20.04 → 22.04 (requires manual action)
```

These are:
- ❌ NOT installed automatically
- ⚠️ Requires thorough testing
- ⚠️ May require system downtime
- ⚠️ Manual review and planning needed

## Reboot Management

### No Auto-Reboot (Safest)

```ini
Unattended-Upgrade::Automatic-Reboot "false";
```

When reboot is needed:
1. File `/var/run/reboot-required` is created
2. Admin is notified
3. Manual `reboot` command required

Best for:
- Production systems
- Services requiring uptime
- Services requiring manual startup

### Auto-Reboot at Specific Time

```ini
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";  # 3 AM UTC
```

When reboot is needed:
1. Updates are installed
2. System waits until 3 AM
3. Automatic reboot occurs
4. Services auto-start after reboot

Best for:
- Test/staging environments
- Non-critical infrastructure
- Batch processing systems

## Customization

### Hold Packages from Auto-Update

Prevent specific packages from being auto-updated:

```bash
# Hold a package
sudo apt-mark hold <package-name>

# Example: Hold Docker to prevent version conflicts
sudo apt-mark hold docker.io

# List held packages
apt-mark showhold

# Unhold a package
sudo apt-mark unhold <package-name>
```

Using Ansible:

```yaml
vars:
  packages_to_hold:
    - docker.io
    - kubernetes
    - postgresql
```

### Email Notifications

Enable notifications when updates are installed:

```bash
# With Ansible
ansible-playbook infrastructure/security/install_unattended_upgrades.ansible \
  -e enable_notifications=true \
  -e notification_email="admin@example.com"
```

Manual configuration:

```ini
# /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Mail "admin@example.com";
Unattended-Upgrade::MailOnlyOnError "false";  # Email on any change
```

### Disable Auto-Updates

To disable automatic updates:

```bash
# Method 1: Disable service
sudo systemctl disable unattended-upgrades
sudo systemctl stop unattended-upgrades

# Method 2: Edit config
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
# Comment out: APT::Periodic::Unattended-Upgrade "1";
# Change to: APT::Periodic::Unattended-Upgrade "0";
```

## Monitoring and Maintenance

### Check Update Status

```bash
# Quick status check
security-update-status

# Manual check
apt list --upgradable
apt list --upgradable | grep security

# Detailed check
sudo unattended-upgrade --dry-run
```

### View Update Logs

```bash
# Main update log
tail -f /var/log/unattended-upgrades/unattended-upgrades.log

# APT history
cat /var/log/apt/history.log

# System journal
journalctl -u unattended-upgrades -f
journalctl -u apt -f
```

### Check for Required Reboots

```bash
# Check if reboot required
[ -f /var/run/reboot-required ] && echo "REBOOT NEEDED" || echo "No reboot needed"

# View reason for reboot
cat /var/run/reboot-required.pkgs

# Using helper script
check-reboot-required
```

### Generate Update Report

```bash
# Create security updates report
security-update-report

# Report saved to: /var/log/security-updates-$(date +%Y%m%d).txt
```

## Common Tasks

### Force Update Check

```bash
# Run update check immediately
sudo unattended-upgrade -d

# Or trigger APT update manually
sudo apt update
sudo apt list --upgradable
```

### Apply Updates Manually

```bash
# Install security updates manually
sudo apt update
sudo apt upgrade  # Only security patches (with unattended-upgrades)

# Install all updates (including non-security)
sudo apt full-upgrade

# Apply specific package update
sudo apt install --only-upgrade <package-name>
```

### Reboot System

```bash
# Check if reboot needed
check-reboot-required

# Reboot immediately
sudo reboot

# Schedule reboot for specific time
echo "sudo shutdown -r 03:00" | sudo tee /etc/cron.d/scheduled-reboot
```

### Troubleshoot Failed Updates

```bash
# 1. Check for held packages
apt-mark showhold

# 2. Check for broken dependencies
sudo apt --fix-broken install

# 3. Check APT cache
sudo apt autoclean
sudo apt autoremove

# 4. View detailed logs
sudo journalctl -u unattended-upgrades -n 100

# 5. Run in debug mode
sudo unattended-upgrade -d
```

## Best Practices

### 1. Testing in Staging First

Before enabling auto-reboot in production:

1. Deploy to staging cluster
2. Enable auto-reboot
3. Monitor for stability issues
4. Verify services auto-start correctly

```bash
# Deploy to staging
ansible-playbook infrastructure/security/install_unattended_upgrades.ansible \
  -e enable_auto_reboot=true \
  -i staging-inventory
```

### 2. Stagger Reboots Across Nodes

For high-availability clusters, don't reboot all nodes simultaneously:

```bash
# Option 1: Use different reboot times per node
# Set different times in inventory or with host variables

# Option 2: Disable auto-reboot, manually manage
# Schedule reboots with maintenance windows
```

### 3. Monitor Reboot Status

```bash
# Check all nodes for reboot requirement
ansible all -m shell -a "check-reboot-required; echo $?"

# Nodes with exit code 1 need reboot
```

### 4. Notification Setup

Configure email notifications to stay informed:

```bash
# Install postfix for local mail delivery
sudo apt install postfix

# Configure unattended-upgrades with notifications
# See configuration section above
```

### 5. Audit Trail

Keep records of all updates:

```bash
# Monthly backup of update logs
tar -czf /backup/security-updates-$(date +%Y%m).tar.gz \
  /var/log/unattended-upgrades/ \
  /var/log/apt/history.log

# Retain for compliance
```

## Troubleshooting

### No Updates Being Applied

```bash
# 1. Check service status
sudo systemctl status unattended-upgrades

# 2. Verify configuration
grep "Unattended-Upgrade::Automatic-Reboot" /etc/apt/apt.conf.d/50unattended-upgrades

# 3. Check APT periodic is enabled
grep "APT::Periodic" /etc/apt/apt.conf.d/02periodic

# 4. Run dry-run
sudo unattended-upgrade --dry-run

# 5. Check APT cache
sudo apt update
apt list --upgradable
```

### Updates Failing

```bash
# 1. Check for held packages
apt-mark showhold

# 2. Fix broken dependencies
sudo apt --fix-broken install
sudo apt --fix-missing install

# 3. Check disk space
df -h /

# 4. Clean APT cache
sudo apt autoclean
sudo apt autoremove

# 5. Review logs
tail -50 /var/log/unattended-upgrades/unattended-upgrades.log
```

### Reboot Not Happening

```bash
# 1. Check reboot requirement
[ -f /var/run/reboot-required ] && echo "Reboot needed"

# 2. Check auto-reboot setting
grep "Automatic-Reboot \"" /etc/apt/apt.conf.d/50unattended-upgrades

# 3. Check systemd-inhibit (prevents reboot)
systemd-inhibit --list

# 4. Manual reboot
sudo reboot

# 5. Check timezone for scheduled reboot
timedatectl
```

## Integration with Cluster Services

### Kubernetes Considerations

For Kubernetes nodes, consider:

```bash
# Drain node before reboot
kubectl drain <node-name> --ignore-daemonsets

# Reboot node
sudo reboot

# Uncordon node
kubectl uncordon <node-name>

# Or disable auto-reboot and schedule manually
apt-mark hold kubelet kubeadm kubectl
```

### Docker/Container Considerations

For container hosts:

```bash
# Hold container runtime to prevent version conflicts
apt-mark hold docker.io

# Or hold containerd
apt-mark hold containerd

# Verify before rebooting
docker ps -q  # Check for running containers
```

### Database Considerations

For database servers:

```bash
# Hold database packages
apt-mark hold postgresql postgresql-contrib
apt-mark hold mysql-server

# Manually manage major version upgrades
# Ensure backups before upgrading
```

## See Also

- [Debian Security Handbook](https://www.debian.org/doc/manuals/securing-debian-howto/)
- [Ubuntu Security](https://ubuntu.com/security)
- [unattended-upgrades Documentation](https://wiki.debian.org/UnattendedUpgrades)
- [APT Security Updates](https://help.ubuntu.com/community/AutomaticSecurityUpdates)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
