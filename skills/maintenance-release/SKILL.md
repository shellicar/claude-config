---
name: maintenance-release
description: Perform maintenance release with security fixes and dependency updates. Use when updating dependencies, applying security patches, or doing routine maintenance.
---

# Maintenance Release Workflow

Perform a maintenance release by gathering security and dependency information, proposing a recommended plan, and executing after user refinement.

## Quick Start

```
1. Verify preconditions (clean tree, on main, synced)
2. Run `pnpm audit` and `pnpm outdated`
3. Present findings and propose update plan
4. Execute: `pnpm update` or targeted updates
5. Run `pnpm build && pnpm test`
6. Optionally invoke `github-version` for release
7. Commit and create PR via `github-pr`
```

## Scope

- Single repository at a time
- Security fixes (CVEs)
- Dependency updates (major/minor/patch)

## Phase 0: Pre-flight Checks

Before starting maintenance, verify the repository meets these preconditions.

### Preconditions

1. **On default branch** (`main` or `master`)
2. **Clean working tree** (no uncommitted changes)
3. **Synced with remote** (local matches origin)
4. **No stale branches** (previous work has been merged/cleaned)

### Verification Commands

```bash
git branch --show-current    # Should be main
git status                   # Should be clean
git fetch origin
git pull                     # Should be up to date
git branch -a                # Check for stale branches
```

### If Preconditions Not Met

Report to user what needs to be addressed before proceeding. Do not continue until preconditions are satisfied.

## Phase 1: Information Gathering

### 1.1 Check for CVEs

```bash
pnpm audit 2>&1
```

Parse output to identify:

- Severity (critical, high, moderate, low)
- Affected packages
- Vulnerable versions
- Patched versions
- Dependency paths

#### Finding the CVE ID

The audit output shows a GHSA link (e.g., `https://github.com/advisories/GHSA-xxxx`).

To find the actual CVE ID (needed for branch naming):

1. Visit the GHSA link
2. Look for "CVE ID" on the page
3. If not shown, follow links to the package's security advisory (e.g., the package repo's security tab)
4. The CVE ID format is `CVE-YYYY-NNNNN`

Example: GHSA-7h2j-956f-4vf2 → follow link to package repo → CVE-2026-25547

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

#### Option 1: pnpm outdated (recursive)

```bash
pnpm outdated -r
```

#### Option 2: Custom updates script (if defined)

```bash
# Check if script exists
grep '"updates"' package.json

# Run it (typically runs ncu --workspaces)
pnpm updates
```

#### Option 3: npm-check-updates directly

```bash
# If installed as devDependency
pnpm exec npm-check-updates --workspaces

# Or run without installing
pnpm dlx npm-check-updates --workspaces
```

#### Categorize Results

- **Major**: Breaking changes, require individual consideration
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

```bash
pnpm audit --fix
```

This typically updates the lock file to use patched versions.

If `pnpm audit --fix` doesn't resolve the CVE:

1. Report the issue to the user
2. Delegate manual intervention (e.g., `pnpm-workspace.yaml` overrides, package.json overrides)
3. User will guide next steps

### 4.2 Apply Selected Updates

```bash
# For specific packages
pnpm update <package>@<version>

# For all minor/patch
pnpm update
```

### 4.3 Verify

```bash
pnpm install

# Lint/format (use biome directly - more portable than custom scripts)
pnpm biome ci
# or: pnpm biome check
# or: pnpm biome check --fix

[ -x node_modules/.bin/knip ] && pnpm knip
[ -x node_modules/.bin/dpdm ] && pnpm circular

# If script fails but binary exists, check package.json scripts.
# Package may be installed without a script configured - use AskUserQuestion.

pnpm test      # run tests
pnpm build     # verify build
```

If verification fails, report to user and await guidance.

### 4.4 Check for Version Scripts

Some repositories have version verification scripts:

```bash
# If exists
./scripts/verify-version.sh
```

Run if present, skip if not.

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
# Security only
fix(security): resolve CVE in brace-expansion

# Dependencies only
chore(deps): update minor and patch dependencies

# Mixed
chore(maintenance): security fixes and dependency updates
```

### 5.3 Ask About PR

```text
Changes are ready to commit.

Would you like to:
1. Commit only (I'll create PR later)
2. Commit and create PR (invoke github-pr skill)
```

If user chooses PR, delegate to the `github-pr` skill.

## Notes

- Use `AskUserQuestion` tool when gathering user input during this workflow
- This skill gathers information and recommends; the user decides
- Major updates are ALWAYS presented individually for conscious decision
- The plan shows everything, even items recommended to skip
- User context (deadlines, priorities) may override recommendations
- When manual intervention is needed, delegate to the user
- Version bumping is out of scope (handled by GitVersion/release process)
