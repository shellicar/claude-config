---
name: version-management
description: Determine next version and update CHANGELOG for releases
---

# Version Management

Determine the next version number and update CHANGELOG.md for a release.

## Scope

- Determine next semantic version
- Update CHANGELOG.md
- Bump package.json version

## Release Philosophy

For npm packages:

- Releases are cheap - release often, especially for security fixes
- Keep releases small and focused
- Multiple PRs can go into one version, but prefer frequent small releases
- Pre-releases available for uncertain features

## Phase 1: Determine Current Version

### From Package.json

```bash
grep '"version"' packages/*/package.json | head -1
# or for root package
grep '"version"' package.json
```

### From Git Tags

```bash
git describe --tags --abbrev=0
```

### From CHANGELOG.md

```bash
grep -E '## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1
```

## Phase 2: Determine Next Version

Based on semver and the type of changes:

| Change Type | Version Bump | Example |
| ----------- | ------------ | ------- |
| Security fix | Patch | 1.2.0 → 1.2.1 |
| Bug fix | Patch | 1.2.0 → 1.2.1 |
| Dependency updates (patch/minor) | Patch | 1.2.0 → 1.2.1 |
| New feature (backwards compatible) | Minor | 1.2.0 → 1.3.0 |
| Breaking change | Major | 1.2.0 → 2.0.0 |

### Pre-releases

For features you're not fully confident in, use pre-release versions:

```text
1.2.1-preview.1
1.2.1-preview.2
1.2.1-preview.3
...
1.2.1  (final release)
```

- CHANGELOG is written as if it's the final version (1.2.1)
- Pre-release suffix is only in package.json
- Increment preview number for each iteration

### Confirm with User

Use `AskUserQuestion` to confirm the version:

```text
Current version: 1.2.0
Recommended next version: 1.2.1 (patch - security fix)

Is this correct?
```

## Phase 3: Update CHANGELOG.md

### Check if CHANGELOG.md Exists

```bash
ls CHANGELOG.md
```

If not present, skip this phase.

### @shellicar CHANGELOG Format

All @shellicar repos use Keep a Changelog format:

```markdown
# Changelog

## [x.y.z] - YYYY-MM-DD

### Section

- Change description
```

**Note on dates:** The date is the planned/expected release date. It doesn't need to match the actual release date exactly - it's more about when the changelog entry was written.

#### Standard Sections

| Section | Use For |
| ------- | ------- |
| `### Added` | New features |
| `### Changed` | Changes to existing features, dependency updates |
| `### Fixed` | Bug fixes |
| `### Security` | Security fixes (include CVE reference) |
| `### Breaking Changes` | Breaking changes (major versions) |
| `### Structure` | Monorepo/project structure changes |

#### Security Fix Entry

```markdown
### Security

- Fixed CVE-2026-25547 in @isaacs/brace-expansion
```

#### Dependency Update Entry

For dependency updates, mention **notable** packages specifically rather than just "all dependencies". Notable means:

- Major version bumps (even in devDependencies)
- Packages users might recognize or care about
- Packages that could affect behavior (runtime deps especially)

**Good examples:**

```markdown
### Changed

- Updated typescript to 5.8, vitest to 3.0
- Updated all dependencies to latest versions
```

```markdown
### Changed

- Updated esbuild to 0.25, tsup to 8.5
```

**Avoid** listing every single package - no one cares about 10+ entries of patch updates. Group trivial updates under "Updated all dependencies" or omit if nothing notable.

**Rule of thumb:** If you wouldn't mention it in a conversation, don't list it separately.

#### Combined Entry (Security + Deps)

```markdown
### Security

- Fixed CVE-2026-25547 in @isaacs/brace-expansion

### Changed

- Updated typescript to 5.8
- Updated all dependencies to latest versions
```

### Update Version Links

Add link at bottom of CHANGELOG (maintain alphabetical/version order):

```markdown
[1.2.1]: https://github.com/shellicar/<repo>/releases/tag/1.2.1
```

Insert after the most recent version link.

## Phase 4: Bump Package.json Version

Update the version in package.json (monorepo: the published package):

```bash
# For monorepo with packages/
packages/<package-name>/package.json

# For single package repo
package.json
```

Update the `"version"` field to the new version.

For pre-releases:

```json
"version": "1.2.1-preview.1"
```

## Phase 5: Stage Changes

```bash
git add CHANGELOG.md
git add packages/*/package.json  # or just package.json
```

Do NOT commit - let the calling workflow handle commits.

## Integration with Other Skills

This skill is **independent and composable**. It can be called:

- **Same PR as changes**: `maintenance-release` → `version-management` → `git-commit` → `git-pr`
- **Separate PR**: Changes merged first, then `version-management` → `git-commit` → `git-pr` when ready to release

### Why Separate PRs?

- Work can be done without committing to a release
- Multiple changes can be batched before releasing
- Functionality and version management are orthogonal concerns
- Useful when "not sure if we plan to release yet"

### Typical Callers

- `maintenance-release` - optionally, after verification passes
- Standalone - when ready to release accumulated changes
- `git-pr` - may check if version is known for milestone

## Notes

- Always confirm version with user before proceeding
- Match existing CHANGELOG format
- Security fixes and dependency updates are patch releases (no functionality change)
- Pre-releases for uncertain features: `x.y.z-preview.N`
- CHANGELOG date is planned date, not necessarily actual release date
- For npm packages: release early, release often
