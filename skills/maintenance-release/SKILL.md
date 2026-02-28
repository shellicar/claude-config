---
name: maintenance-release
description: Perform maintenance release with security fixes and dependency updates. Use when updating dependencies, applying security patches, or doing routine maintenance.
---

# Maintenance Release Workflow

**Scope:** Steps for gathering CVE and dependency data, proposing an update plan, executing updates, and verifying the result. Version management lives in github-version.

Perform a maintenance release by gathering security and dependency information, proposing a recommended plan, and executing after user refinement.

## Quick Start

```
1. Verify preconditions (on main, synced) — handle ecosystem dirty tree
2. Run `pnpm audit` and `pnpm exec npm-check-updates --workspaces`
3. Present findings and propose update plan
4. Fix audit: pnpm audit --fix → nuke lockfile+node_modules → reinstall → verify
5. Update deps: ncu (analyze first, user picks, reject syncpack + majors)
6. Post-ncu fixups: corepack up + biome migrate
7. Run `pnpm build` and `pnpm test`
8. Optionally invoke `github-version` for release
9. Commit, push, and create PR (load `github-pr` and `github-milestone` skills)
```

## Helper Scripts

Scripts in `~/repos/@shellicar/ecosystem/scripts/`:

| Script | Purpose |
|--------|---------|
| `fix-audit.sh` | Fix audit vulnerabilities with clean override resolution (handles pnpm#6774) |
| `fix-ghsa.mjs` | Apply targeted pnpm overrides from GHSA vulnerability data |
| `post-ncu.sh` | Restore corepack SHA + run biome migrate after ncu |
| `ensure-labels.sh` | Create standard GitHub labels (dependencies, bug, etc.) |
| `preflight.sh` | Pre-flight checks: git state, audit, updates, version |
| `verify.sh` | Run build + test, only show output on failure (context-efficient) |
| `post-merge.sh` | Post-merge cleanup: pull main, prune, delete merged branch |

## Scope

- Single repository at a time
- Security fixes (CVEs)
- Dependency updates (major/minor/patch)

## Progress Tracking

Create a TODO list at the start of the workflow to track progress through each phase. Update it as you go — mark each step complete immediately after finishing, not in batches.

Initial TODOs (adjust based on what preflight reveals):

```
- Run preflight checks
- Present findings and recommend plan
- Fix audit vulnerabilities
- Update dependencies (ncu)
- Post-ncu fixups (corepack, biome)
- Verify (build + test)
- Update CHANGELOG and bump version
- Commit, push, create PR (load github-pr + github-milestone skills)
- Wait for merge, create release, clean up
```

Drop steps that don't apply (e.g. skip "Fix audit" if no vulnerabilities, skip "Update dependencies" if everything is current). Add steps if needed (e.g. "Apply targeted GHSA overrides" if fix-audit.sh doesn't resolve everything).

## Phase 0: Pre-flight Checks

Run the pre-flight script to gather all state in one call:

```bash
~/repos/@shellicar/ecosystem/scripts/preflight.sh
```

This reports: branch, sync status, working tree, stale branches, audit vulnerabilities, available updates, and current version.

### Preconditions

1. **On default branch** (`main` or `master`)
2. **Clean working tree** (no uncommitted changes — see Ecosystem Dirty Tree below)
3. **Synced with remote** (local matches origin)
4. **No stale branches** (previous work has been merged/cleaned)

### Ecosystem Dirty Tree

After `pnpm install`, lefthook may create/move files (e.g. `scripts/verify-version.sh` → `.lefthook/pre-push/verify-version.sh`). This is an **ecosystem-wide migration pattern** — the same change appears in every repo.

These changes are **expected** and should be included in the maintenance release commit. They are not "real" uncommitted work.

**How to handle:**
1. Run `git status` after `pnpm install`
2. If changes are limited to lefthook/ecosystem files → include in maintenance PR
3. If changes include real work-in-progress → inform user, do not proceed

**Typical ecosystem files:**
- `lefthook.yml` (config changes)
- `.lefthook/` directory (script relocation)
- `scripts/*.sh` (deletions when moved to `.lefthook/`)

### If Preconditions Not Met

Report to user what needs to be addressed before proceeding. Do not continue until preconditions are satisfied.

