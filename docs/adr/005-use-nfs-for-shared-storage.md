---
type: adr
number: 005
title: Use NFS for Shared Storage
date: 2025-10-24
status: accepted
deciders:
  - Evan
tags:
  - adr
  - storage
  - nfs
  - nas
  - infrastructure
---

# ADR-005: Use NFS for Shared Storage

**Date:** 2025-10-24 (retroactive documentation)
**Status:** Accepted
**Deciders:** Evan

## Context
Need shared storage accessible from:
- Proxmox (for VM disks)
- Multiple VMs (for media library)
- Services (for configs and data)

Synology NAS already available on network.

## Decision
Use NFS from Synology NAS for shared storage across infrastructure.

## Consequences

**Positive:**
- Centralized storage management
- Large capacity (57TB)
- Synology handles RAID/redundancy
- Easy to expand
- Accessible from all VMs
- NAS handles backups

**Negative:**
- Network latency vs local storage
- Single point of failure
- NFS performance lower than local disk
- Network dependency

**Neutral:**
- NFS vs SMB/CIFS (chose NFS for Linux VMs)
- Could use iSCSI for better performance

## Alternatives Considered

1. **Local storage only**
   - Better performance
   - No central management
   - Harder to backup
   - Limited by single host capacity

2. **Ceph/Distributed storage**
   - Over-engineered for single host
   - Requires multiple nodes
   - More complex

3. **SMB/CIFS**
   - Alternative network protocol
   - NFS generally better for Linux
   - More overhead
