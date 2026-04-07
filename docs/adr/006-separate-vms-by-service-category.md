---
type: adr
number: 006
title: Separate VMs by Service Category
date: 2025-10-24
status: accepted
deciders:
  - Evan
tags:
  - adr
  - infrastructure
  - virtualization
  - architecture
---

# ADR-006: Separate VMs by Service Category

**Date:** 2025-10-24 (retroactive documentation)
**Status:** Accepted
**Deciders:** Evan

## Context
Multiple services needed. Choices:
- All services on one VM
- One VM per service
- Group services logically

## Decision
Group services into VMs by category/purpose:
- VM 100: Media server (Emby)
- VM 101: Download clients with VPN
- VM 102: Media automation (*arr)
- VM 103: Supporting services

## Consequences

**Positive:**
- Logical grouping
- Resource allocation per category
- Isolation between categories
- Can restart/maintain VMs independently
- VPN only affects download VM
- Blast radius contained

**Negative:**
- More VMs to manage
- More resource overhead (4 OS instances)
- Network between VMs for communication
- SSH into correct VM needed

**Neutral:**
- Balance between isolation and complexity
- Could be more or less granular

## Alternatives Considered

1. **Single mega VM**
   - Simpler management
   - Single point of failure
   - Resource contention
   - VPN would affect everything

2. **One VM per service**
   - Maximum isolation
   - Too many VMs to manage
   - Excessive resource overhead

3. **Different grouping**
   - Many ways to group services
   - Current grouping works well
