---
type: adr
number: 017
title: Use Terraform with bpg/proxmox for VM Provisioning
date: 2025-04-07
status: accepted
deciders:
  - Evan
tags:
  - adr
  - infrastructure
  - terraform
  - proxmox
---

# ADR-017: Use Terraform with bpg/proxmox for VM Provisioning

**Date:** 2025-04-07
**Status:** Accepted
**Deciders:** Evan

## Context

The original infinity-node infrastructure provisioned VMs using shell scripts that called the Proxmox API directly (`create-test-vm.sh`, `expand-vm-disk.sh`). While functional, this approach had limitations:

- **Not idempotent** — running a script twice could create duplicate VMs or fail unpredictably
- **No state tracking** — no record of what was provisioned vs. what should exist
- **Fragile** — API calls were hand-crafted with curl; error handling was minimal
- **No plan/preview** — changes were applied immediately with no dry-run capability
- **Hard to reproduce** — VM specs scattered across script arguments and comments

## Decision

Use Terraform with the `bpg/proxmox` provider (~0.66) for all VM provisioning. A reusable `proxmox-vm` module encapsulates VM creation with cloud-init support. Each Proxmox host gets its own Terraform workspace (`terraform/hel/`, `terraform/brain/`, etc.).

## Consequences

**Positive:**
- Idempotent — `terraform apply` converges to desired state
- State management — Terraform tracks what exists and what's planned
- Plan/apply workflow — preview changes before applying
- Reusable module — consistent VM configuration across all hosts
- Cloud-init support — VMs bootstrap themselves on first boot
- Declarative — VM specs are code, not script arguments

**Negative:**
- Learning curve for Terraform and HCL
- State file management (currently local, should move to remote backend)
- Provider version compatibility requires attention
- Proxmox API token required per host

**Neutral:**
- Separate workspace per Proxmox host keeps state isolated
- Terraform state is local per-workspace for now (RustFS on midgard available for remote backend)

## Alternatives Considered

1. **Shell scripts calling Proxmox API (status quo)**
   - Quick to write but fragile and not idempotent
   - Superseded by this decision

2. **Pulumi**
   - Similar to Terraform but uses general-purpose languages
   - Smaller community, fewer Proxmox provider options

3. **Ansible for provisioning**
   - Possible with `community.general.proxmox` module
   - Less suited for stateful infrastructure management than Terraform
   - Ansible used for post-provisioning configuration instead
