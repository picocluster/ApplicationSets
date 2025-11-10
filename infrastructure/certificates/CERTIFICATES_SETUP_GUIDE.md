# Let's Encrypt Certificate Management Setup Guide

Complete guide for managing SSL/TLS certificates with Let's Encrypt and Certbot in your PicoCluster.

## Overview

Let's Encrypt provides free, automated SSL/TLS certificates. Combined with Certbot, you get:

- **Automated provisioning**: Request certificates without manual processes
- **Auto-renewal**: Certificates renewed automatically before expiration
- **Multiple domain types**: Single domain, multiple domains, wildcard certificates
- **Flexible validation**: Standalone HTTP, webroot, or DNS-based validation
- **Integration**: Works with Traefik, nginx, Apache, custom services

### Why SSL/TLS Certificates?

- **Security**: Encrypt traffic between client and server
- **Trust**: Browser displays green lock for HTTPS
- **Privacy**: Prevent man-in-the-middle attacks
- **Compliance**: Required for PCI DSS, HIPAA, GDPR
- **SEO**: Google ranks HTTPS higher than HTTP

## Architecture

```
Certificate Request
       ↓
Certbot (ACME Client)
       ↓
Let's Encrypt ACME Server
       ↓
Domain Validation (HTTP/DNS)
       ↓
Certificate Authority
       ↓
Certificate Issuance
       ↓
Automatic Renewal (every 60 days)
```

## Quick Start

### Step 1: Install Certbot

```bash
# Install on certificate management node
ansible-playbook infrastructure/certificates/install_certbot.ansible
```

Certbot will:
- Install to `/usr/bin/certbot`
- Store certificates in `/etc/letsencrypt/`
- Enable automatic renewal via systemd timer
- Create management scripts: `cert-info`, `cert-check`

### Step 2: Request Certificate

```bash
# Single domain
certbot certonly --standalone --domains example.com

# Multiple domains
certbot certonly --standalone --domains example.com,www.example.com

# With email for renewal notifications
certbot certonly --standalone \
  --domains example.com \
  --email admin@example.com
```

### Step 3: Configure Web Server

#### Traefik Configuration

```yaml
# docker-compose.yml
version: '3.8'
services:
  traefik:
    image: traefik:v2.10
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command:
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.websecure.http.tls.certresolver=letsencrypt"
      - "--entrypoints.websecure.http.tls.certresolver.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/etc/letsencrypt/acme.json"
```

#### nginx Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://backend;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}
```

#### Apache Configuration

```apache
<VirtualHost *:443>
    ServerName example.com

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/cert.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem
    SSLCertificateChainFile /etc/letsencrypt/live/example.com/chain.pem

    # Modern SSL configuration
    SSLProtocol -all +TLSv1.2 +TLSv1.3
    SSLCipherSuite HIGH:!aNULL:!MD5

    ProxyPreserveHost On
    ProxyPass / http://backend/
    ProxyPassReverse / http://backend/
</VirtualHost>

# Redirect HTTP to HTTPS
<VirtualHost *:80>
    ServerName example.com
    Redirect permanent / https://example.com/
</VirtualHost>
```

### Step 4: Verify Installation

```bash
# Check certificate information
cert-info

# Check expiration dates
cert-check

# Verify SSL/TLS
openssl s_client -connect example.com:443

# Test with curl
curl -I https://example.com
```

## Certificate Types

### Single Domain

For a single domain (example.com):

```bash
certbot certonly --standalone --domains example.com
```

Certificate covers only `example.com`. Requests to `www.example.com` will fail SSL validation.

### Multiple Domains

For multiple specific domains:

```bash
certbot certonly --standalone \
  --domains example.com,www.example.com,api.example.com
```

All domains are in one certificate. Subject Alternative Names (SANs).

### Wildcard Certificate

For all subdomains (`*.example.com`):

```bash
# First configure DNS challenge
ansible-playbook infrastructure/certificates/configure_dns_challenge.ansible \
  -e dns_provider="digitalocean" \
  -e dns_api_token="your-token" \
  -e cert_domain="example.com"

