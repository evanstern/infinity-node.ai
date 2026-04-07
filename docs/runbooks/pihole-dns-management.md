---
type: runbook
tags:
  - dns
  - pihole
  - infrastructure
  - network
---
# Pi-hole DNS Management Runbook

## Overview

This runbook documents the Pi-hole DNS configuration and management for the infinity-node infrastructure. Pi-hole provides local DNS service discovery using the `local.infinity-node.win` domain, enabling services to be accessed by name instead of IP addresses.

**Last Updated:** 2025-11-08
**Task Reference:** IN-034

---

## Quick Reference

### Pi-hole Access

- **Web Admin:** http://192.168.1.79/admin/ or https://192.168.1.79/admin/
- **DNS Server:** 192.168.1.79 (port 53)
- **Credentials:** Stored in Vaultwarden (`shared/pihole-admin`)
- **MAC Address:** dc:a6:32:27:bf:eb (for DHCP reservation)

### DNS Domain

- **Local Domain:** `local.infinity-node.win`
- **Expand Hostnames:** Enabled (allows short names like `vm-100` to work with domain suffix)
- **Naming Pattern:** `<service>.local.infinity-node.win`

### DNS Record Management

**Manual Entry (Web UI):**
1. Access Pi-hole admin: http://192.168.1.79/admin/
2. Navigate to: **Local DNS → DNS Records**
3. Add record: Hostname → IP address
4. Short names work automatically (e.g., `vm-100` resolves to `vm-100.local.infinity-node.win`)

**Automated Management (Future):**
- Config file: `config/dns-records.json`
- Script: `scripts/infrastructure/manage-pihole-dns.sh`
- **Status:** Script created but Pi-hole API has issues - manual entry currently used

---

## Infrastructure Details

### Pi-hole Hardware

- **Device:** Raspberry Pi
- **IP Address:** 192.168.1.79 (static reservation)
- **MAC Address:** dc:a6:32:27:bf:eb
- **Hostname:** raspberrypi.lan
- **Version:** Pi-hole v6.1 (as of 2025-11-08)

### Network Configuration

**Router Settings:**
- **Primary DNS:** 192.168.1.79 (Pi-hole)
- **Secondary DNS:** 1.1.1.1 (Cloudflare - failover)
- **DHCP Reservation:** Static IP for Pi-hole MAC address

**DNS Resolution Flow:**
```
Client Request (e.g., vm-100.local.infinity-node.win)
    ↓
Router (DHCP provides Pi-hole as DNS)
    ↓
Pi-hole DNS Server (192.168.1.79:53)
    ├── Local domain? → Answer from local records
    └── Public domain? → Forward to Cloudflare (1.1.1.1)
```

---

## DNS Records

### VM Records

All VMs have DNS records for direct access:

| Hostname | IP Address | VM |
|----------|------------|-----|
| `vm-100.local.infinity-node.win` | 192.168.1.100 | emby |
| `vm-101.local.infinity-node.win` | 192.168.1.101 | downloads |
| `vm-102.local.infinity-node.win` | 192.168.1.102 | arr |
| `vm-103.local.infinity-node.win` | 192.168.1.103 | misc |

**Note:** With "Expand hostnames" enabled, short names (`vm-100`) automatically resolve to full FQDNs.

### Service Records

All services have DNS records for direct access. See `config/dns-records.json` for complete list.

**VM 100 (emby) Services:**
- `emby.local.infinity-node.win` → 192.168.1.100
- `portainer-100.local.infinity-node.win` → 192.168.1.100
- `tdarr.local.infinity-node.win` → 192.168.1.100

**VM 101 (downloads) Services:**
- `portainer-101.local.infinity-node.win` → 192.168.1.101
- `deluge.local.infinity-node.win` → 192.168.1.101
- `nzbget.local.infinity-node.win` → 192.168.1.101

**VM 102 (arr) Services:**
- `portainer-102.local.infinity-node.win` → 192.168.1.102
- `radarr.local.infinity-node.win` → 192.168.1.102
- `sonarr.local.infinity-node.win` → 192.168.1.102
- `prowlarr.local.infinity-node.win` → 192.168.1.102
- `lidarr.local.infinity-node.win` → 192.168.1.102
- `jellyseerr.local.infinity-node.win` → 192.168.1.102
- `huntarr.local.infinity-node.win` → 192.168.1.102
- `flaresolverr.local.infinity-node.win` → 192.168.1.102

