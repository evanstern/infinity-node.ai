---
type: adr
number: 010
title: Use Agent System for Claude Code Collaboration
date: 2025-10-24
status: accepted
deciders:
  - Evan
  - Claude Code
tags:
  - adr
  - ai
  - collaboration
  - agents
---

# ADR-010: Use Agent System for Claude Code Collaboration

**Date:** 2025-10-24
**Status:** Accepted
**Deciders:** Evan + Claude Code

## Context
Working with Claude Code on complex infrastructure requires:
- Clear responsibilities
- Safety boundaries
- Specialized knowledge
- Coordination on complex tasks

## Decision
Implement specialized agent system where Claude Code adopts different personas:
- Testing Agent (read-only, advisory)
- Docker Agent (container management)
- Infrastructure Agent (Proxmox/VMs)
- Security Agent (secrets, auth)
- Media Stack Agent (critical services)
- Documentation Agent (knowledge management)

## Consequences

**Positive:**
- Clear boundaries and permissions
- Specialized context per domain
- Safety through restrictions
- Better coordination on complex tasks
- Explicit about what can/cannot be done

**Negative:**
- More conceptual overhead
- Requires understanding agent system
- Context switching between agents

**Neutral:**
- Novel approach for AI collaboration
- Will learn and evolve over time

## Alternatives Considered

1. **No agent system**
   - Simpler conceptually
   - Less clear boundaries
   - Harder to coordinate
   - More risk of mistakes

2. **Different agent breakdown**
   - Many ways to divide responsibilities
   - Current breakdown matches infrastructure