# This creates certificate for:
# - example.com
# - *.example.com
# Covers all subdomains: api.example.com, www.example.com, etc.
```

**Note**: Wildcard certificates require DNS validation (ACME DNS challenge).

## Validation Methods

### HTTP Validation (Standalone)

Best for: Public domains with HTTP access

```bash
certbot certonly --standalone --domains example.com
```

Certbot:
1. Listens on port 80
2. Waits for Let's Encrypt to make HTTP request
3. Responds with validation token
4. Certificate issued

**Requirements**: Port 80 must be publicly accessible

### HTTP Validation (Webroot)

Best for: Existing web server (nginx, Apache)

```bash
certbot certonly --webroot \
  --webroot-path /var/www/html \
  --domains example.com
```

Certbot:
1. Places validation file in web root
2. Let's Encrypt accesses via http://example.com/.well-known/acme-challenge/
3. Certificate issued

**Requirements**: Web server already running and serving files

### DNS Validation

Best for: Wildcard certificates, private domains

```bash
ansible-playbook infrastructure/certificates/configure_dns_challenge.ansible \
  -e dns_provider="digitalocean" \
  -e dns_api_token="your-api-token" \
  -e cert_domain="example.com"
```

Certbot:
1. Creates TXT record in DNS zone
2. Let's Encrypt queries DNS for TXT record
3. Certificate issued
4. TXT record automatically deleted

**Requirements**: DNS API credentials for your provider

## Configuration

### Main Configuration File

Location: `/etc/letsencrypt/`

Key files:
- `live/` - Symlinks to current certificates
- `archive/` - Actual certificate files (numbered)
- `renewal/` - Renewal configurations per domain
- `renewal-hooks/post/` - Scripts to run after renewal

### Certificate File Locations

```
/etc/letsencrypt/live/example.com/
├── cert.pem              # Your certificate (public)
├── chain.pem             # CA's certificate chain
├── fullchain.pem         # cert.pem + chain.pem (recommended for web servers)
├── privkey.pem           # Your private key (SECRET - never share)
└── README               # File descriptions
```

**For web servers, use `fullchain.pem`**, not just `cert.pem`.

### Renewal Configuration

Each domain has renewal config:

```
/etc/letsencrypt/renewal/example.com.conf
```

Edit to add DNS challenge for renewal:

```ini
# For DigitalOcean DNS challenge
authenticator = dns-digitalocean
dns_digitalocean_credentials = /etc/letsencrypt/dns-digitalocean.ini
```

## Automatic Renewal

### Renewal Schedule

Certbot renewal runs automatically via systemd timer:

```bash
# Check renewal status
systemctl status certbot-renewal.timer

# View timer schedule
systemctl list-timers certbot-renewal.timer

# View renewal logs
journalctl -u certbot-renewal.service -f

# Manual renewal (checks all certificates)
certbot renew

# Dry run (test without making changes)
certbot renew --dry-run
```

### Renewal Hooks

Automatically restart services on certificate renewal:

Edit renewal hook scripts in `/etc/letsencrypt/renewal-hooks/post/`:

```bash
# /etc/letsencrypt/renewal-hooks/post/custom.sh
#!/bin/bash
echo "Certificate renewed, restarting services..."

# Restart Traefik
if systemctl is-active --quiet traefik; then
    systemctl restart traefik
fi

# Restart nginx
if systemctl is-active --quiet nginx; then
    systemctl restart nginx
fi

# Custom application restart
systemctl restart my-app
```

Make executable:

```bash
chmod +x /etc/letsencrypt/renewal-hooks/post/custom.sh
```

## Certificate Management

### View Certificate Information

```bash
# Display all certificates
cert-info

# Check specific certificate
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -text -noout

# Check expiration date
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -enddate

# Check certificate subject and SANs
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -subject -nameopt RFC2253
```

### Check Expiration Dates

```bash
# Check all certificates
cert-check

