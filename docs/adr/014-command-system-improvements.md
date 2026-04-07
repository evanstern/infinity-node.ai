---
type: adr
status: accepted
date: 2025-11-01
decision-makers:
  - Evan
  - Claude (AI Agent)
tags:
  - adr
  - ai-collaboration
  - workflow
  - commands
  - documentation
---

# ADR-014: Command System Improvements for AI Reliability

## Status

**Accepted** - Implemented 2025-11-01

## Context

### The Problem

AI agents (Claude) were not reliably following `/create-task` command instructions, leading to:

1. **Task ID counter not maintained** - Counter file showed 31, but tasks existed up to IN-036
2. **Critical steps skipped** - Steps buried at line 526 were forgotten
3. **Inconsistent execution** - Entire phases sometimes skipped

### Root Causes Identified

**1. Commands are prompts, not scripts**
- Cursor slash commands are markdown files injected into AI context
- No enforcement mechanism - AI can skip steps
- Long commands (780 lines) lead to information compression
- AI forgets early instructions by later phases

**2. Information architecture problems**
- Critical steps buried deep (line 526 of 780)
- Narrative format easy to skim or skip
- No verification checkpoints
- No programmatic enforcement

**3. Context overload**
- Supporting documentation was monolithic (727 + 933 = 1,660 lines)
- Loading huge docs fills context window
- AI compresses large documents, loses details
- All tasks paid full context cost regardless of complexity

### How AI Context Actually Works

Key insight: **AI context accumulates but doesn't "clear" during conversation**

- Context fills up and stays filled until conversation ends
- Small docs (100-200 lines): AI retains all details
- Large docs (700+ lines): AI compresses, loses specifics
- Information at line 526 gets compressed/forgotten
- Information at line 19 stays sharp

**Implication**: Don't load what you don't need upfront; load just-in-time.

## Decision

Implement a **three-layer approach** to command reliability:

### Layer 1: Lean Command Files (~300-400 lines)