## Phase 1: Information Gathering

The `preflight.sh` output already includes audit results and available updates. Use that output for this phase — no need to re-run those commands.

### 1.1 Check for CVEs

From the preflight audit output, identify:

- Severity (critical, high, moderate, low)
- Affected packages
- Vulnerable versions
- Patched versions
- Dependency paths

#### Finding the CVE ID and GHSA URL

Both the CVE ID and GHSA URL are needed — the CVE for branch naming, and the GHSA URL for the commit message link.

**From `pnpm audit`**: The output includes GHSA links. Use `pnpm audit --json` for structured data with advisory URLs and CVE IDs.

**From a CVE ID**: Search GitHub advisories — it matches directly on CVE IDs:

```
https://github.com/advisories?query=CVE-YYYY-NNNNN
```

Additional filters: `ecosystem:npm`, `affects:LIBRARY`, `severity:LEVEL` — see [GitHub docs](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/fix-reported-vulnerabilities/browsing-security-advisories-in-the-github-advisory-database#searching-the-github-advisory-database).

**From a GHSA URL**: Visit the page to find the CVE ID listed on it.

Example: CVE-2026-22036 ↔ GHSA-g9mf-h72j-4rw9

### 1.2 Check @shellicar Package Dependencies

If a CVE is found, check if it affects other @shellicar packages. Most packages share similar dev/build dependencies, so a CVE in one likely affects all.

```bash
# Reference the dependency graph
cat ~/repos/@shellicar/ecosystem/DEPENDENCY-GRAPH.md
```

**Important**: Update packages in dependency order (Tier 0 → Tier 1 → Tier 2). For example, if `build-clean` has a CVE fix, release it first before updating packages that depend on it.

If an @shellicar dependency has a newer version with the fix:
- Include that update in the plan
- Note: "Includes CVE fix from @shellicar/build-clean 1.2.1"

### 1.3 Trace Dependency Origins

For each CVE or notable update, trace where it comes from:

```bash
pnpm why <package-name>
```

This reveals:

- Is it a direct or transitive dependency?
- Which package(s) pull it in?
- Is the root in `dependencies`, `devDependencies`, or an internal tool?

Example output interpretation:

```text
@isaacs/brace-expansion 5.0.0
└─┬ tsup (devDependencies)
  └─┬ sucrase
    └─┬ glob
      └── minimatch
```

This shows the CVE is in a dev dependency chain → lower risk.

### 1.5 Check for Available Updates

Check ALL packages in the workspace, not just the root.

**Important**: `pnpm outdated` respects semver ranges in package.json — it won't show that `vitest@3.0` is available if your range is `^2.x`. Use `npm-check-updates` instead for a complete picture.

#### Preferred: npm-check-updates (ncu)

```bash
# Preview available updates (DO NOT use -u flag yet)
pnpm exec npm-check-updates --workspaces

# Or if custom script exists:
pnpm updates
```

**Always exclude syncpack** from auto-updates — major bumps cause breaking changes:

```bash
pnpm exec npm-check-updates --workspaces --reject syncpack
```

**Never run ncu with `-u` yourself.** Instead:
1. Run without `-u` to see what's available
2. Analyze and recommend which to include/skip (see Phase 2)
3. Present recommendation to user via `AskUserQuestion`
4. User runs ncu interactively or with specific filters

#### Categorize Results

- **Major**: Breaking changes, require individual consideration — **skip by default** in maintenance releases
- **Minor**: New features, backwards compatible
- **Patch**: Bug fixes only

### 1.6 Identify Package Context

For each update, determine:

#### Dependency Type and Location

- **Production dependency** (`dependencies`): Ships to users, highest risk
- **Dev dependency** (`devDependencies`): Build/test only, medium risk
- **Internal tools** (e.g., `tools/`, `scripts/`): Internal use only, lowest risk
- **Peer dependency** (`peerDependencies`): Compatibility constraint

#### Risk Assessment Matrix

| Situation | Internal Tools | Dev Dependency | Prod Dependency |
| --------- | -------------- | -------------- | --------------- |
| CVE present | Lowest risk | Lower risk | Highest risk |
| Major update breaks | Easily caught | Caught in dev | Could break prod |
| Update liberally? | Yes | Yes | More caution |

Note: A CVE in an internal tool (e.g., `tools/verify-version.sh` deps) is still worth fixing but has minimal real-world impact if something breaks.

#### Special Package Rules

- `syncpack` - **never auto-update** (major bumps break; always `--reject syncpack`)
- `@types/node` - always safe to update (types only, recommended)
- `@types/*` - should align with main package version
- Build tools (esbuild, tsup, vitest) - dev only, can be more aggressive
- Runtime libraries (express, hono) - more caution needed

## Phase 2: Present Recommended Plan

Present ALL information gathered, organized into recommended actions.

### Recommendation Scenarios

Use these scenarios to guide the recommended plan:

#### Scenario A: Critical/High CVE Present

- Primary goal: Fix security vulnerability with minimal risk
- Recommend: Security fixes + patch updates only
- Skip: Minor and major updates (could introduce instability)
- Reasoning: Don't risk breaking changes when shipping a security fix

#### Scenario B: Moderate/Low CVE Present

- Primary goal: Fix security, can be slightly more liberal
- Recommend: Security fixes + patch + minor updates
- Skip: Major updates
- Reasoning: Lower urgency allows safe feature updates

#### Scenario C: No CVEs, Routine Maintenance

- Primary goal: Stay current
- Recommend: All patch + minor updates
- Major: Present individually for user decision
- Reasoning: No security pressure, good time for broader updates

#### Scenario D: Major Update Focus

- Primary goal: Tackle a specific major version bump
- Recommend: Only the targeted major update
- Skip: Everything else (isolate the breaking change)
- Reasoning: Major updates should be tested in isolation

#### Scenario E: Quick Patch Run

- Primary goal: Minimal maintenance, minimal risk
- Recommend: Patch updates only
- Skip: Minor and major
- Reasoning: Bug fixes only, no new features

### Applying Scenarios

1. Detect which scenario applies based on gathered information
2. State which scenario is being applied and why
3. User can override (e.g., "I want scenario C even though there's a CVE")

### Format

```markdown
## Security Vulnerabilities

| Severity | Package | Type | Current | Fixed | Path |
|----------|---------|------|---------|-------|------|
| critical | @isaacs/brace-expansion | dev | 5.0.0 | 5.0.1 | tsup>sucrase>glob>... |

Note: This CVE is in a dev dependency (lower risk - doesn't ship to users).

## Available Updates

### Major Updates (individual consideration required)

| Package | Type | Current | Latest | Notes |
|---------|------|---------|--------|-------|
| zod | prod | 3.24.0 | 4.0.0 | ⚠️ Breaking API changes (prod) |
| vitest | dev | 2.1.0 | 3.0.0 | Breaking, but dev only |
| @types/express | dev | 4.x | 5.x | ⚠️ express still on 4.x |

### Minor Updates

| Package | Type | Current | Latest |
|---------|------|---------|--------|
| hono | prod | 4.6.0 | 4.7.0 |
| esbuild | dev | 0.24.0 | 0.25.0 |

### Patch Updates

| Package | Type | Current | Latest |
|---------|------|---------|--------|
| typescript | dev | 5.7.0 | 5.7.2 |

---

## Recommended Plan

**INCLUDE:**
- ✅ Security fix: @isaacs/brace-expansion (critical CVE)
- ✅ @types/node 20.x → 22.x (types only, always safe)
- ✅ All minor updates (backwards compatible)
- ✅ All patch updates (bug fixes)

**SKIP:**
- ⏭️ zod 3 → 4 (major - significant migration work)
- ⏭️ applicationinsights 2 → 3 (major - needs dedicated effort)
- ⏭️ @types/express 4 → 5 (main package still on v4)

**Reasoning:** Prioritizing security and safe updates. Major updates flagged for separate consideration.

---

What would you like to adjust?
```

### Scenario F: Nothing To Do

If no CVEs and no updates available:

- Report: "No security vulnerabilities found. All dependencies are up to date."
- Exit gracefully - no further action needed

## Phase 3: User Refinement

Use the `AskUserQuestion` tool when gathering user input during this workflow.

Example questions:

- "What would you like to adjust from this plan?"
- "Which major updates would you like to include?"
- "Should we proceed with security fixes only?"

Example user responses:

- "Just security for now"
- "Include minor updates too"
- "Let's also do the zod update, I have time"
- "Skip minor, only patch and security"

Adjust the plan accordingly and confirm before proceeding.

## Phase 4: Execute Plan

### 4.1 Apply Security Fixes

Use the `fix-audit.sh` helper script:

```bash
~/repos/@shellicar/ecosystem/scripts/fix-audit.sh
```

This runs `pnpm audit --fix`, then nukes lockfile + node_modules and reinstalls to work around the pnpm override chaining bug ([pnpm#6774](https://github.com/pnpm/pnpm/issues/6774)), then verifies the audit is clean.

If `fix-audit.sh` reports vulnerabilities still present:
1. Use `fix-ghsa.mjs` to apply targeted overrides for specific GHSAs
2. Then re-run `fix-audit.sh` to verify

```bash
# Apply targeted override for a specific GHSA
echo '[{"pkg":"koa","vulnerable":">= 3.0.0, < 3.1.2","patched":"3.1.2"}]' \
  | node ~/repos/@shellicar/ecosystem/scripts/fix-ghsa.mjs pnpm-workspace.yaml
```

If neither approach resolves the CVE, inform the user for manual intervention.

#### Known Issue: pnpm Override Chaining Bug

pnpm overrides don't re-evaluate after a first override changes the resolved version. For example, if you have:
- `koa@<2.16.4: '>=2.16.4'` (resolves koa to 3.0.3, crossing major boundary)
- `koa@>=3.0.0 <3.1.2: '>=3.1.2'` (should catch 3.0.3 but doesn't chain)

The **only reliable workaround** is deleting both `pnpm-lock.yaml` AND `node_modules` then reinstalling. The `fix-audit.sh` script handles this automatically.

See: https://github.com/pnpm/pnpm/issues/6774

### 4.2 Apply Selected Updates

**Do NOT run ncu with `-u` directly.** The preflight output already shows all available updates. Use that to determine the update strategy.

#### Analyze the preflight ncu output

Look for packages that need special handling:

- **Pinned versions** (no `^` or `~` prefix, e.g. `4.5.1`) — these are intentional, skip them
- **Major bumps** — skip by default in maintenance releases
- **syncpack** — always reject

#### Provide exact commands

Based on the analysis, provide the user with **non-interactive** commands to run. Never rely on interactive selection — it's error-prone.

**Simple case** (no pinned versions to worry about):

```bash
pnpm exec npm-check-updates --workspaces -u --reject syncpack
```

**When some packages must be skipped** (pinned versions or majors):

```bash
# Update everything except the problem packages
pnpm exec npm-check-updates --workspaces -u --reject syncpack,<pkg1>,<pkg2>

# Then update skipped packages only in specific workspaces that use ^
pnpm --filter <workspace-name> add <pkg>@^<version> -D
```

Example: if `@azure/cosmos` is pinned at `4.5.1` in an example workspace but uses `^4.9.0` elsewhere:

```bash
# Update everything except @azure/cosmos and syncpack
pnpm exec npm-check-updates --workspaces -u --reject syncpack,@azure/cosmos

# Then update @azure/cosmos only in workspaces that use ^ ranges
pnpm --filter @shellicar/cosmos-query-builder add @azure/cosmos@^4.9.1 -D
pnpm --filter @shellicar/cosmos-query-builder-examples-cjs add @azure/cosmos@^4.9.1 -D
```

#### Verify the diff

After the user runs the commands, verify `git diff` on package.json files to confirm:
- No pinned versions were changed
- No major bumps were introduced
- All expected packages were updated

### 4.3 Post-ncu Fixups

After ncu updates package versions, two things typically break:

1. **packageManager SHA hash** — ncu strips the corepack SHA from the `packageManager` field
2. **biome.json schema** — if biome was updated, the schema URL is stale

Use the `post-ncu.sh` helper script:

```bash
~/repos/@shellicar/ecosystem/scripts/post-ncu.sh
```

Or manually:
```bash
corepack up                    # Restore packageManager SHA
pnpm biome migrate             # Update biome.json schema
pnpm install                   # Update lockfile
```

### 4.4 Verify

```bash
~/repos/@shellicar/ecosystem/scripts/verify.sh
```

This runs `pnpm build` and `pnpm test`, capturing output. On success it prints a one-line summary per step (minimal context). On failure it shows the full output for diagnosis.

Options: `--build` (build only), `--test` (test only).

If verification fails, report to user and await guidance.

### 4.5 Version and Changelog (optional)

Version bumping and CHANGELOG.md updates are handled by the `github-version` skill.

**Two workflow options:**

1. **Same PR**: After verification passes, invoke `github-version` skill, then create a second commit for version changes
2. **Separate PR**: Commit changes now, merge, then do version management in a separate PR when ready to release

Use `AskUserQuestion` to confirm:

```text
Verification passed. Changes are ready.

Would you like to:
1. Include version bump in this PR (invoke github-version)
2. Commit changes only (version management later, separate PR)
```

This allows flexibility - work can be merged without committing to a release.

## Phase 5: Prepare for Commit

### 5.1 Determine Branch Name

Branch names must be unique - avoid generic names that would be reused.

#### Branch Prefixes

- `security/` - security fixes (CVEs)
- `chore/` - dependency updates, maintenance
- `fix/` - bug fixes (not for security or maintenance)

#### Include Context for Uniqueness

Combine human-readable context with unique identifier:

- **CVE with package**: `security/<package>-CVE-YYYY-NNNNN` (preferred for single CVE)
- **Date-based**: `security/audit-YYYY-MM-DD` (for multiple CVEs or mixed)
- **Package-based**: `chore/update-<package>-YYYY-MM-DD`

#### Examples

- Security fix for brace-expansion CVE-2026-25547 → `security/brace-expansion-CVE-2026-25547`
- Multiple CVEs on 2026-02-04 → `security/audit-2026-02-04`
- Dependency updates only → `chore/deps-update-2026-02-04`
- Mixed (security + deps) → `security/audit-2026-02-04` (security takes precedence)

### 5.2 Generate Commit Message

Based on included changes:

```text
# Security only (link to GHSA advisory)
Fix [CVE-2026-22036](https://github.com/advisories/GHSA-xxxx-xxxx-xxxx) in undici

# Dependencies only
Update minor and patch dependencies

# Mixed
Security fixes and dependency updates
```

### 5.3 Ensure Labels Exist

Before creating a PR, ensure standard labels exist on the repository:

```bash
~/repos/@shellicar/ecosystem/scripts/ensure-labels.sh --repo <repo-name>
```

This script is idempotent and can be auto-approved in settings.json.

### 5.4 Create PR

You MUST load and follow the `github-pr` skill to create the PR. Do NOT run ad-hoc `gh pr create` or `az rest` commands — the skill and its scripts encode the required parameters.

You MUST load the `github-milestone` skill to find or create the milestone before creating the PR.

After PR creation, **always link the PR URL** back to the user so they can review it.

## Phase 6: Post-Merge

After the PR is merged, complete the release:

### 6.1 Wait for Merge

Check PR status:

```bash
gh pr view <number> --json state,mergedAt
```

If auto-merge is enabled, the PR will merge once checks pass. Do not proceed until `state` is `MERGED`.

### 6.2 Create Release

Invoke the `github-release` skill to create a GitHub release, which triggers npm publish.

### 6.3 Milestone

Do **not** close the milestone after a patch release. See the `github-milestone` skill — milestones use `x.y` format and stay open across the minor series.

### 6.4 Clean Up Branches

```bash
~/repos/@shellicar/ecosystem/scripts/post-merge.sh --branch <branch-name>
```

This verifies the branch has a merged PR, switches to main, pulls, prunes remotes, and deletes the local branch. Safe to auto-approve because it only deletes branches with confirmed merged PRs.

## Notes

- Use `AskUserQuestion` tool when gathering user input during this workflow
- This skill gathers information and recommends; the user decides
- Major updates are ALWAYS presented individually for conscious decision
- The plan shows everything, even items recommended to skip
- User context (deadlines, priorities) may override recommendations
- When manual intervention is needed, delegate to the user
- Version bumping is out of scope (handled by GitVersion/release process)
