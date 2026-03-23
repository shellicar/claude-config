---
name: detect-convention
description: |
  WHAT: Identifies the active project convention so the correct convention skill is loaded.
  WHY: Org rules, standards, and agreed practices are followed.
  WHEN: TRIGGER at the start of any project work to load the correct convention skill.
user-invocable: false
metadata:
  category: workflow
---

# Convention Detection

**Scope:** How to detect the active project convention from git remote URLs and directory paths. Convention rules themselves live in each convention skill.

Detect the project convention and default branch from the current git repository.

## Script

```bash
~/.claude/skills/detect-convention/scripts/detect-convention.sh
```

### Output

Three lines on stdout:
1. Convention name (e.g. `shellicar-config`, `eagers`, `hopeventures`)
2. Default branch (e.g. `main`, `master`)
3. Protected branches (space-separated, or `none` if direct commits are allowed)

### On failure

Prints an error to stderr and exits non-zero. The calling skill should proceed without convention-specific rules, or ask the Supreme Commander which convention to use.

### How It Works

The script matches on **both** the git remote URL **and** the working directory path:

| Remote pattern | Directory pattern | Convention |
|---------------|-------------------|------------|
| `github.com/shellicar/` | `~/.claude` or `~/dotfiles` | `shellicar-config` |
| `github.com/shellicar/` | `~/repos/@shellicar/` | `shellicar-oss` |
| `github.com/shellicar/` | `~/repos/shellicar/` | `shellicar` |
| `dev.azure.com/eagersautomotive/` | `~/repos/Eagers/` | `eagers` |
| `dev.azure.com/hopeventures/` | `~/repos/HopeVentures/` | `hopeventures` |
| `dev.azure.com/Flightrac/` | `~/repos/Flightrac/` | `flightrac` |

## Usage

After detecting the convention, load the corresponding `<convention>-conventions` skill for convention-specific rules (branch protection, commit message format, PR format, etc.).
