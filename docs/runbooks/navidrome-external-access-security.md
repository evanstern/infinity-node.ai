---
type: runbook
service: navidrome
category: security
priority: high
tags:
  - navidrome
  - security
  - fail2ban
  - vm-103
  - external-access
created: 2025-11-13
updated: 2025-11-13
---

# Navidrome External Access Security

**Status:** ACTIVE – fail2ban protections enabled ahead of public exposure.

**Purpose:** Document the configuration and operational procedures that harden Navidrome when the service becomes directly reachable from the internet. This complements the Traefik configuration and ensures repeatable recovery steps if fail2ban triggers.

## Components

| Component | Location | Notes |
|-----------|----------|-------|
| Fail2ban stack | `stacks/fail2ban/docker-compose.yml` | LinuxServer.io image with host networking and `NET_ADMIN`/`NET_RAW`. |
| Traefik access log | `/home/evan/logs/traefik/access.log` | Mounted read-only into fail2ban for router-level bans. |
| Navidrome auth log | `/home/evan/data/navidrome/logs/navidrome.log` | Produced by `navidrome-start.sh` wrapper; used for direct-port bans. |
| Configuration | `stacks/fail2ban/config/{jail.d,filter.d}` | Git-managed jails/filters for Navidrome. |

## Deployment Checklist

1. Ensure host directories exist:
   ```bash
   sudo mkdir -p /home/evan/logs/traefik
   sudo mkdir -p /home/evan/data/navidrome/logs
   sudo chown -R evan:evan /home/evan/logs/traefik /home/evan/data/navidrome/logs
   ```
2. Copy `.env.example` to `.env` under `stacks/fail2ban/` and confirm log paths are accurate.
3. Copy the Navidrome start wrapper from the repo to the host path used in the stack:
   ```bash
   sudo install -o evan -g evan -m 0755 stacks/navidrome/start.sh /home/evan/scripts/navidrome-start.sh
   ```
4. Trigger Portainer “Pull and redeploy” for the `navidrome` and `fail2ban` stacks.
5. Verify the container is healthy:
   ```bash
   docker ps | grep fail2ban
   docker exec fail2ban fail2ban-client status
   ```

## Validation

- **Regex sanity check**
  ```bash
  docker exec fail2ban fail2ban-regex /remotelogs/traefik/access.log /config/filter.d/navidrome-traefik.conf
  docker exec fail2ban fail2ban-regex /remotelogs/navidrome/navidrome.log /config/filter.d/navidrome-auth.conf
  ```
- **Simulated failures** – Attempt ≥5 bad logins via Traefik-reached URL and watch `fail2ban-client status navidrome-traefik`.
- **Ban confirmation** – From banned IP, confirm curl/browser access is blocked (timeout or 403).

## Operations

| Task | Command |
|------|---------|
| Show active jails | `docker exec fail2ban fail2ban-client status` |
| Inspect Navidrome jail | `docker exec fail2ban fail2ban-client status navidrome-traefik` |
| Unban specific IP | `docker exec fail2ban fail2ban-client set navidrome-traefik unbanip <IP>` |
| Whitelist trusted subnet | Add CIDR to `ignoreip` (create `/config/jail.local`) and redeploy stack |
| View fail2ban log | `docker exec fail2ban tail -f /config/log/fail2ban.log` |

## Alerting & Monitoring

- Track ban counts periodically (`fail2ban-client status navidrome-traefik` → `Currently banned`).
- Proposed enhancement: integrate ban notifications with existing monitoring (Grafana/Telegram) once alerting workflow is defined.

## Rollback

1. Disable stack via Portainer (“Stop stack”).
2. Flush residual chains if needed:
   ```bash
   sudo iptables -F DOCKER-USER
   sudo iptables -F f2b-navidrome-traefik
   sudo iptables -X f2b-navidrome-traefik
   ```
3. Restore previous Traefik/Navidrome configs from git if log routing needs to revert.

## References

- [[stacks/fail2ban/README|Fail2ban Stack]]
- [[stacks/navidrome/README|Navidrome Stack]]
- [[stacks/traefik/vm-103/README|Traefik VM-103 Stack]]
- https://docs.linuxserver.io/images/docker-fail2ban/
- https://github.com/linuxserver/fail2ban-confs