# Monitor with Nagios/Icinga
# Output exit codes: 0=OK, 1=warning, 2=critical
```

### Renew Before Expiration

```bash
# Manually renew certificate
certbot renew --cert-name example.com

# Force renewal (even if not near expiration)
certbot renew --cert-name example.com --force-renewal

# Renew with DNS challenge
certbot renew --dns-digitalocean \
  --dns-digitalocean-credentials /etc/letsencrypt/dns-digitalocean.ini
```

### Revoke Certificate

If private key is compromised:

```bash
# Revoke certificate
certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem

# Delete certificate locally
certbot delete --cert-name example.com
```

## DNS Challenge Setup

For wildcard certificates, configure DNS provider:

### DigitalOcean

1. Generate API token:
   - Dashboard → API → Tokens/Keys
   - Create new token with read/write scope

2. Configure Certbot:
   ```bash
   ansible-playbook infrastructure/certificates/configure_dns_challenge.ansible \
     -e dns_provider="digitalocean" \
     -e dns_api_token="your-api-token" \
     -e cert_domain="example.com"
   ```

3. Request wildcard certificate:
   ```bash
   certbot certonly --dns-digitalocean \
     --dns-digitalocean-credentials /etc/letsencrypt/dns-digitalocean.ini \
     --domains example.com,*.example.com
   ```

### Route 53 (AWS)

1. Create IAM user with Route53 permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "route53:GetChange",
           "route53:ChangeResourceRecordSets",
           "route53:ListResourceRecordSets"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

2. Configure Certbot:
   ```bash
   ansible-playbook infrastructure/certificates/configure_dns_challenge.ansible \
     -e dns_provider="route53" \
     -e dns_api_token="access-key:secret-key" \
     -e cert_domain="example.com"
   ```

### CloudFlare

1. Generate API token:
   - Dashboard → My Account → API Tokens
   - Create token with Zone:DNS:Edit permissions

2. Configure Certbot:
   ```bash
   ansible-playbook infrastructure/certificates/configure_dns_challenge.ansible \
     -e dns_provider="cloudflare" \
     -e dns_api_token="your-api-token" \
     -e cert_domain="example.com"
   ```

## Troubleshooting

### Certificate Not Renewing

```bash
# 1. Check renewal status
certbot renew --dry-run

# 2. Check renewal hook logs
journalctl -u certbot-renewal.service -n 50

# 3. Check renewal configuration
cat /etc/letsencrypt/renewal/example.com.conf

# 4. Manually trigger renewal with verbose output
certbot renew -vvv --cert-name example.com

# 5. Check systemd timer
systemctl status certbot-renewal.timer
journalctl -u certbot-renewal.service -f
```

### "Challenge Failed" Error

```bash
# 1. Verify domain points to server
nslookup example.com

# 2. Check if port 80 is accessible
nc -zv example.com 80

# 3. Check firewall rules
sudo ufw status
sudo iptables -L -n

# 4. Try with verbose output
certbot renew -vvv --cert-name example.com

# 5. Check Let's Encrypt logs
curl -X POST https://acme-v02.api.letsencrypt.org/acme/new-order \
  --json @order.json
```

### DNS Challenge Not Working

```bash
# 1. Verify DNS credentials
cat /etc/letsencrypt/dns-digitalocean.ini

# 2. Test DNS provider API
curl -X GET "https://api.digitalocean.com/v2/domains" \
  -H "Authorization: Bearer your-token"

# 3. Check DNS record propagation
dig example.com TXT

# 4. View renewal config
cat /etc/letsencrypt/renewal/example.com.conf

# 5. Manual test with dry-run
certbot renew --dns-digitalocean \
  --dns-digitalocean-credentials /etc/letsencrypt/dns-digitalocean.ini \
  --dry-run -vvv
```

### Port 80 Already in Use

If another service uses port 80, use webroot validation:

```bash
# Stop web server, get certificate, restart web server
systemctl stop nginx

certbot certonly --standalone --domains example.com

