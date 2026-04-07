---
type: adr
number: 007
title: Dedicated VM with VPN for Downloads
date: 2025-10-24
status: accepted
deciders:
  - Evan
tags:
  - adr
  - networking
  - security
  - vpn
  - downloads
---

# ADR-007: Dedicated VM with VPN for Downloads

**Date:** 2025-10-24 (retroactive documentation)
**Status:** Accepted
**Deciders:** Evan

## Context
Download clients (torrents/usenet) should use VPN for:
- Privacy
- Avoiding ISP throttling
- Protecting home IP

Other services should NOT use VPN to:
- Avoid latency for streaming
- Allow direct access for management
- Prevent VPN failures from affecting everything

## Decision
Dedicated VM (101) for download clients with VPN container routing all traffic.

## Consequences

**Positive:**
- Download traffic protected by VPN
- Other services unaffected by VPN
- Kill switch prevents leaks
- Can troubleshoot VPN without affecting critical services
- VPN failure only affects downloads

**Negative:**
- Dedicated VM for relatively few services
- VPN adds latency to downloads
- More complex network setup

**Neutral:**
- Could use VPN at router level (affects everything)
- Could use split-tunnel VPN (more complex)

## Alternatives Considered

1. **VPN on router**
   - All traffic routed through VPN
   - Affects streaming and management
   - Single point of failure

2. **Per-container VPN**
   - Each download client manages own VPN
   - More complex
   - Redundant VPN connections

3. **No VPN**
   - Simpler
   - Privacy concerns
   - ISP may throttle
