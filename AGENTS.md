# infinity-node.ai

## Mission

Rewrite the **infinity-node** homelab infrastructure into a hybrid of two existing systems:

1. **infinity-node** (old) — `https://github.com/evanstern/infinity-node` (the original repo)
2. **devops/master** (new) — `/home/coda/projects/devops/master` (the current IaC repo on this machine)

The result should take the best of both: devops/master's infrastructure primitives with infinity-node's operational maturity.

---

## Context: The Two Systems

### System 1: infinity-node (Old)

**Repo**: https://github.com/evanstern/infinity-node
**Languages**: Shell (90%), Python (10%)
**Deployment model**: Portainer GitOps — stacks polled from Git every 5 minutes
**Provisioning**: Shell scripts calling Proxmox API directly
**Config management**: Ansible (skeleton only — structure defined, barely used)
**Secrets**: Vaultwarden + Bitwarden CLI + `.env` files deployed to VMs
**Docs**: Massive — 796-line ARCHITECTURE.md, 14 ADRs, 8 runbooks, 6 AI agent specs, Obsidian vault

#### Infrastructure Topology (Old)

```
Proxmox Host: infinity-node (192.168.1.81)
├── VM 100 (emby)      — Media streaming, NVIDIA RTX 4060 Ti GPU passthrough, tmpfs transcode cache
├── VM 101 (downloads)  — NordVPN WireGuard tunnel + Deluge + NZBGet (VPN kill switch via shared network namespace)
├── VM 102 (arr)        — Radarr, Sonarr, Lidarr, Prowlarr, Jellyseerr, Flaresolverr, Huntarr
└── VM 103 (misc)       — Everything else (17+ services)

Storage: local 100GB + local-lvm 1.8TB + Synology NAS 57TB NFS (192.168.1.80)
Network: 192.168.1.0/24, Pi-hole at 192.168.1.79, domain: local.infinity-node.win
External access: Pangolin tunnels (45.55.78.215), domain: infinity-node.com via Cloudflare
```

#### Services (39 Docker Compose stacks)

**Critical (household impact)**:
- Emby — media streaming with hardware transcoding (RTX 4060 Ti, 4.08x realtime 1080p, <10% CPU)
- Radarr/Sonarr/Lidarr/Prowlarr — media automation pipeline
- Jellyseerr — media request interface
- Deluge + NZBGet — torrent/usenet with VPN kill switch

**Important (personal use)**:
- Vaultwarden — password manager (centralized secret source of truth)
- Paperless-NGX — document management
- Immich — photo library
- Navidrome — music streaming
- Audiobookshelf — audiobooks/podcasts
- Kavita/Komga — comics/ebooks
- Calibre — ebook management
- MyBibliotheca — book tracking
- Linkwarden — bookmark manager
- N8N — workflow automation
- Actual Budget — personal finance
- Homepage — dashboard
- Forgejo — self-hosted Git
- Cookcli — recipe management
- Booklore — book metadata
- Fail2ban — intrusion prevention
- Mylar3/LazyLibrarian — comic/book automation

**Per-VM infrastructure**:
- Traefik — one instance per VM for reverse proxy + TLS
- Watchtower — auto-update containers (risky pattern — replaced by DIUN in new repo)

#### Operational Scripts (41 total)

**Infrastructure**: `create-test-vm.sh`, `expand-vm-disk.sh`, `check-proxmox-resources.sh`, `create-git-stack.sh`, `query-portainer-stacks.sh`, `update-stack-env.sh`
**Secrets**: `create-secret.sh`, `get-vw-secret.sh`, `audit-secrets.sh`
**Backup**: `backup-vaultwarden.sh`, Calibre/MyBibliotheca backups
**Tasks**: MDTD lifecycle management scripts
**Utilities**: Music library organization, Bitwarden CLI setup, disk space monitoring

#### Documentation

- `docs/ARCHITECTURE.md` — 796 lines, complete topology with network diagrams
- `docs/adr/` — 14 Architectural Decision Records
- `docs/runbooks/` — 8 operational procedures (VM recovery, service rebuilds)
- `docs/agents/` — 6 AI agent specs (Testing, Docker, Infrastructure, Security, Media, Documentation)
- `docs/services/` — per-service documentation
- `CLAUDE.md` — 180 lines, AI assistant safety rules and workflows
- `.cursorrules` — 316 lines, Cursor IDE config with agent system
- `tasks/` — MDTD task system (62 completed, 2 active, 11 backlog)