systemctl start nginx
```

Or use DNS validation:

```bash
ansible-playbook infrastructure/certificates/configure_dns_challenge.ansible \
  -e dns_provider="digitalocean" \
  -e dns_api_token="your-token" \
  -e cert_domain="example.com"
```

### Certificate Chain Issues

```bash
# Verify certificate chain
openssl verify -CAfile /etc/letsencrypt/live/example.com/chain.pem \
  /etc/letsencrypt/live/example.com/cert.pem

# Check full chain
openssl s_client -connect example.com:443 -showcerts

# Ensure web server uses fullchain.pem
# NOT just cert.pem
```

## Security Best Practices

### 1. Protect Private Key

```bash
# Private key permissions
ls -l /etc/letsencrypt/live/example.com/privkey.pem
# Should be: -rw-r--r-- (644) or -rw------- (600)

# Never share or copy without permission
# Never commit to version control
# Use .gitignore: /etc/letsencrypt/live/*/privkey.pem
```

### 2. Certificate Pinning

For critical services, pin certificate public key:

```bash
# Extract public key hash
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem \
  -noout -pubkey | \
  openssl rsa -pubin -outform DER | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64
```

### 3. Monitor Expiration

```bash
# Cron job to check expiration
0 3 * * * /usr/local/bin/cert-check || \
  echo "Certificate expiring soon" | mail admin@example.com
```

### 4. Backup Certificates

```bash
# Backup Let's Encrypt directory
tar -czf letsencrypt-backup-$(date +%Y%m%d).tar.gz \
  /etc/letsencrypt/

# Store in safe location
mv letsencrypt-backup-*.tar.gz /backup/
```

### 5. Use HSTS Header

```nginx
# nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

```apache
# Apache
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
```

## Integration with Services

### Consul Service Registration

```bash
curl -X PUT http://localhost:8500/v1/agent/service/register -d @- << EOF
{
  "ID": "https-service",
  "Name": "https-api",
  "Address": "example.com",
  "Port": 443,
  "Check": {
    "HTTPS": "https://example.com/health",
    "Interval": "10s",
    "TLSSkipVerify": false
  }
}
EOF
```

### Prometheus Monitoring

```yaml
# Scrape targets with HTTPS
scrape_configs:
  - job_name: 'api'
    scheme: https
    tls_config:
      ca_file: /etc/letsencrypt/live/example.com/chain.pem
    static_configs:
      - targets: ['example.com:443']
```

### Kubernetes Secrets

```bash
# Create Kubernetes secret from certificate
kubectl create secret tls example-com-tls \
  --cert=/etc/letsencrypt/live/example.com/fullchain.pem \
  --key=/etc/letsencrypt/live/example.com/privkey.pem \
  -n default
```

## Advanced Topics

### Certificate Transparency Logs

All Let's Encrypt certificates are logged in CT logs:

```bash
# Find certificate in CT logs
curl https://crt.sh/?q=example.com
```

### OCSP Stapling

Improve SSL/TLS handshake performance:

```nginx
# nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
```

### HTTP/2 Support

```nginx
# nginx
listen 443 ssl http2;
```

## Useful Commands Reference

```bash
# Certificate management
certbot certificates                     # List all certificates
certbot certonly --standalone            # Request new certificate
certbot renew                             # Renew all certificates
certbot revoke --cert-name example.com   # Revoke certificate
certbot delete --cert-name example.com   # Delete certificate

# Testing
certbot renew --dry-run                  # Test renewal
openssl s_client -connect example.com:443
curl -I https://example.com

# Monitoring
cert-info                                # Show all certificates
cert-check                               # Check expiration dates
systemctl status certbot-renewal.timer

# Debugging
certbot -vvv                             # Verbose output
certbot renew -vvv --cert-name example.com
journalctl -u certbot-renewal.service -f

# Logs
cat /var/log/letsencrypt/letsencrypt.log
journalctl -u certbot-renewal.service
```

## See Also

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [ACME Protocol Specification](https://tools.ietf.org/html/rfc8555)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [SSL Labs Best Practices](https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
