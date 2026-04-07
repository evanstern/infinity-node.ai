---
type: adr
number: 002
title: Use Docker for Service Containerization
date: 2025-10-24
status: accepted
deciders:
  - Evan
tags:
  - adr
  - docker
  - containerization
  - infrastructure
---

# ADR-002: Use Docker for Service Containerization

**Date:** 2025-10-24 (retroactive documentation)
**Status:** Accepted
**Deciders:** Evan

## Context
Need to run multiple services efficiently with:
- Isolation between services
- Easy updates and rollbacks
- Reproducible deployments
- Resource management
- Port management

## Decision
Use Docker with docker-compose for all services.

## Consequences

**Positive:**
- Huge ecosystem of pre-built images
- Easy to update services
- Isolation between services
- Reproducible deployments
- Good documentation and community
- docker-compose makes multi-container apps easy

**Negative:**
- Another layer of complexity
- Networking can be tricky
- Storage/volume management requires understanding
- Security requires attention (container escape risks)
- Resource overhead vs bare metal

**Neutral:**
- Requires learning Docker concepts
- Alternative to VMs for isolation

## Alternatives Considered

1. **Kubernetes**
   - Over-engineered for single-host setup
   - Much steeper learning curve
   - Better for multi-host clusters

2. **LXC Containers**
   - Proxmox has good LXC support
   - Less ecosystem than Docker
   - Different isolation model

3. **Bare metal services**
   - No isolation
   - Harder to manage dependencies
   - Harder to update/rollback
   - Port conflicts