#### Unique Patterns Worth Preserving

1. **GPU hardware transcoding** — RTX 4060 Ti passthrough to Emby VM, tmpfs 4GB RAM transcode cache
2. **VPN kill switch** — downloads containers share VPN container's network namespace; VPN down = downloads stop
3. **Pangolin external access** — tunnel server for selective external service exposure
4. **Comprehensive ADRs** — 14 decision records capturing the *why* behind choices
5. **Runbooks** — step-by-step operational procedures
6. **Pi-hole DNS config** — `config/dns-records.json` with all local DNS entries

---

### System 2: devops/master (New)

**Location**: `/home/coda/projects/devops/master`
**Languages**: YAML/HCL (Terraform + Ansible)
**Deployment model**: Ansible pushes compose files to hosts via SSH, runs `docker compose up -d`
**Provisioning**: Terraform with bpg/proxmox provider, reusable module
**Config management**: Ansible — proper inventory, roles, playbooks, host_vars
**Secrets**: Vaultwarden + Bitwarden CLI + Ansible `community.general.bitwarden` lookup plugin (zero secrets on disk)
**Docs**: Lean design specs and server notes

#### Infrastructure Topology (New)

```
Proxmox Servers (5 total, 2 in IaC):
  hel (192.168.8.37)     — Primary, 10 VMs
  brain (192.168.8.10)   — Secondary, 1 VM (traefik)
  casper (192.168.8.17)  — NOT in IaC yet
  balthasar (192.168.8.18) — NOT in IaC yet
  melchior (192.168.8.19)  — NOT in IaC yet

VMs on hel:
  asgaard (192.168.8.42)    — Portainer, paperless, nextcloud, immich, homarr, heimdall, influxdb, grafana, registry, n8n, firefly, code-server, servatrice, audiobookshelf (17 containers)
  wukong (192.168.8.50)     — sonarr, radarr, prowlarr, jellyseerr
  tyr (192.168.8.51)        — byparr, lidarr
  brokkr (192.168.8.20)     — tdarr
  midgard (192.168.8.41)    — TrueNAS VM + RustFS (S3-compatible on :9000)
  haos (192.168.8.210)      — Home Assistant OS
  amp (192.168.8.29)        — AMP game servers
  openclaw (192.168.8.36)   — Provisioned, empty
  matrix (192.168.8.38)     — Matrix Synapse
  vaultwarden (192.168.8.16) — Vaultwarden password manager

VMs on brain:
  traefik (192.168.8.11) — Reverse proxy + wildcard TLS (*.local.fuku.cloud via Cloudflare DNS challenge)

Bare metal:
  karn (192.168.8.200)  — TrueNAS bare metal NAS
  loki (192.168.8.45)   — GPU box (ollama, fooocus, Grafana Loki)
  sai (192.168.8.34)    — Ubuntu (emby)
  freyr (192.168.8.31)  — Ubuntu (nzbget, deluge)

Network: 192.168.8.0/24, Pi-hole x2 (192.168.8.7, .8), domain: *.local.fuku.cloud
DNS: Traefik wildcard cert via Cloudflare DNS challenge
```

#### Repository Layout

```
devops/master/
├── terraform/
│   ├── modules/proxmox-vm/   — Reusable VM module (cloud-init, bpg/proxmox ~0.66)
│   ├── hel/                  — Main Proxmox workspace
│   └── brain/                — Secondary Proxmox workspace
├── ansible/
│   ├── inventory/
│   │   ├── hosts.yml          — Groups: proxmox, bare_metal, vms, docker_hosts, api_only, truenas
│   │   ├── host_vars/         — Per-host vars for 15+ hosts
│   │   └── group_vars/docker_hosts/
│   ├── playbooks/
│   │   ├── provision-vm.yml   — Post-Terraform VM bootstrap
│   │   ├── configure-server.yml — Baseline config for any host
│   │   └── deploy-service.yml — Push compose file + docker compose up -d
│   ├── roles/
│   │   ├── common/            — All Linux hosts
│   │   ├── docker/            — Docker install + config
│   │   ├── truenas/           — REST API management (no SSH)
│   │   └── homeassistant/     — HA REST API management
│   └── templates/
├── services/                  — services/<host>/<service>/docker-compose.yml (42 files across 12 hosts)
├── scripts/
│   ├── bw-run.sh              — Wraps any command with Bitwarden session
│   └── bw-unlock.sh           — Unlock Bitwarden vault
├── notes/servers/             — Per-host markdown notes (IPs, specs, services)
├── notes/network.md           — Complete IP map and DNS entries
└── docs/superpowers/          — Design specs and plans
```

