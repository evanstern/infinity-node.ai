---
type: adr
number: 001
title: Use Proxmox as Hypervisor
date: 2025-10-24
status: accepted
deciders:
  - Evan
tags:
  - adr
  - infrastructure
  - virtualization
  - proxmox
---

# ADR-001: Use Proxmox as Hypervisor

**Date:** 2025-10-24 (retroactive documentation)
**Status:** Accepted
**Deciders:** Evan

## Context
Need a hypervisor for running multiple VMs on a single physical server. Requirements:
- Mature and stable
- Web-based management
- Good community support
- Support for various storage types
- Free/open source

## Decision
Use Proxmox VE as the hypervisor platform.

## Consequences

**Positive:**
- Excellent web UI for management
- Strong community and documentation
- Built-in backup capabilities
- Supports various storage backends (local, NFS, etc.)
- Free and open source
- Easy VM creation and management
- Built-in console access

**Negative:**
- Learning curve for Proxmox-specific concepts
- Some features only in paid "enterprise" version
- Updates can occasionally require attention

**Neutral:**
- Debian-based (familiar to some, not to others)
- Uses its own clustering approach

## Alternatives Considered

1. **ESXi (VMware)**
   - More enterprise-focused
   - Free version very limited
   - VMware's future uncertain after Broadcom acquisition

2. **Hyper-V**
   - Windows-based
   - Good integration with Windows ecosystem
   - Less familiar for Linux-focused workloads

3. **KVM/libvirt directly**
   - More flexible
   - No web UI without additional tools
   - More manual management
