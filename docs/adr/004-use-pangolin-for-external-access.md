---
type: adr
number: 004
title: Use Pangolin for External Access
date: 2025-10-24
status: accepted
deciders:
  - Evan
tags:
  - adr
  - networking
  - security
  - pangolin
  - tunnel
---

# ADR-004: Use Pangolin for External Access

**Date:** 2025-10-24 (retroactive documentation)
**Status:** Accepted
**Deciders:** Evan

## Context
Need secure external access to services without:
- Opening ports on home router
- Exposing services directly to internet
- Complex VPN setup for each user
- Dynamic DNS management

## Decision
Use Pangolin (self-hosted) for tunnel-based external access.

## Consequences

**Positive:**
- No port forwarding required
- Identity-aware access control
- Self-hosted (control and privacy)
- Supports multiple services/sites
- TLS termination handled
- Works through restrictive firewalls

**Negative:**
- Requires external server (Digital Ocean)
- Additional cost for external server
- Another service to maintain
- Newt client on each VM that needs external access

**Neutral:**
- Similar to Cloudflare Tunnel but self-hosted
- Requires domain and DNS management

## Alternatives Considered

1. **Cloudflare Tunnel**
   - Easier setup
   - Less control
   - Privacy concerns (traffic through Cloudflare)
   - Vendor lock-in

2. **VPN (WireGuard/OpenVPN)**
   - More traditional approach
   - Each user needs VPN config
   - More complex for family members
   - Better for full network access

3. **Reverse Proxy + Port Forward**
   - Simpler architecture
   - Exposes home IP
   - Port forwarding complexity
   - Security concerns

4. **Tailscale**
   - Very easy to use
   - Service-dependent
   - Less control over infrastructure