#### Key Ansible Groups

```yaml
docker_hosts: traefik, asgaard, wukong, tyr, brokkr, amp, openclaw, matrix, vaultwarden, freyr, loki, sai
api_only: haos, karn, midgard  # No SSH — REST API only
truenas: karn, midgard
```

#### Secrets Pipeline

All secrets in Vaultwarden (`vault.local.fuku.cloud`), fetched at runtime:
- **Terraform**: `bw-run.sh` exports `TF_VAR_*` env vars from Vaultwarden items
- **Ansible**: `community.general.bitwarden` lookup plugin fetches per-play
- **Vaultwarden items**: `hel-proxmox`, `brain-proxmox`, `rustfs-s3`, `homeassistant`, `truenas-karn`, `diun-gotify`, `vaultwarden-rustfs`
- **Terraform state**: Local per-workspace (hel/, brain/). RustFS on midgard available for remote backend but not yet wired.

#### What's Good

1. **Predictable layout** — `services/<host>/<service>/docker-compose.yml`, always
2. **Secrets never on disk** — bw lookup at runtime, no `.env` files
3. **Terraform VM module** — reusable, clean, cloud-init based
4. **Ansible roles** — common, docker, truenas, homeassistant are real and used
5. **DIUN everywhere** — image update notifications (safer than Watchtower auto-update)
6. **API-only hosts** — TrueNAS and HAOS correctly managed via REST API

#### What's Missing

1. **Pi-hole not managed** — no Ansible role, no config versioning
2. **3 of 5 Proxmox hosts not in IaC** — casper, balthasar, melchior
3. **No CI/CD** — all manual
4. **Terraform state local** — RustFS available but not wired
5. **No monitoring IaC** — Grafana/InfluxDB exist but are GUI-configured
6. **No backup strategy in code**
7. **No operational scripts** (only bw-run.sh and bw-unlock.sh)
8. **Documentation sparse** — server notes mostly TODO stubs
9. **No external access strategy**

---

## Evaluation Summary: What Each System Wins

### infinity-node Wins

| Area | Detail |
|------|--------|
| Documentation | 796-line architecture doc, 14 ADRs, 8 runbooks, 6 agent specs vs. sparse TODOs |
| Operational scripts | 41 battle-tested scripts vs. 2 |
| GPU transcoding | RTX 4060 Ti passthrough + tmpfs cache — documented and tuned |
| VPN kill switch | Network namespace sharing pattern — proven |
| Backup automation | Vaultwarden backup script + Calibre/book backups |
| Task tracking | MDTD system with 62 completed tasks and lessons learned |
| External access | Pangolin tunnel architecture |
| Pi-hole management | `config/dns-records.json` |
| Secret auditing | `audit-secrets.sh` scans for hardcoded secrets |

### devops/master Wins

| Area | Detail |
|------|--------|
| VM provisioning | Terraform module with bpg/proxmox, cloud-init, proper state |
| Config management | Ansible actually used — roles, playbooks, inventory, host_vars |
| Secrets | Zero-on-disk via Ansible bitwarden lookup plugin |
| Service isolation | Dedicated VMs per workload vs. 4-VM model |
| Multi-host Terraform | Separate workspaces per Proxmox host, ready for expansion |
| Image updates | DIUN (notify) is safer than Watchtower (auto-update) |
| Service layout | `services/<host>/<service>/` convention is clean and predictable |

---

## Instructions for the Next Agent

### Phase 1: Re-evaluate Both Systems

Before writing any code, clone and read both repositories in full:

1. **Clone infinity-node**: `git clone https://github.com/evanstern/infinity-node /tmp/infinity-node`
2. **Read devops/master**: it's at `/home/coda/projects/devops/master`
3. **Verify the analysis above** — read the actual files, don't trust this summary blindly. Confirm:
   - The 39 stacks in infinity-node and what each does
   - The 42 compose files in devops/master and what each does
   - The Ansible roles/playbooks in devops/master and their maturity
   - The operational scripts in infinity-node and which are still relevant
   - The documentation in both repos
4. **Produce your own evaluation** of each system's strengths and weaknesses. Compare against the analysis above. Note any discrepancies.

