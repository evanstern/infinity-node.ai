---
type: runbook
service: emby
category: networking
priority: critical
tags:
  - emby
  - port-forwarding
  - quick-reference
---

# Emby Port Forwarding Quick Reference

**Quick setup guide for exposing Emby via port forwarding with security.**

## Quick Setup Checklist

### 1. Router Configuration (Google Nest WiFi)

**Via Google Home App:**
1. Open Google Home app
2. WiFi → Advanced Networking → Port Management
3. Add port forwarding rule:
   - **Name:** Emby HTTPS
   - **External Port:** 443
   - **Internal IP:** 192.168.1.100
   - **Internal Port:** 8096
   - **Protocol:** TCP

**Note:** If port 443 is blocked, use 8443 or another port.

### 2. DDNS Configuration

**Option A: Cloudflare DNS (Recommended)**
- Use Cloudflare API to update A record
- Script: `scripts/security/update-cloudflare-dns.sh` (to be created)
- Updates `emby.infinity-node.com` → Public IP

**Option B: Router DDNS**
- Configure in router settings
- Provider: DuckDNS, No-IP, etc.
- Domain: `emby.infinity-node.com`

### 3. SSL Certificate

```bash
# On VM 100
sudo certbot certonly --standalone -d emby.infinity-node.com

# Convert to PFX
sudo openssl pkcs12 -export \
  -out /path/to/emby-certificate.pfx \
  -inkey /etc/letsencrypt/live/emby.infinity-node.com/privkey.pem \
  -in /etc/letsencrypt/live/emby.infinity-node.com/fullchain.pem \
  -passout pass:YOUR_PASSWORD
```

### 4. Emby Configuration

**Network Settings:**
- External domain: `emby.infinity-node.com`
- Public HTTPS port: 443
- Custom SSL certificate: `/path/to/emby-certificate.pfx`
- Secure connection mode: "Required for all remote connections"
- Allow remote connections: Enabled

### 5. fail2ban Setup

```bash
# Run setup script
sudo ./scripts/security/setup-emby-fail2ban.sh

# Or manually configure (see full runbook)
```

### 6. Firewall (UFW)

```bash
sudo ufw allow 443/tcp
sudo ufw allow from 192.168.1.0/24 to any port 8096
sudo ufw allow from 192.168.1.0/24 to any port 8920
sudo ufw enable
```

## Testing

1. **Test External Access:**
   ```bash
   curl -I https://emby.infinity-node.com
   ```

2. **Test Emby Connect:**
   - Go to app.emby.media
   - Add server: `emby.infinity-node.com` (no port)
   - Should connect successfully

3. **Test TV Apps:**
   - Roku: Add server via Emby Connect
   - Apple TV: Add server via Emby Connect
   - Firestick: Add server via Emby Connect

4. **Test fail2ban:**
   ```bash
   sudo fail2ban-client status emby
   ```

## Security Checklist

- [ ] Port forwarding configured
- [ ] DDNS updating correctly
- [ ] SSL certificate installed and valid
- [ ] Emby HTTPS required for remote
- [ ] fail2ban installed and active
- [ ] Firewall rules configured
- [ ] Strong passwords on all accounts
- [ ] Test external access
- [ ] Test Emby Connect
- [ ] Monitor logs for attacks

## Troubleshooting

**Emby Connect not working:**
- Check port forwarding is active
- Verify DDNS is updating
- Test direct IP access
- Check Emby logs

**fail2ban not working:**
- Verify log path is correct
- Check fail2ban service status
- Test filter regex
- Review fail2ban logs

**SSL certificate issues:**
- Check certificate expiration
- Verify PFX password
- Test certificate renewal

## Router Migration

When changing routers:

1. Document current port forwarding rules
2. Configure new router with same rules
3. Test DDNS still works
4. Verify external access
5. Update documentation

## Related Documentation

- [[docs/runbooks/emby-external-access-security|Full Security Runbook]]
- [[stacks/emby/README|Emby Stack Documentation]]
