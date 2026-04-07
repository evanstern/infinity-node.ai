---
type: runbook
service: emby
category: security
priority: critical
tags:
  - emby
  - security
  - port-forwarding
  - fail2ban
  - external-access
---

# Emby External Access Security Configuration

**Status:** DRAFT - Security plan for exposing Emby via port forwarding

**Purpose:** Secure configuration for exposing Emby server directly to internet via port forwarding, enabling Emby Connect and TV app compatibility.

## Security Overview

Exposing Emby directly to the internet requires multiple layers of security:

1. **Network Layer:** Firewall rules, port restrictions
2. **Application Layer:** Emby authentication, HTTPS, rate limiting
3. **Monitoring Layer:** fail2ban, log monitoring, intrusion detection
4. **Access Control:** Strong passwords, user permissions, IP allowlisting (optional)

## Threat Model

**Risks:**
- Brute force attacks on Emby login
- Exploitation of Emby vulnerabilities
- Unauthorized access to media library
- Potential network access if Emby is compromised
- DDoS/abuse of server resources

**Mitigations:**
- fail2ban for brute force protection
- HTTPS encryption
- Strong authentication
- Regular updates
- Network isolation where possible
- Monitoring and alerting

## Prerequisites

- Router with port forwarding capability
- DDNS service account (if no static IP)
- Domain name (infinity-node.com already owned)
- SSL certificate (Let's Encrypt recommended)
- Access to router admin interface

## Configuration Steps

### Phase 1: Network Configuration

#### 1.1 Router Port Forwarding

**Google Nest WiFi Configuration:**
- Access: Google Home app → WiFi → Advanced Networking → Port Management
- Create port forwarding rule:
  - **Name:** Emby HTTPS
  - **External Port:** 443 (HTTPS) or 8096 (HTTP)
  - **Internal IP:** 192.168.1.100
  - **Internal Port:** 8096
  - **Protocol:** TCP

**Note:** Google Nest WiFi has limited port forwarding options. Consider:
- Using non-standard external port (e.g., 8443) if 443 is blocked
- Upgrading router for better control (future)

**Future Router Migration:**
- Document port forwarding rules
- Test after router change
- Update DDNS if needed

#### 1.2 DDNS Configuration

**Option A: Router-Based DDNS (Preferred)**
- Configure DDNS in router settings
- Provider: DuckDNS, No-IP, Dynu, etc.
- Update interval: Every 5 minutes
- Domain: `emby.infinity-node.com` (or subdomain)

**Option B: Client-Based DDNS**
- Run DDNS client on VM 100 or Proxmox host
- Update script runs via cron
- More reliable than router-based

**Cloudflare DDNS (Recommended):**
- Use Cloudflare API for DNS updates
- Script on VM 100 updates A record
- More reliable than traditional DDNS

#### 1.3 DNS Configuration

**Cloudflare DNS:**
- Create A record: `emby.infinity-node.com` → Public IP
- Or use DDNS to update automatically
- TTL: 300 seconds (5 minutes) for faster updates

### Phase 2: SSL/TLS Configuration

#### 2.1 Obtain SSL Certificate

**Let's Encrypt via Certbot:**
```bash
# Install certbot on VM 100
sudo apt update
sudo apt install certbot

# Obtain certificate (DNS challenge recommended)
sudo certbot certonly --manual --preferred-challenges dns \
  -d emby.infinity-node.com

# Or use HTTP challenge if port 80 is accessible
sudo certbot certonly --standalone -d emby.infinity-node.com
```

**Convert to PFX Format (Emby requires):**
```bash
# Convert certificate to PFX
sudo openssl pkcs12 -export \
  -out /path/to/emby-certificate.pfx \
  -inkey /etc/letsencrypt/live/emby.infinity-node.com/privkey.pem \
  -in /etc/letsencrypt/live/emby.infinity-node.com/fullchain.pem \
  -passout pass:YOUR_PFX_PASSWORD

# Set permissions
sudo chmod 600 /path/to/emby-certificate.pfx
sudo chown evan:evan /path/to/emby-certificate.pfx
```

#### 2.2 Configure Emby SSL

**Emby Network Settings:**
- **Custom SSL certificate path:** `/path/to/emby-certificate.pfx`
- **Certificate password:** (from PFX creation)
- **Public HTTPS port number:** 443
- **Secure connection mode:** "Required for all remote connections"
- **External domain:** `emby.infinity-node.com`

**Auto-Renewal:**
- Set up certbot renewal cron job
- Script to convert renewed cert to PFX
- Restart Emby after renewal (or use webhook)

### Phase 3: fail2ban Configuration

#### 3.1 Install fail2ban

```bash
# On VM 100
sudo apt update
sudo apt install fail2ban
```

#### 3.2 Configure Emby Jail

**Create `/etc/fail2ban/jail.d/emby.conf`:**
```ini
[emby]
enabled = true
port = 8096,8920
filter = emby
logpath = /path/to/emby/logs/server-*.txt
maxretry = 5
findtime = 600
bantime = 3600
action = iptables[name=Emby, port=8096, protocol=tcp]
```

**Create `/etc/fail2ban/filter.d/emby.conf`:**
```ini
[Definition]
failregex = ^.*Authentication request for <HOST>.*has been denied.*$
            ^.*Authentication request for .* from <HOST>.*has been denied.*$
ignoreregex =
```

**Note:** Adjust logpath to match your Emby log location (check Emby config directory).

#### 3.3 Test fail2ban

```bash
# Check fail2ban status
sudo fail2ban-client status emby

# Test filter
sudo fail2ban-regex /path/to/emby/logs/server-*.txt /etc/fail2ban/filter.d/emby.conf

# Manually ban/unban for testing
sudo fail2ban-client set emby banip <IP>
sudo fail2ban-client set emby unbanip <IP>
```

### Phase 4: Additional Security Measures

#### 4.1 Firewall Configuration (VM 100)

**UFW Rules:**
```bash
# Allow SSH (already configured)
sudo ufw allow 22/tcp

# Allow Emby HTTP/HTTPS from local network only
sudo ufw allow from 192.168.1.0/24 to any port 8096
sudo ufw allow from 192.168.1.0/24 to any port 8920

# Allow Emby HTTPS from internet (port forwarding)
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
sudo ufw status verbose
```

**Note:** Port forwarding handles external access, but UFW adds defense-in-depth.

#### 4.2 Emby Security Settings

**User Management:**
- Strong passwords required (minimum 12 characters)
- Enable password complexity requirements
- Regular password rotation
- Disable unused accounts
- Limit admin accounts

**Network Settings:**
- **Allow remote connections:** Enabled
- **Require HTTPS:** Yes (for remote connections)
- **Remote IP address filters:** Optional - allowlist known IPs if possible
- **Enable automatic port mapping:** Disabled (manual port forwarding)

**Security Settings:**
- Hide admin account from login screen (if supported)
- Enable login attempt logging
- Review access logs regularly

#### 4.3 Rate Limiting (Optional)

**Nginx Reverse Proxy (Advanced):**
- Deploy Nginx in front of Emby
- Configure rate limiting
- Additional security headers
- SSL termination at Nginx

**Benefits:**
- Rate limiting per IP
- Additional security headers
- Better DDoS protection
- Can hide Emby version

**Trade-offs:**
- Additional service to maintain
- More complex setup
- May interfere with Emby features

### Phase 5: Monitoring & Alerting

#### 5.1 Log Monitoring

**Monitor Emby Logs:**
```bash
# Watch for failed login attempts
tail -f /path/to/emby/logs/server-*.txt | grep -i "denied\|failed\|error"

# Check fail2ban logs
sudo tail -f /var/log/fail2ban.log | grep emby
```

**Automated Monitoring:**
- Set up logwatch or similar
- Email alerts for suspicious activity
- Regular security audits

#### 5.2 Access Monitoring

**Review Regularly:**
- Emby dashboard → Users → Activity
- Check for unknown IP addresses
- Review failed login attempts
- Monitor concurrent connections

#### 5.3 fail2ban Monitoring

**Check Status:**
```bash
# View banned IPs
sudo fail2ban-client status emby

# View detailed status
sudo fail2ban-client status emby -v
```

**Alerting:**
- Set up email notifications for bans
- Monitor ban frequency
- Investigate repeated attacks

## Security Checklist

### Before Going Live

- [ ] Port forwarding configured correctly
- [ ] DDNS configured and tested
- [ ] SSL certificate installed and valid
- [ ] Emby HTTPS configured and required
- [ ] fail2ban installed and configured
- [ ] Firewall rules configured
- [ ] Strong passwords set for all users
- [ ] Admin account secured
- [ ] Log monitoring set up
- [ ] Test external access from different network
- [ ] Test Emby Connect connection
- [ ] Test TV apps (Roku, Apple TV, etc.)
- [ ] Verify fail2ban is working
- [ ] Document all configurations

### Ongoing Maintenance

- [ ] Weekly: Review access logs
- [ ] Weekly: Check fail2ban status
- [ ] Monthly: Review user accounts
- [ ] Monthly: Check SSL certificate expiration
- [ ] Quarterly: Security audit
- [ ] Immediately: Update Emby on security releases
- [ ] Immediately: Investigate suspicious activity

## Troubleshooting

### Emby Connect Not Working

1. Verify port forwarding is active
2. Check DDNS is updating correctly
3. Test direct IP access
4. Check Emby logs for connection attempts
5. Verify SSL certificate is valid
6. Check firewall rules

### fail2ban Not Working

1. Verify logpath matches Emby log location
2. Test filter regex with fail2ban-regex
3. Check fail2ban service status
4. Review fail2ban logs for errors
5. Verify iptables rules are being created

### SSL Certificate Issues

1. Verify certificate is valid: `openssl x509 -in cert.pem -text -noout`
2. Check certificate expiration
3. Verify PFX password is correct
4. Check file permissions
5. Test certificate renewal process

## Migration Notes

### When Changing Routers

1. Document current port forwarding rules
2. Test DDNS update mechanism
3. Configure new router port forwarding
4. Verify external access still works
5. Update documentation with new router details

### When Moving Locations

1. Update DDNS configuration
2. Update Cloudflare DNS if needed
3. Test port forwarding on new network
4. Verify ISP doesn't block ports
5. Update firewall rules if network changes

## Related Documentation

- [[stacks/emby/README|Emby Stack Documentation]]
- [[docs/ARCHITECTURE|Infrastructure Architecture]]
- [[docs/agents/SECURITY|Security Agent]]
- [[docs/adr/004-use-pangolin-for-external-access|ADR-004: Pangolin]]

## Security Considerations

**Important:** This configuration exposes Emby directly to the internet. While we implement multiple security layers, risks remain:

- **Attack Surface:** Direct exposure increases attack surface
- **Brute Force:** Automated attacks are common
- **Vulnerabilities:** Emby vulnerabilities could be exploited
- **Network Access:** If Emby is compromised, network access may be possible

**Mitigations:**
- Multiple security layers (fail2ban, firewall, HTTPS)
- Regular updates
- Strong authentication
- Monitoring and alerting
- Network isolation where possible

**Alternative:** Consider keeping Pangolin for other services and only exposing Emby directly, or implementing a reverse proxy with additional security features.