### Phase 2: Design the Hybrid

The hybrid should use:

**From devops/master (infrastructure primitives)**:
- Terraform for VM provisioning (reusable proxmox-vm module)
- Ansible for configuration management and service deployment
- `services/<host>/<service>/docker-compose.yml` layout
- Bitwarden lookup plugin for zero-secrets-on-disk
- DIUN for image update notifications
- Ansible inventory groups (docker_hosts, api_only, truenas)

**From infinity-node (operational maturity)**:
- Comprehensive documentation structure (ARCHITECTURE.md pattern, ADRs, runbooks)
- Operational scripts (adapt the relevant ones — VM disk expansion, resource checking, secret auditing, backups)
- VPN kill switch pattern for download services
- GPU transcoding documentation
- Backup automation (expand beyond Vaultwarden to cover Nextcloud, Paperless, Immich, etc.)
- Pi-hole management (Ansible role + DNS config)

**New additions (gaps in both)**:
- Remote Terraform state backend (RustFS on midgard is already available)
- Monitoring/alerting as code (Grafana dashboards, InfluxDB data sources, alert rules)
- CI/CD pipeline for stack validation
- Disaster recovery runbook
- Remaining Proxmox hosts in IaC (casper, balthasar, melchior)

### Phase 3: Build It

The target repo structure:

```
infinity-node.ai/
├── AGENTS.md                    # This file
├── terraform/
│   ├── modules/proxmox-vm/      # From devops/master
│   ├── hel/
│   ├── brain/
│   ├── casper/                   # NEW
│   ├── balthasar/                # NEW
│   └── melchior/                 # NEW
├── ansible/
│   ├── inventory/
│   │   ├── hosts.yml
│   │   ├── host_vars/
│   │   └── group_vars/
│   ├── playbooks/
│   │   ├── provision-vm.yml
│   │   ├── configure-server.yml
│   │   ├── deploy-service.yml
│   │   └── backup.yml            # NEW
│   ├── roles/
│   │   ├── common/
│   │   ├── docker/
│   │   ├── truenas/
│   │   ├── homeassistant/
│   │   ├── pihole/               # NEW — from infinity-node dns config
│   │   └── monitoring/           # NEW
│   └── templates/
├── services/                     # Merged from both repos, deduplicated
│   ├── <host>/<service>/docker-compose.yml
│   └── ...
├── scripts/
│   ├── bw-run.sh                 # From devops/master
│   ├── bw-unlock.sh              # From devops/master
│   ├── expand-vm-disk.sh         # From infinity-node (adapted)
│   ├── check-proxmox-resources.sh # From infinity-node (adapted)
│   ├── audit-secrets.sh          # From infinity-node (adapted)
│   ├── backup-vaultwarden.sh     # From infinity-node (adapted)
│   └── ...
├── docs/
│   ├── ARCHITECTURE.md           # Rewritten for hybrid topology
│   ├── SECRET-MANAGEMENT.md      # From devops/master (it's good)
│   ├── adr/                      # Migrated from infinity-node + new decisions
│   ├── runbooks/                 # Migrated from infinity-node + new procedures
│   └── services/                 # Per-service documentation
├── notes/
│   ├── servers/                  # Per-host notes (from devops/master, fleshed out)
│   └── network.md                # From devops/master
└── config/
    └── dns-records.json          # From infinity-node
```

### Key Decisions to Make (ask the user)

1. **Which services survive the merge?** Both repos have overlapping services (emby, arr stack, vaultwarden, paperless, immich, etc.) but on different hosts/IPs. The new repo's topology is the target — map infinity-node services onto it.
2. **Portainer: keep or drop?** devops/master uses Ansible push. infinity-node uses Portainer GitOps. Pick one.
3. **External access**: Pangolin tunnels from infinity-node, or different approach?
4. **Monitoring stack**: Grafana + InfluxDB (exists on asgaard) or Prometheus-based?
5. **NAS topology**: Two NAS (karn bare metal + midgard VM) or consolidate?

### Constraints

- The target infrastructure is the **devops/master topology** (192.168.8.0/24 network, hel/brain Proxmox, etc.)
- Do NOT change the network layout, IPs, or VM assignments
- Do NOT commit secrets, `.env` files, tfstate, or API tokens
- Prefer Ansible bitwarden lookup over `.env` files on disk
- Prefer DIUN over Watchtower
- All compose files under `services/<host>/<service>/docker-compose.yml` — no exceptions
