---
type: runbook
service: traefik
category: infrastructure
tags:
  - runbook
  - traefik
  - reverse-proxy
  - networking
---

# Traefik Management Runbook

**Service:** Traefik Reverse Proxy
**VMs:** 100, 101, 102, 103 (all VMs)
**Purpose:** Port-free service access via DNS names

## Quick Reference

### Access URLs

**Traefik Dashboard (per VM):**
- VM 100: http://192.168.1.100:8080 (direct access - dashboard not routed via Traefik)
- VM 101: http://192.168.1.101:8080 (direct access - dashboard not routed via Traefik)
- VM 102: http://192.168.1.102:8080 (direct access - dashboard not routed via Traefik)
- VM 103: http://192.168.1.103:8080 (direct access - dashboard not routed via Traefik)

**Service Access (Port-Free):**
- All services: `http://service-name.local.infinity-node.win`
- Examples: `http://vaultwarden.local.infinity-node.win`, `http://radarr.local.infinity-node.win`

### Stack Locations

```
stacks/traefik/
├── template/              # Base templates
├── vm-100/                # VM 100 configuration
├── vm-101/                # VM 101 configuration
├── vm-102/                # VM 102 configuration
└── vm-103/                # VM 103 configuration
```

## Common Tasks

### Adding a New Service to Traefik

**1. Update service docker-compose.yml:**

Add Traefik network to the service:

```yaml
services:
  service-name:
    networks:
      - default
      - traefik-network

networks:
  traefik-network:
    external: true
    name: traefik-network
```

**2. Add routing rule to `dynamic.yml`:**

Edit `stacks/traefik/vm-XXX/dynamic.yml`:

```yaml
http:
  routers:
    service-name:
      rule: "Host(`service-name.local.infinity-node.win`)"
      entryPoints:
        - web
      service: service-name

  services:
    service-name:
      loadBalancer:
        servers:
          - url: "http://container-name:port"
```

**Important:** Use the actual container name (check with `docker ps` on the VM).

**3. Commit and push:**

```bash
git add stacks/traefik/vm-XXX/dynamic.yml stacks/service-name/docker-compose.yml
git commit -m "feat(traefik): add service-name routing on VM XXX"
git push
```

**4. Redeploy:**

- **Traefik:** Portainer will auto-update via GitOps (5-minute polling) OR manually redeploy via Portainer UI
- **Service:** Redeploy service stack via Portainer to connect to traefik-network

**5. Verify:**

```bash
# Test routing
curl -H "Host: service-name.local.infinity-node.win" http://<vm-ip>/

# Check Traefik dashboard
curl http://<vm-ip>:8080/api/http/routers | jq '.[] | select(.name | contains("service-name"))'
```

### Removing a Service from Traefik

**1. Remove routing rule:**

Edit `stacks/traefik/vm-XXX/dynamic.yml` and remove the router and service entries.

**2. Commit and push:**

```bash
git add stacks/traefik/vm-XXX/dynamic.yml
git commit -m "feat(traefik): remove service-name routing on VM XXX"
git push
```

**3. Traefik auto-updates** (GitOps will pick up changes)

**4. Optional:** Remove traefik-network from service docker-compose.yml if no longer needed

### Updating Service Container Name or Port

**1. Update `dynamic.yml`:**

Edit the service URL in `stacks/traefik/vm-XXX/dynamic.yml`:

```yaml
services:
  service-name:
    loadBalancer:
      servers:
        - url: "http://new-container-name:new-port"
```

**2. Commit and push:**

```bash
git add stacks/traefik/vm-XXX/dynamic.yml
git commit -m "fix(traefik): update service-name container/port on VM XXX"
git push
```

**3. Traefik auto-updates** (GitOps)

### Checking Traefik Status

**On VM:**

```bash
# Check container status
docker ps | grep traefik

# Check health
docker inspect traefik | jq -r '.[0].State.Health.Status'

# View logs
docker logs traefik --tail 50

# Check routing configuration
curl -s http://localhost:8080/api/http/routers | jq -r '.[] | {name: .name, rule: .rule, status: .status}'

# Check services
curl -s http://localhost:8080/api/http/services | jq -r '.[] | {name: .name, servers: .servers}'
```

**From local machine:**

```bash
# Test service routing
curl -H "Host: service-name.local.infinity-node.win" http://<vm-ip>/

# Check Traefik API
curl http://<vm-ip>:8080/api/overview
```

### Troubleshooting

#### Service Returns 502 Bad Gateway

**Possible causes:**
1. Service not on traefik-network
2. Container name mismatch in dynamic.yml
3. Service not running
4. Port mismatch

**Fix:**

