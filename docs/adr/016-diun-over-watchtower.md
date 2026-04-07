---
type: adr
number: 016
title: Use DIUN for Image Update Notifications Instead of Watchtower
date: 2025-04-07
status: accepted
deciders:
  - Evan
tags:
  - adr
  - infrastructure
  - docker
  - updates
---

# ADR-016: Use DIUN for Image Update Notifications Instead of Watchtower

**Date:** 2025-04-07
**Status:** Accepted
**Deciders:** Evan

## Context

The original infinity-node infrastructure used Watchtower to automatically update running Docker containers when new images were available. While convenient, this caused problems:

- **Unexpected breaking changes** — containers updated to incompatible versions without warning
- **No rollback awareness** — updates happened silently; failures were discovered after the fact
- **Data migration risks** — database-backed services (Paperless, Immich, Vaultwarden) could auto-update to versions requiring manual migration steps
- **No operator control** — updates happened on Watchtower's schedule, not the operator's

## Decision

Use DIUN (Docker Image Update Notifier) to monitor for available image updates and send notifications via Gotify. The operator reviews notifications and decides when to update each service.

## Consequences

**Positive:**
- Operator retains full control over when updates are applied
- Notifications via Gotify provide awareness without forced action
- No risk of silent breaking changes or failed data migrations
- Can batch updates during maintenance windows
- DIUN is lightweight and runs as a single container per host

**Negative:**
- Updates require manual action (pull + recreate)
- Operator must monitor Gotify notifications
- Slightly more operational overhead than fully automated updates

**Neutral:**
- Update frequency depends on operator responsiveness
- Can be combined with Ansible playbooks for controlled batch updates

## Alternatives Considered

1. **Watchtower (status quo)**
   - Fully automated but caused breaking changes
   - Superseded by this decision

2. **Renovate / Dependabot**
   - PR-based update workflow — better for source code than running containers
   - Could complement DIUN for compose file version pinning

3. **Manual monitoring**
   - Checking Docker Hub manually — too labor-intensive
   - DIUN automates the monitoring part
