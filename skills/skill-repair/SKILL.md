---
name: skill-repair
description: >
  Fix broken skills and scripts rather than working around them.
  TRIGGER when: a skill script errors, has a syntax error, produces unexpected output, or skill instructions are unclear.
  DO NOT TRIGGER when: skill is working normally.
---

# Skill Repair

**When a skill or script fails: fix it, re-run it. Do not work around it.**

## The Rule

Skills are not optional helpers. They are the workflow. A broken skill is a bug — fix it now.

| Failure | Response |
|---|---|
| Script syntax error | Fix the syntax. Re-run. |
| Script runtime error | Diagnose. Fix. Re-run. |
| Script missing / wrong path | Find the correct path. Re-run. |
| Script produces wrong output | Fix the script. Re-run. |
| Instructions unclear or contradictory | Ask the Supreme Commander. Do not guess. |

## What NOT To Do

- Run the script's commands manually because the script failed
- Gather information ad-hoc to substitute for a failed gather script
- Continue the workflow with partial state from a failed step
- Skip a skill step because a tool or script "doesn't work right now"

## What To Do

1. **State the failure** — which skill, which step, the exact error
2. **Propose a fix** — show what change is needed
3. **Confirm if unsure** — if the fix isn't obvious, ask before modifying the skill
4. **Fix and re-run** — apply the fix, re-run the original step

## Why

Skills are dogfooded — they run in real workflows on every invocation. A broken script that gets worked around stays broken. Fixing it now improves every future run.

Working around a broken skill hides the bug, bypasses the checks built into the skill, and produces ad-hoc unaudited behaviour that diverges from the intended workflow.
