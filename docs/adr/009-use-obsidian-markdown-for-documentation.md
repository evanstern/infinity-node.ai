---
type: adr
number: 009
title: Use Obsidian + Markdown for Documentation
date: 2025-10-24
status: accepted
deciders:
  - Evan
  - Claude Code
tags:
  - adr
  - documentation
  - obsidian
  - markdown
---

# ADR-009: Use Obsidian + Markdown for Documentation

**Date:** 2025-10-24
**Status:** Accepted
**Deciders:** Evan + Claude Code

## Context
Need documentation system that:
- Works with Claude Code effectively
- Handles task management (MDTD)
- Visualizes relationships
- Stored in git
- No lock-in

## Decision
Use Obsidian as optional interface for Markdown-based documentation with:
- Wiki-links for cross-referencing
- YAML frontmatter for metadata
- Dataview plugin for queries
- Works without Obsidian (just markdown)

## Consequences

**Positive:**
- Powerful graph view of relationships
- Dataview queries for task management
- Wiki-links make navigation easy
- Claude Code can read/write easily
- No lock-in (just markdown)
- Works offline
- Git-friendly

**Negative:**
- Obsidian-specific features not portable
- Requires plugin setup
- Learning curve for Obsidian

**Neutral:**
- Could use other tools on same markdown
- Obsidian is optional, not required

## Alternatives Considered

1. **Plain Markdown**
   - Works everywhere
   - No visualization
   - Manual link management

2. **Wiki (Docusaurus, GitBook, etc.)**
   - Better for publishing
   - More complex setup
   - Less flexible for notes

3. **Notion/similar**
   - Not markdown-based
   - Vendor lock-in
   - Not Claude Code friendly
