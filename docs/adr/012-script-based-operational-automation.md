---
type: adr
number: 012
title: Script-Based Operational Automation
date: 2025-10-26
status: accepted
deciders:
  - Evan
  - Claude Code
tags:
  - adr
  - automation
  - scripting
  - operations
---

# ADR-012: Script-Based Operational Automation

**Date:** 2025-10-26
**Status:** Accepted
**Deciders:** Evan + Claude Code

## Context

Infrastructure operations are currently performed manually or with ad-hoc scripts. As we grow:
- Need reproducible operations (secret audits, deployments, health checks)
- Want to reduce human error in repetitive tasks
- Building toward Goal #3 (Automate deployment, updates, recovery)
- Need composable building blocks for larger workflows
- Want executable documentation (runbooks)

## Decision

Establish a structured approach to operational automation:

**1. Organized Script Library**
- Scripts organized by function: `secrets/`, `deployment/`, `setup/`, `validation/`, `backup/`
- Clear naming convention: `verb-noun.sh`
- Consistent structure with help text and exit codes

**2. Script Development Standards**
- Header documentation with purpose, usage, examples
- Error handling (`set -euo pipefail`)
- Descriptive variables and clear logic
- Color-coded output for clarity
- Exit codes: 0 (success), 1 (error), 2 (invalid input)

**3. Documentation Requirements**
- `scripts/README.md` inventory of all scripts
- Use cases and examples
- Dependencies and prerequisites
- Related documentation links

**4. When to Create Scripts**
- ✅ Operations run multiple times
- ✅ Validation and health checks
- ✅ Common tasks needing consistency
- ✅ Building blocks for larger automation
- ❌ One-off tasks or trivial commands

## Consequences

**Positive:**
- Reproducible operations every time
- Reduced human error
- Building blocks for larger automation
- Executable documentation
- Knowledge captured in code
- Easier onboarding (examples to follow)
- Foundation for runbooks (IN-003)
- Progress toward automation goal

**Negative:**
- Scripts require maintenance
- Need to keep documentation updated
- Learning curve for script standards
- Can accumulate clutter if not disciplined

**Neutral:**
- Balance between automation and flexibility
- Need judgment on when to script vs manual
- Scripts evolve with infrastructure

## Implementation

**Initial Scripts Organized:**
- **Secret management:** `audit-secrets.sh`, `create-secret.sh`, `update-secret.sh`, `delete-secret.sh`
- **Deployment:** `deploy-with-secrets.sh`
- **Setup:** `setup-evan-nopasswd-sudo.sh`, `setup-inspector-user.sh`

**First Use Case:** Secret inventory for IN-002 (secret migration)

**Future Automation:**
- Service health checks
- Backup operations
- Deployment runbooks
- Validation and testing
- Resource monitoring

## Alternatives Considered

1. **No structured automation**
   - Simpler initially
   - More error-prone
   - Harder to scale
   - Knowledge in heads, not code

2. **Configuration management tools (Ansible, etc.)**
   - Over-engineered for single host
   - Steeper learning curve
   - More complexity to maintain
   - Shell scripts sufficient for our scale

3. **Different organization** (flat scripts/ directory)
   - Works initially
   - Becomes cluttered quickly
   - Harder to find relevant scripts
   - No clear categorization
