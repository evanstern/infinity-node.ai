---
type: adr
number: 015
title: Use Ansible Push Deployment Instead of Portainer GitOps
date: 2025-04-07
status: accepted
deciders:
  - Evan
tags:
  - adr
  - infrastructure
  - deployment
  - ansible
---

# ADR-015: Use Ansible Push Deployment Instead of Portainer GitOps

**Date:** 2025-04-07
**Status:** Accepted
**Deciders:** Evan

## Context

The original infinity-node infrastructure used Portainer's GitOps feature to deploy Docker Compose stacks. Portainer polled a Git repository every 5 minutes and redeployed stacks when changes were detected. While this provided a GUI-based workflow, it had significant limitations:

- **No secrets management** — `.env` files had to be deployed to VMs manually or committed to Git
- **Polling latency** — 5-minute delay between commit and deployment
- **GUI coupling** — stack configuration lived partly in Portainer's database, not fully in code
- **No idempotency guarantees** — Portainer's reconciliation was opaque
- **Single point of failure** — Portainer down meant no deployments

## Decision

Use Ansible push deployment (`deploy-service.yml` playbook) to deploy Docker Compose stacks to hosts via SSH. Compose files live in `services/<host>/<service>/docker-compose.yml` and are pushed with `docker compose up -d`.

## Consequences

**Positive:**
- Declarative, idempotent deployments via Ansible playbooks
- Secrets injected at runtime via `community.general.bitwarden` lookup plugin — zero secrets on disk
- Immediate deployment on command — no polling delay
- Full audit trail via Git commits and Ansible logs
- No dependency on a GUI service for deployments
- Works across all hosts uniformly

**Negative:**
- Requires SSH access to all hosts (already established)
- No web UI for deployment status (mitigated by Ansible output and logging)
- Operator must run playbooks manually or via CI/CD

**Neutral:**
- Portainer can still be used for container inspection/debugging without managing deployments

## Alternatives Considered

1. **Portainer GitOps (status quo)**
   - GUI-based, but poor secrets management and polling latency
   - Superseded by this decision

2. **ArgoCD / Flux**
   - Kubernetes-native GitOps — overkill for Docker Compose workloads
   - Would require migrating to Kubernetes

3. **Watchtower + Git hooks**
   - Fragile, no secrets management, limited to image updates
