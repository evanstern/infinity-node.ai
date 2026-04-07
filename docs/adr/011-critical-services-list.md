---
type: adr
number: 011
title: Critical Services List
date: 2025-10-24
status: accepted
deciders:
  - Evan
  - Claude Code
tags:
  - adr
  - operations
  - priorities
  - critical-services
---

# ADR-011: Critical Services List

**Date:** 2025-10-24
**Status:** Accepted
**Deciders:** Evan + Claude Code

## Context
Not all services have equal importance. Some affect household members, others only system owner.

## Decision
Define three services as CRITICAL (affecting household users):
- Emby (VM 100): Media streaming
- Downloads (VM 101): Media acquisition
- *arr services (VM 102): Media automation

All other services are important but primarily affect system owner only.

## Consequences

**Positive:**
- Clear prioritization
- Extra caution for critical services
- Can make faster changes to non-critical
- Focus maintenance on what matters most

**Negative:**
- Less attention to "non-critical" services
- Must maintain list over time

**Neutral:**
- Could expand critical list
- Priority may shift over time

## Alternatives Considered

1. **All services equal priority**
   - Simpler
   - Slower to make changes
   - Inefficient

2. **More granular tiers**
   - More complex
   - Current approach sufficient
