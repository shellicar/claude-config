---
name: writing-style
description: "Writing style for PRs, commits, work items, and titles.\nTRIGGER when: writing commit messages, PR titles, PR descriptions, work item titles, work item descriptions, or any user-facing text.\nDO NOT TRIGGER when: writing code, reading files, researching, or non-text-writing tasks."
user-invocable: false
---

# Writing Style

**Scope: How to write user-facing text — tone and content guidance, not templates or formatting.**

The core principle: **describe the effect, not the implementation**.

## The Rule

Say **what changed and why** — not **how you implemented it**. The audience is someone reading a title, description, or commit message to understand what happened. They don't need to know which functions you wrote, which files you touched, or which patterns you used.

This applies everywhere: PR titles, PR descriptions, commit messages, work item titles, and work item descriptions.

## PR Descriptions

Keep descriptions **short and scannable**. The PR title already conveys the purpose — the body adds only what the title can't.

**Format**:
```markdown
## Summary

- Bullet point of key change 1
- Bullet point of key change 2
- Bullet point of key change 3
```

**Rules**:
- Use `## Summary` heading with a bullet list
- **3-5 bullets maximum** — one short phrase per bullet, not full sentences
- Each bullet should describe a meaningful change, not individual file edits
- Group related changes into a single bullet
- Do NOT list every file changed or every minor detail
- Do NOT add lengthy explanations, rationale, or background context
- Do NOT include test plans, implementation notes, or technical deep-dives
- If a change is trivial enough that the title says it all, an empty body is fine

**Good**:
```markdown
## Summary

- Add env scrubbing for sandbox
- Fix date formatting in export reports
- Update facilitator licence validation rules
```

**Bad**:
```markdown
## Summary

- Create ENV_PASSTHROUGH Set and buildSandboxEnv() function that filters process.env
- Change DateFormatter.format() to use ISO 8601 instead of locale string in ExportService.ts
- Add handleFacilitator method to ProgramGroupViewProcessor and wire up event handler in ProcessViewHandler
```

The bad example describes the implementation. The good example describes the effect.

## PR Titles

- Short summary of the branch purpose (under 70 characters)
- Describe the effect, not the code
- Check that the title matches what was actually done, not what was originally planned

## Commit Messages

- Concise, single line
- Imperative mood ("Add feature" not "Added feature")
- No period at end
- Keep under 50 characters (hard limit: 72)
- Detail belongs in PRs, not commits

**Good**: `Recalculate group status when facilitator licence changes`
**Bad**: `Add handleFacilitator to ProgramGroupViewProcessor`

## Work Item and Task Titles

Titles should describe the **effect** or **goal**, not the implementation.

**Good**: `Recalculate group status when facilitator licence changes`
**Bad**: `Add handleFacilitator to ProgramGroupViewProcessor`

Stakeholders read these titles — focus on what changes from their perspective, not what code you're writing.

## Work Item Descriptions

Write descriptions like a professional speaking to a colleague, not notes or bullet points.

**Good**:
```
Handle js-joda types from the create buy a car schema.
Refactor to use record based mapping and fix the date formatting.
```

**Bad**:
```
Schema now uses js-joda types.
mapToJson must handle them.
Refactored to give static errors when unmapped types are added.
```

The bad example reads like disconnected notes. The good example states what was done in clear sentences.

Say what it is without saying how you did it. Don't abstract things, don't dumb it down, don't try to sound smart.

## Convention-Specific Formats

Convention skills define the specific template structure (which sections to include, work item link format, etc.). This skill defines *how to write the content* that goes in those templates.
