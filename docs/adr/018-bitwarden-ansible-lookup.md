---
type: adr
number: 018
title: Use Bitwarden Ansible Lookup Plugin for Runtime Secret Injection
date: 2025-04-07
status: accepted
deciders:
  - Evan
tags:
  - adr
  - security
  - secrets
  - ansible
  - bitwarden
---

# ADR-018: Use Bitwarden Ansible Lookup Plugin for Runtime Secret Injection

**Date:** 2025-04-07
**Status:** Accepted
**Deciders:** Evan

## Context

The original infinity-node infrastructure managed secrets through a combination of Vaultwarden (as the source of truth) and `.env` files deployed to VMs. While Vaultwarden centralized secret storage, the deployment pipeline had gaps:

- **`.env` files on disk** — secrets were written to VM filesystems, accessible to anyone with SSH access
- **Manual deployment** — `.env` files were copied manually or via scripts, with no audit trail
- **Git risk** — `.env` files could accidentally be committed to the repository
- **Rotation friction** — changing a secret required updating Vaultwarden AND redeploying `.env` files to every affected VM
- **Audit gap** — no way to know which secrets were deployed where without manual checking

## Decision

Use the `community.general.bitwarden` Ansible lookup plugin to fetch secrets from Vaultwarden at deploy time. Secrets are injected into Docker Compose environment variables or config files during `ansible-playbook` execution and never written to disk as `.env` files.

For Terraform, the `bw-run.sh` wrapper script exports secrets as `TF_VAR_*` environment variables from Vaultwarden items.

## Consequences

**Positive:**
- Zero secrets on disk — secrets exist only in memory during playbook execution
- Single source of truth — all secrets live in Vaultwarden
- Automatic rotation — update the secret in Vaultwarden, re-run the playbook
- Audit trail — Ansible logs show which secrets were accessed (not their values)
- No `.env` files to accidentally commit or leak
- Works with existing Vaultwarden instance — no new infrastructure required

**Negative:**
- Vaultwarden must be accessible during playbook runs
- Bitwarden CLI must be installed and unlocked on the control node
- Slightly slower playbook execution due to API calls
- If Vaultwarden is down, no deployments can proceed

**Neutral:**
- Requires `bw-run.sh` / `bw-unlock.sh` wrapper scripts for session management
- Secrets are organized as Vaultwarden items with structured field names

## Alternatives Considered

1. **`.env` files on disk (status quo)**
   - Simple but insecure — secrets persist on VM filesystems
   - Superseded by this decision

2. **HashiCorp Vault**
   - Industry standard, but heavy infrastructure for a homelab
   - Would require running and managing another service

3. **Ansible Vault (encrypted files in Git)**
   - Secrets encrypted at rest in the repo
   - Still requires a decryption key; secrets end up on disk after decryption
   - Less flexible than runtime lookup

4. **SOPS (Mozilla)**
   - Encrypted secrets in Git with cloud KMS or age/GPG
   - Good for static configs, less flexible for dynamic lookup
