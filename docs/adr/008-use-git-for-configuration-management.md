---
type: adr
number: 008
title: Use Git for Configuration Management
date: 2025-10-24
status: accepted
deciders:
  - Evan
tags:
  - adr
  - git
  - version-control
  - configuration
---

# ADR-008: Use Git for Configuration Management

**Date:** 2025-10-24 (retroactive documentation)
**Status:** Accepted
**Deciders:** Evan

## Context
Need version control for:
- Docker compose files
- Documentation
- Scripts
- Configuration (non-secret)

## Decision
Use Git (GitHub) for all infrastructure configurations.

## Consequences

**Positive:**
- Version history for all changes
- Can review changes over time
- Easy to rollback
- Collaborate with others (Claude Code)
- Backup of configurations
- Can track why changes were made

**Negative:**
- Must be careful about secrets
- Requires git discipline
- Another system to learn/use

**Neutral:**
- Could use different VCS
- Git is standard for this use case

## Alternatives Considered

1. **No version control**
   - Simpler
   - No history
   - Hard to track changes
   - No backup

2. **Different VCS** (SVN, Mercurial)
   - Git is standard
   - Better ecosystem

## Validation

**2025-10-26:** Decision validated through completion of [[tasks/completed/IN-001-import-existing-docker-configs|IN-001]]. Successfully imported 24 service stacks with docker-compose configurations, documentation, and .env.example templates. All configurations now version controlled in Git with comprehensive READMEs. Strategy proven effective for infrastructure-as-code approach.