```bash
# 1. Check if service is on network
docker network inspect traefik-network | jq -r '.[0].Containers[] | .Name'

# 2. Verify container name
docker ps | grep service-name

# 3. Connect service to network if missing
docker network connect traefik-network service-name

# 4. Check dynamic.yml matches actual container name/port
cat stacks/traefik/vm-XXX/dynamic.yml | grep -A 3 "service-name:"
```

#### Service Returns 404 Not Found

**Possible causes:**
1. Router not configured in dynamic.yml
2. Host header mismatch
3. DNS not resolving correctly

**Fix:**

```bash
# 1. Check router exists
curl -s http://<vm-ip>:8080/api/http/routers | jq '.[] | select(.name | contains("service-name"))'

# 2. Verify DNS resolution
dig service-name.local.infinity-node.win

# 3. Check dynamic.yml router rule matches DNS name
cat stacks/traefik/vm-XXX/dynamic.yml | grep -A 5 "service-name:"
```

#### Traefik Container Restarting

**Possible causes:**
1. Configuration syntax error
2. Port conflict
3. Config files are directories (Portainer Git clone bug)

**Fix:**

```bash
# 1. Check logs
docker logs traefik --tail 100

# 2. Validate configuration syntax
docker compose -f /data/compose/<stack-id>/stacks/traefik/vm-XXX/docker-compose.yml config

# 3. Check port availability
ss -tuln | grep -E ':(80|443)'

# 4. Fix Portainer Git clone issue (if config files are directories)
./scripts/infrastructure/fix-traefik-config-files.sh <vm-ip> <stack-id>
```

#### Portainer Git Clone Issue (Files as Directories)

**Symptom:** Traefik fails with "is a directory" error

**Fix:**

```bash
# Run fix script
./scripts/infrastructure/fix-traefik-config-files.sh <vm-ip> [stack-id]

# Script will:
# 1. Find Traefik stack directory
# 2. Remove incorrect directories
# 3. Clone fresh repo and copy correct files
# 4. Restart Traefik container
```

### Special Configurations

#### VM 100: Emby (Host Network Mode)

Emby uses `network_mode: host`, so Traefik routes via Docker bridge gateway:

```yaml
services:
  emby:
    loadBalancer:
      servers:
        - url: "http://172.17.0.1:8096"  # Docker bridge gateway IP
```

#### VM 101: Download Clients (VPN Network Mode)

Download clients use `network_mode: service:vpn`, so Traefik routes to VPN container ports:

```yaml
services:
  deluge:
    loadBalancer:
      servers:
        - url: "http://172.17.0.1:8112"  # VPN container exposes port 8112
```

### Redeploying Traefik Stack

**Via Portainer UI:**
1. Navigate to Stacks → traefik
2. Click "Pull and redeploy"
3. Verify container restarts successfully

**Via Portainer API:**

```bash
# Get stack ID
export BW_SESSION=$(cat ~/.bw-session)
TOKEN=$(./scripts/secrets/get-vw-secret.sh "portainer-api-token-vm-XXX" "shared")
URL=$(./scripts/secrets/get-vw-secret.sh "portainer-api-token-vm-XXX" "shared" "url")
STACK_ID=$(curl -sk -H "X-API-Key: $TOKEN" "$URL/api/stacks" | jq -r '.[] | select(.Name == "traefik") | .Id')

# Redeploy
curl -sk -X POST \
  -H "X-API-Key: $TOKEN" \
  "$URL/api/stacks/$STACK_ID/git/redeploy?endpointId=3"
```

### Monitoring

**Check Traefik logs:**

```bash
# Real-time logs
docker logs -f traefik

# Last 100 lines
docker logs traefik --tail 100

# Filter for errors
docker logs traefik 2>&1 | grep -i error
```

**Check routing activity:**

```bash
# View access logs (if enabled)
docker logs traefik 2>&1 | grep "RequestAddr"

# Check API for active routers
curl -s http://localhost:8080/api/http/routers | jq '.[] | select(.status == "enabled")'
```

### Backup and Recovery

**Backup configuration:**

```bash
# Backup all Traefik configs
tar -czf traefik-backup-$(date +%Y%m%d).tar.gz stacks/traefik/

# Configuration is already in git, but this provides local backup
```

**Recovery:**

1. Configuration is in git - just redeploy stack
2. If Portainer stack deleted, recreate:
   ```bash
   ./scripts/infrastructure/create-git-stack.sh \
     "portainer-api-token-vm-XXX" \
     "shared" \
     3 \
     "traefik" \
     "stacks/traefik/vm-XXX/docker-compose.yml"
   ```
3. Run fix script to ensure config files are correct:
   ```bash
   ./scripts/infrastructure/fix-traefik-config-files.sh <vm-ip> <stack-id>
   ```

## Related Documentation

- [[stacks/traefik/README|Traefik Stack Documentation]]
- [[docs/ARCHITECTURE|Infrastructure Architecture]]
- [[config/dns-records.json|DNS Records Configuration]]