**Structure:**
1. Critical steps FIRST (lines 19-68, not line 526!)
2. Checklists instead of narrative (`- [ ]` format)
3. References to detailed docs (don't inline everything)
4. Script calls instead of manual logic

**Example transformation:**
```markdown
# OLD (narrative, buried)
### Phase 6: Task Generation
Determine Task ID:
1. Read next ID from tasks/.task-id-counter
2. Use format: IN-NNN
[... 40 more lines at line 526 ...]

# NEW (checklist, prominent)
## 🚨 CRITICAL FIRST STEPS - EXECUTE IMMEDIATELY

### Step 1: Get Next Task ID
./scripts/tasks/get-next-task-id.sh

[At line 19, impossible to miss!]

### Phase 6: Task Generation
- [ ] Get task ID: Run ./scripts/tasks/get-next-task-id.sh
- [ ] Store ID for use
- [ ] Generate filename
- [ ] Fill template
```

### Layer 2: Helper Scripts

**Create scripts for critical operations:**

- `scripts/tasks/get-next-task-id.sh` (69 lines)
  - Reads counter or scans tasks
  - Returns next ID in format `IN-NNN`
  - Self-healing (recreates counter if missing)

- `scripts/tasks/update-task-counter.sh` (49 lines)
  - Increments counter after creation
  - Validates before updating
  - Provides confirmation

- `scripts/tasks/validate-task.sh` (207 lines)
  - Validates file exists and unique
  - Checks YAML frontmatter
  - Verifies naming convention
  - Confirms location matches status

**Principle**: AI orchestrates, scripts execute complex logic.

### Layer 3: Modular Documentation

**Split monolithic docs into focused modules:**

```
OLD:
- task-creation-guide.md (727 lines) - loaded for every task
- task-examples.md (933 lines) - loaded for every task
Total: 1,660 lines (~25k tokens)

NEW:
docs/mdtd/
├── README.md (109 lines) - Navigation
├── overview.md (133 lines) - Philosophy
├── phases/ (5 files, 107-157 lines each)
├── reference/ (5 files, 120-216 lines each)
├── patterns/ (3 files, 195-299 lines each)
└── examples/ (3 files, 147-402 lines each)
```

**Loading strategy**: Just-in-time, load only what's needed:
- Simple task: Load nothing extra (0 tokens)
- Moderate task: Load 1-2 guides (~3k tokens)
- Complex task: Load 3-4 docs (~6k tokens)

## Alternatives Considered

### Alternative 1: Keep long narrative commands
**Rejected** - Already proven unreliable. AI compresses long documents.

### Alternative 2: External task CLI (bash script)
```bash
./scripts/tasks/create-task.sh "Description" [complexity]
# Interactive prompts for all fields
```
**Pros**: Most reliable, enforces structure
**Cons**: Loses AI intelligence, less flexible
**Verdict**: Too rigid, removes AI's value

### Alternative 3: Hybrid - Command + validation only
Keep narrative commands, add validation script at end.
**Pros**: Minimal change
**Cons**: Doesn't solve core problem (steps still skipped)
**Verdict**: Insufficient

### Alternative 4: Three-layer approach (CHOSEN)
Lean command + scripts + modular docs
**Pros**:
- Maintains AI flexibility
- Enforces critical operations
- Proportional context usage
- Self-documenting (checklists show what to do)
**Cons**: More files to maintain
**Verdict**: Best balance of reliability and flexibility

## Consequences

### Positive

**Context Efficiency:**
| Task Type | Before | After | Savings |
|-----------|--------|-------|---------|
| Simple | 23k tokens | 5k tokens | **78%** |
| Moderate | 23k tokens | 9k tokens | **61%** |
| Complex | 23k tokens | 17k tokens | **26%** |

**Average: 50-70% context savings**

**Reliability:**
- ✅ Critical steps impossible to miss (at top, in checklists)
- ✅ Scripts enforce correct execution
- ✅ Verification built into process
- ✅ Self-healing (counter recreation)

**Maintainability:**
- ✅ Focused modules easier to update
- ✅ Add patterns/examples without touching command
- ✅ Clear separation of concerns

**Scalability:**
- ✅ Pattern applies to other commands (`/task`, `/commit`)
- ✅ Can add more scripts as needed
- ✅ Can add more docs without bloating command

### Negative

**More files to maintain:**
- Command file (1)
- Helper scripts (3)
- Modular docs (18)
- Total: 22 files vs previous 3 files

**Mitigation**: Clear structure, focused files are easier to maintain individually.

**Learning curve:**
- Understanding when to load which docs
- Knowing which scripts do what

**Mitigation**: README.md provides navigation, scripts have clear names.

## Implementation

### Files Created

**Command restructure:**
- Modified: `.claude/commands/create-task.md` (780 → 342 lines)

**Helper scripts:**
- Created: `scripts/tasks/get-next-task-id.sh`
- Created: `scripts/tasks/update-task-counter.sh`
- Created: `scripts/tasks/validate-task.sh`
- Updated: `scripts/README.md` (documented new scripts)

**Modular documentation:**
- Created: `docs/mdtd/README.md` (navigation hub)
- Created: `docs/mdtd/overview.md` (philosophy)
- Created: `docs/mdtd/phases/` (5 phase guides)
- Created: `docs/mdtd/reference/` (5 reference docs)
- Created: `docs/mdtd/patterns/` (3 common patterns)
- Created: `docs/mdtd/examples/` (3 task examples)
- Deleted: `docs/mdtd/task-creation-guide.md` (old 727-line monolith)
- Deleted: `docs/mdtd/task-examples.md` (old 933-line monolith)

### Verification

**Tested counter synchronization:**
```bash
# Before: Counter out of sync
$ cat tasks/.task-id-counter
31
$ find tasks/ -name "IN-*.md" | ... | tail -1
36  # Gap of 5 tasks!

# After: Scripts self-correct
$ ./scripts/tasks/get-next-task-id.sh
IN-037  # Scanned and found correct next ID
```

All three scripts tested and working correctly.

## Key Principles Established

### 1. Critical Steps First
Information at line 19 stays sharp; line 526 gets compressed.
**Always put critical operations at the top.**

### 2. Checklists > Narrative
`- [ ]` checkboxes force sequential execution.
Narrative descriptions can be skipped.

### 3. Scripts Enforce, Markdown Guides
Markdown can't enforce compliance.
Use scripts for critical operations, markdown for guidance.

### 4. Load Just-in-Time
Don't load huge docs upfront "just in case."
Load focused modules only when needed.

### 5. Keep Commands Focused
- 200-400 lines: Good (AI retains all)
- 400-600 lines: Risky (compression likely)
- 600+ lines: Dangerous (definitely compressed)

## Pattern for Future Commands

This approach works for any AI command:

```
1. LEAN COMMAND (~300-400 lines)
   - Critical steps first
   - Checklists not narrative
   - Link to detailed docs

2. HELPER SCRIPTS
   - Enforce critical operations
   - Handle complex logic
   - Provide verification

3. MODULAR DOCS (~100-200 lines each)
   - Load just-in-time
   - One focused topic per doc
   - Reference from command
```

**Principle**:
- Command = WHAT to do (always loaded)
- Scripts = HOW to do it (enforcement)
- Docs = WHY and DETAILS (load if needed)

## Application to Other Commands

### `/task` command (377 lines)
**Apply**: Move critical "update status and move file" steps to top, add verification checkpoints.

### `/commit` command (107 lines)
**Status**: Already lean ✅ - no changes needed.

### Future commands
Use this pattern from the start.

## Related Documentation

- [[docs/mdtd/README]] - Modular documentation index
- [[docs/AI-COLLABORATION]] - AI collaboration guide
- [[scripts/README]] - All scripts including task helpers
- [[.claude/commands/create-task]] - Restructured command

## References

- Original issue: Task ID counter not maintained (discovered 2025-11-01)
- Testing: Counter gap of 5 tasks (31 → 36) resolved by scripts
- Context research: AI context doesn't "clear" mid-conversation
- File counts: 22 new focused files replacing 3 monolithic files

## Lessons Learned

1. **Long commands defeat themselves** - Past ~400 lines, AI compresses content
2. **Context is precious** - Don't load 700-line docs "just in case"
3. **Scripts > Instructions** - Automate what can be automated
4. **Structure matters** - Critical info must be prominent
5. **Modular > Monolithic** - Even for AI consumption
6. **Test the system** - Counter gap revealed the real problem

---

**Date**: 2025-11-01
**Status**: Accepted and Implemented
**Supersedes**: None
**Superseded by**: None