**VM 103 (misc) Services:**
- `portainer-103.local.infinity-node.win` → 192.168.1.103
- `vaultwarden.local.infinity-node.win` → 192.168.1.103
- `audiobookshelf.local.infinity-node.win` → 192.168.1.103
- `paperless.local.infinity-node.win` → 192.168.1.103
- `immich.local.infinity-node.win` → 192.168.1.103
- `linkwarden.local.infinity-node.win` → 192.168.1.103
- `navidrome.local.infinity-node.win` → 192.168.1.103
- `homepage.local.infinity-node.win` → 192.168.1.103
- `mybibliotheca.local.infinity-node.win` → 192.168.1.103
- `calibre.local.infinity-node.win` → 192.168.1.103

**Total:** 28 DNS records (4 VMs + 24 services)

---

## DNS Naming Convention

### Pattern

```
<service-name>.local.infinity-node.win
```

### Examples

- **VM records:** `vm-100.local.infinity-node.win`, `vm-101.local.infinity-node.win`
- **Service records:** `emby.local.infinity-node.win`, `vaultwarden.local.infinity-node.win`
- **Portainer records:** `portainer-100.local.infinity-node.win` (includes VM number for uniqueness)

### Short Names

With "Expand hostnames" enabled in Pi-hole:
- Short name: `vm-100` → Resolves to: `vm-100.local.infinity-node.win`
- Short name: `emby` → Resolves to: `emby.local.infinity-node.win`

**Note:** Short names only work when the local domain is configured and "Expand hostnames" is enabled.

---

## Adding New DNS Records

### Method 1: Manual Entry (Web UI)

1. **Access Pi-hole Admin:**
   - Navigate to: http://192.168.1.79/admin/
   - Login with credentials from Vaultwarden (`shared/pihole-admin`)

2. **Navigate to DNS Records:**
   - Go to: **Local DNS → DNS Records**

3. **Add Record:**
   - Click **Add** button
   - Enter **Domain** (short name, e.g., `new-service`)
   - Enter **IP Address** (e.g., `192.168.1.103`)
   - Click **Save**

4. **Verify:**
   ```bash
   dig +short new-service.local.infinity-node.win
   # Should return: 192.168.1.103
   ```

### Method 2: Automated Script (Future)

**Status:** Script exists (`scripts/infrastructure/manage-pihole-dns.sh`) but Pi-hole API has issues. Manual entry currently used.

**When working:**
1. Update `config/dns-records.json` with new record
2. Run sync script:
   ```bash
   ./scripts/infrastructure/manage-pihole-dns.sh --dry-run  # Preview changes
   ./scripts/infrastructure/manage-pihole-dns.sh            # Apply changes
   ```

---

## Service Migration Process

When migrating a service from IP addresses to DNS names:

### Step 1: Create DNS Record

Add DNS record in Pi-hole (see "Adding New DNS Records" above).

### Step 2: Update Service Configuration

**For docker-compose.yml:**
- Replace hardcoded IPs with DNS names in environment variables
- Update any service-to-service communication URLs
- Add comments documenting DNS migration

**For README.md:**
- Replace IP addresses in access URLs
- Update documentation examples
- Note DNS name in service overview

**Example:**
```yaml
# Before
environment:
  - VAULTWARDEN_URL=http://vaultwarden.local.infinity-node.win:8111

# After
environment:
  - VAULTWARDEN_URL=http://vaultwarden.local.infinity-node.win:8111
```

### Step 3: Verify DNS Resolution

```bash
# Test DNS resolution
dig +short service-name.local.infinity-node.win

# Test HTTP access
curl -I http://service-name.local.infinity-node.win:PORT
```

### Step 4: Redeploy Service

**Via Portainer:**
1. Access Portainer on the VM
2. Navigate to the service stack
3. Use "Pull and redeploy" to get updated config from git
4. Monitor deployment logs

