# Network Topology

## Network

- **Subnet:** 192.168.1.0/24
- **Domain (local):** local.infinity-node.win
- **Domain (external):** infinity-node.com via Pangolin tunnels

## Proxmox Host

| Host | IP | Role |
|------|----|------|
| infinity-node | 192.168.1.81 | Proxmox hypervisor |

## Virtual Machines

| VM ID | Name | IP | Purpose |
|-------|------|----|---------|
| 100 | emby | 192.168.1.100 | Media streaming (RTX 4060 Ti GPU passthrough) |
| 101 | downloads | 192.168.1.101 | NordVPN WireGuard + Deluge + NZBGet |
| 102 | arr | 192.168.1.102 | Radarr, Sonarr, Lidarr, Prowlarr, Jellyseerr |
| 103 | misc | 192.168.1.103 | General services (17+ containers) |
| 104 | openclaw | 192.168.1.104 | Provisioned, available |

## Infrastructure Services

| Service | IP | Role |
|---------|----|------|
| Pi-hole | 192.168.1.79 | DNS server / ad blocking |
| Synology NAS | 192.168.1.80 | NFS storage (57TB) |

## DNS Hostnames

All VMs are accessible via DNS:

- `vm-100.local.infinity-node.win` (emby)
- `vm-101.local.infinity-node.win` (downloads)
- `vm-102.local.infinity-node.win` (arr)
- `vm-103.local.infinity-node.win` (misc)
- `vm-104.local.infinity-node.win` (openclaw)

## External Access

External access is provided via Pangolin tunnels through `infinity-node.com` (Cloudflare DNS). Selected services are exposed through the tunnel server at 45.55.78.215.
