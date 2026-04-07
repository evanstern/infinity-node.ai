---
type: documentation
service: emby
category: security
priority: critical
tags:
  - emby
  - security
  - external-access
---

# Emby External Access Security Summary

**Purpose:** Security overview for exposing Emby directly to internet via port forwarding.

## Security Layers

### Layer 1: Network Security

**Port Forwarding:**
- Only port 443 (HTTPS) exposed externally
- All traffic encrypted via TLS
- No other ports exposed

**Firewall (UFW):**
- Blocks unauthorized access attempts
- Allows only necessary ports
- fail2ban integration for automatic IP blocking

**Network Isolation:**
- Emby VM isolated from critical infrastructure
- NAS access limited to read-only mounts
- No direct network access to other VMs

### Layer 2: Application Security

**Emby Authentication:**
- Strong password requirements
- User-based access control
- Admin account protection
- Login attempt logging

**HTTPS/TLS:**
- SSL certificate (Let's Encrypt)
- Required for all remote connections
- Encrypts all traffic
- Prevents man-in-the-middle attacks

**Rate Limiting:**
- fail2ban prevents brute force attacks
- Automatic IP blocking after failed attempts
- Configurable thresholds

### Layer 3: Monitoring & Detection

**fail2ban:**
- Monitors Emby logs for failed logins
- Automatically bans IPs after 5 failed attempts
- 1-hour ban duration (configurable)
- Logs all ban actions

**Log Monitoring:**
- Regular review of access logs
- Alert on suspicious activity
- Track failed login attempts
- Monitor for unknown IPs

**Access Auditing:**
- Review user activity regularly
- Check for unauthorized access
- Monitor concurrent connections
- Review user permissions

## Security Measures

### Required

1. **fail2ban** - Brute force protection
2. **HTTPS/TLS** - Encrypted connections
3. **Strong Passwords** - Minimum 12 characters
4. **Firewall** - UFW rules configured
5. **Regular Updates** - Emby and system updates
6. **Log Monitoring** - Regular log reviews

### Recommended

1. **IP Allowlisting** - If you have static IPs
2. **Reverse Proxy** - Additional security layer
3. **2FA** - If Emby supports it
4. **Network Segmentation** - Isolate Emby VM further
5. **Intrusion Detection** - Advanced monitoring

### Optional

1. **VPN Access** - For additional security
2. **Geoblocking** - Block certain countries
3. **Rate Limiting** - Per-IP connection limits
4. **DDoS Protection** - Cloudflare or similar

## Risk Assessment

### High Risk Areas

1. **Brute Force Attacks**
   - **Mitigation:** fail2ban with aggressive settings
   - **Monitoring:** Regular log reviews

2. **Emby Vulnerabilities**
   - **Mitigation:** Regular updates, security patches
   - **Monitoring:** Security advisories

3. **Weak Passwords**
   - **Mitigation:** Strong password requirements
   - **Monitoring:** Regular password audits

### Medium Risk Areas

1. **DDoS Attacks**
   - **Mitigation:** Rate limiting, Cloudflare
   - **Monitoring:** Traffic monitoring

2. **Unauthorized Access**
   - **Mitigation:** Strong authentication, monitoring
   - **Monitoring:** Access logs, user activity

### Low Risk Areas

1. **Network Access** (if Emby compromised)
   - **Mitigation:** Network isolation, firewall rules
   - **Monitoring:** Network traffic monitoring

## Security Best Practices

### Before Going Live

1. ✅ Test all security measures
2. ✅ Verify fail2ban is working
3. ✅ Test SSL certificate
4. ✅ Review firewall rules
5. ✅ Set strong passwords
6. ✅ Configure monitoring

### Ongoing Maintenance

1. **Weekly:**
   - Review access logs
   - Check fail2ban status
   - Review user activity

2. **Monthly:**
   - Security audit
   - Password review
   - Update review

3. **Quarterly:**
   - Full security review
   - Penetration testing (if possible)
   - Documentation update

### Incident Response

1. **Detect:** Monitor logs, alerts
2. **Respond:** Block IPs, investigate
3. **Recover:** Unban legitimate users
4. **Review:** Analyze attack, improve security

## Comparison: Pangolin vs Port Forwarding

### Pangolin (Current)

**Security:**
- ✅ No direct exposure
- ✅ Authentication layer
- ✅ Hidden IP address
- ❌ Blocks Emby Connect
- ❌ Blocks TV apps

**Complexity:**
- ✅ No router config
- ✅ Works with dynamic IP
- ❌ Requires external server
- ❌ Additional service to maintain

### Port Forwarding (Proposed)

**Security:**
- ⚠️ Direct exposure
- ✅ fail2ban protection
- ✅ HTTPS encryption
- ✅ Emby authentication
- ✅ Works with Emby Connect
- ✅ Works with TV apps

**Complexity:**
- ❌ Router configuration
- ❌ DDNS required
- ✅ No external server
- ✅ Simpler architecture

## Recommendations

### For Maximum Security

1. **Use Port Forwarding** for Emby (required for TV apps)
2. **Keep Pangolin** for other services (arr, misc)
3. **Implement All Security Layers** (fail2ban, HTTPS, firewall)
4. **Monitor Regularly** (logs, access, attacks)
5. **Update Frequently** (Emby, system, security patches)

### Alternative: Hybrid Approach

- **Emby:** Port forwarding (for TV apps)
- **Other Services:** Pangolin (with authentication)
- **Best of Both:** Security where needed, compatibility where required

## Conclusion

Port forwarding with proper security measures is acceptable for exposing Emby, especially when TV app compatibility is required. The multiple security layers (fail2ban, HTTPS, firewall, monitoring) provide strong protection against common attacks.

**Key Points:**
- Multiple security layers are essential
- fail2ban is critical for brute force protection
- HTTPS is required for all connections
- Regular monitoring is necessary
- Updates are important for security

**Next Steps:**
1. Review full security runbook
2. Set up fail2ban
3. Configure SSL certificate
4. Test all security measures
5. Go live with monitoring

## Related Documentation

- [[docs/runbooks/emby-external-access-security|Full Security Runbook]]
- [[docs/runbooks/emby-port-forwarding-quick-reference|Quick Reference]]
- [[stacks/emby/README|Emby Stack Documentation]]