**Via Script:**
```bash
./scripts/infrastructure/redeploy-git-stack.sh \
  --secret "portainer-api-token-vm-XXX" \
  --stack-name "SERVICE-NAME"
```

### Step 5: Test Service Access

- Access service via DNS name in browser
- Verify all functionality works
- Check service logs for any DNS-related errors

---

## DNS Port Limitation

**Important:** DNS A records only contain IP addresses. Ports are not part of DNS resolution.

### Current Approach

Services accessed with port numbers:
- `http://emby.local.infinity-node.win:8096`
- `http://vaultwarden.local.infinity-node.win:8111`

### Future Approach (Traefik Reverse Proxy)

When Traefik is deployed (task IN-046), services can be accessed without ports:
- `http://emby.local.infinity-node.win` (Traefik routes by hostname)
- `https://vaultwarden.local.infinity-node.win` (TLS termination)

**Note:** Service-level DNS records are still useful even with reverse proxy:
- Direct access for debugging
- Monitoring and health checks
- Service-to-service communication
- Bypassing reverse proxy when needed

---

## Troubleshooting

### DNS Not Resolving

**Check DNS server:**
```bash
# Verify Pi-hole is responding
dig @192.168.1.79 vm-100.local.infinity-node.win

# Check local DNS resolution
dig vm-100.local.infinity-node.win
```

**Check router DNS settings:**
- Verify router DHCP provides Pi-hole (192.168.1.79) as primary DNS
- Verify secondary DNS is set (1.1.1.1 for failover)

**Check Pi-hole status:**
- Access Pi-hole admin dashboard
- Check query log for DNS requests
- Verify local domain is configured (`local.infinity-node.win`)

### Public DNS Not Working

**Check failover:**
```bash
# Test public DNS resolution
dig google.com @1.1.1.1

# If Pi-hole is down, clients should use Cloudflare (1.1.1.1)
```

**Verify router DNS settings:**
- Primary: 192.168.1.79 (Pi-hole)
- Secondary: 1.1.1.1 (Cloudflare)

### DNS Changes Not Taking Effect

**Clear DNS cache:**
```bash
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

**Wait for DHCP lease renewal:**
- DNS changes propagate via DHCP
- May take up to DHCP lease time (typically 24 hours)
- Can force renewal by disconnecting/reconnecting network

### Pi-hole Unreachable

**Check network connectivity:**
```bash
ping 192.168.1.79
```

**Check static IP reservation:**
- Verify router has DHCP reservation for Pi-hole MAC (dc:a6:32:27:bf:eb)
- Verify reservation points to 192.168.1.79

**Check Pi-hole hardware:**
- Verify Raspberry Pi is powered on
- Check network cable connection
- May need physical access to Pi-hole device

---

## Verification Commands

### Test DNS Resolution

```bash
# Test VM records
for vm in vm-100 vm-101 vm-102 vm-103; do
  echo "$vm.local.infinity-node.win -> $(dig +short ${vm}.local.infinity-node.win)"
done

# Test service records
dig +short emby.local.infinity-node.win
dig +short vaultwarden.local.infinity-node.win
dig +short audiobookshelf.local.infinity-node.win
```

### Test HTTP Access

```bash
# Test service accessibility
curl -I http://audiobookshelf.local.infinity-node.win:13378
curl -I http://vaultwarden.local.infinity-node.win:8111
```

### Check Pi-hole Query Log

1. Access Pi-hole admin: http://192.168.1.79/admin/
2. Navigate to: **Query Log**
3. Filter by domain: `local.infinity-node.win`
4. Verify local domain queries are being answered by Pi-hole (not forwarded)

---

## Related Documentation

- [[ARCHITECTURE|Infrastructure Architecture]] - Complete infrastructure overview
- [[SECRET-MANAGEMENT|Secret Management]] - Pi-hole credentials storage
- `config/dns-records.json` - Version-controlled DNS record configuration
- `scripts/infrastructure/manage-pihole-dns.sh` - Automated DNS record management script

---

## Change Log

| Date | Change | Reference |
|------|--------|-----------|
| 2025-11-08 | Initial DNS configuration and documentation | IN-034 |

---

**Note:** This runbook should be updated whenever DNS configuration changes or new services are added.
