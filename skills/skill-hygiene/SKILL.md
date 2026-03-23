---
name: skill-hygiene
description: |
  Ongoing process for assessing and improving skill quality: smell catalogue, hygiene pass workflow, and current state of the library. Without it, hygiene passes restart from scratch with no record of what was done or what to look for.
  TRIGGER when auditing skill quality or running a hygiene pass.
user-invocable: true
metadata:
  category: workflow
---

# Skill Hygiene

**Scope: Assessing and improving skill quality over time. For authoring new skills, see `skill-management`.**

## Skill Smells

Patterns that indicate a skill needs attention. A smell is a signal worth investigating, not a guaranteed problem.

### Description Smells

**Table-of-contents description**: Lists what is inside the skill rather than why to load it. Usually reads as a comma-separated list of sections or topics.
> Bad: "Git conventions for shellicar projects: branch naming, PR format, and repo settings."

**Pattern-matched description**: Derived from the skill name rather than the skill content. Sounds plausible but does not reflect what the skill actually does.

**Hollow filler**: Words that say nothing specific: "safely", "correctly", "reliably", "stays navigable", "as the project grows". Every skill is "correct" by definition. Name the actual concern.
> Bad: "Safely migrates work items so the board stays navigable."

**WHAT/TRIGGER overlap**: The WHAT lists the same surfaces already listed in the TRIGGER. Each sentence should earn its space.
> Bad: WHAT says "ensures commit messages, PR titles, and work items describe effects" and TRIGGER says "when writing commit messages, PR titles, or work items". Same list, stated twice.

**Stale-value encoding**: Specific values in the description (branch names, field names, version numbers) that will drift from the actual skill content.

**Abstract justification in WHY**: Explains the reason the skill was built rather than the concrete outcome. "for template enhancement functionality" (reason) vs "to use new template versions" (outcome).

**Unnecessary DO NOT TRIGGER**: Exclusions that don't describe a real known problem. If you can't immediately name a case where loading the skill caused harm, the clause is noise.

### Structural Smells

**Stale cross-references**: References to skills that have been renamed or deleted.

**Missing category metadata**: Skills without `metadata.category` cannot be filtered or grouped in audits.

## Hygiene Pass Workflow

1. Work in batches of ~5 skills alphabetically
2. Read the **entire** skill before writing the description. Never pattern-match from the name.
3. Write a fresh description from scratch; do not iterate on a bad one
4. Stage each batch for review before committing
5. Commit per batch with a descriptive message
6. Update **Current State** below after each pass

**Rule**: If you cannot explain the core insight of the skill after reading it, the description will be wrong. Re-read.

**When in doubt, ask**: If the purpose still isn't clear after a full read, ask before writing. A skill whose purpose is unclear after reading may itself need updating to clarify its scope. The description problem might be a skill problem.

## Current State

**Last pass**: 2026-03-23 (Phase 3, full hygiene pass)
**Coverage**: All 40 skills reviewed

**What was done**:
- Descriptions rewritten from skill content (not pattern-matched)
- WHAT/WHY/WHEN pattern applied consistently
- `metadata.category` added to all skills (foundational / workflow / standards / reference)
- Description quality principles documented in `skill-management`

**Next pass**: Phase 4 (2nd pass on batches 1-4). The description quality standards established in Phase 3 post-date the first four batches. Those descriptions may have table-of-contents, hollow filler, or WHAT/TRIGGER overlap issues that weren't caught at the time. Review against the current principles in `skill-management`.
