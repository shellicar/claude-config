---
name: git-knowledge
description: "Corrects common git mental model errors before they cause data loss or unexpected working tree state.\nTRIGGER before switching branches, rebasing, stashing, or any operation that modifies commit history or working tree state.\nDO NOT TRIGGER for read-only operations like log or status."
user-invocable: false
metadata:
  category: reference
---

# Git Knowledge

**Scope:** How Git actually works — the relationship between working tree, index, and commits. This skill corrects common misconceptions that lead to unnecessary operations. It does NOT contain workflows — see `git-commit`, `git-push`, `git-cleanup` for those.

## The Three States

Git has three places where file content lives:

1. **Working tree** — files on disk. What you see in the editor.
2. **Index (staging area)** — snapshot of what will go into the next commit. Modified by `git add` and `git restore --staged`.
3. **Commits** — permanent snapshots in the repository history. Created by `git commit`.

Understanding which state you're affecting prevents unnecessary operations.

## Branch Switching

A branch is a pointer to a commit. Switching branches moves HEAD to a different commit and updates the working tree to match.

### When stashing is NOT needed

- **Creating a new branch** (`git switch -c <name>`): The new branch points at the same commit as the current branch. The working tree does not change. Staged and unstaged files carry over unchanged. There is nothing to stash.

- **Switching to an existing branch with no conflicts**: If the uncommitted changes (staged or unstaged) do not conflict with the target branch, Git carries them over silently. The uncommitted files remain exactly as they are. There is nothing to stash.

- **Switching to an existing branch when uncommitted files only exist in the working tree and are not tracked in either branch**: Untracked files are never affected by branch switches. They stay in the working tree regardless.

### When stashing IS needed

- **Switching branches when uncommitted changes conflict** with the target branch's tree. Git will refuse the switch with an error like `error: Your local changes to the following files would be overwritten by checkout`. Only then do you need to stash (or commit).

### The rule

**Do not stash pre-emptively.** Attempt the branch switch first. If Git refuses, then stash. If Git succeeds, the files carried over and no stash was needed.

## Unstaged Files

Unstaged files are modifications in the working tree that have not been added to the index.

### What unstaged files DO NOT affect

- **Commits**: Only staged files go into a commit. Unstaged files are invisible to `git commit`.
- **Pushes**: Only commits are pushed. Unstaged files are not pushed.
- **Branch switches**: Unstaged files carry over between branches (unless they conflict — see above).
- **Pulls/rebases**: Unstaged files are preserved unless they conflict with incoming changes.

### What unstaged files DO affect

- **Diffs**: `git diff` shows unstaged changes. `git diff --cached` shows staged changes. These are different commands showing different things.
- **Status**: `git status` lists them as "Changes not staged for commit". This is informational, not a problem to solve.

### The rule

**Unstaged files are not a problem.** They do not need to be "dealt with" before performing other operations. They sit in the working tree and do not interfere with commits, pushes, or branch switches (barring conflicts). Do not stage, stash, or discard files just because they appear in `git status`.

## Staged Files

Staged files are changes added to the index via `git add`.

### Key properties

- Staging is **reversible** — `git restore --staged <file>` removes from the index without losing the working tree changes.
- Staging is **an intent declaration**, not a commitment. Nothing is permanent until `git commit`.
- Staged files survive branch switches (same rules as unstaged — carried over unless they conflict).
- A file can be **both staged and unstaged** simultaneously — this means part of the file was staged, then more edits were made. `git diff --cached` shows what's staged; `git diff` shows what's unstaged on top.

## Untracked Files

Files that Git has never seen (not in any commit, not in the index).

### Key properties

- Untracked files are **completely invisible** to Git operations: commits, pushes, pulls, branch switches, rebases, merges.
- They are listed in `git status` under "Untracked files" for awareness, not because they're a problem.
- The only operations that affect untracked files are `git clean` (deletes them) and `git add` (starts tracking them).

### The rule

**Untracked files need no action** unless you intend to commit them. They cannot "break" anything.

## Common Misconceptions

### "I need to stash before creating a branch"

**Wrong.** Creating a branch (`git switch -c`) does not change the working tree. The new branch starts at the same commit. All working tree state (staged, unstaged, untracked) carries over. Stashing is unnecessary and wastes time.

### "Unstaged files will be lost if I switch branches"

**Wrong.** Unstaged files carry over between branches. Git only refuses a switch if there's a conflict between the uncommitted changes and the target branch. Even then, the files are not lost — Git blocks the operation rather than overwriting.

### "I need a clean working tree before pulling"

**Usually wrong.** `git pull` merges (or rebases) the remote changes into the current branch's commits. Uncommitted changes are preserved unless they conflict with the incoming changes. If there's a conflict, Git tells you. You don't need to stash pre-emptively.

### "Unstaged changes might get committed accidentally"

**Wrong.** Only staged changes are committed. `git commit` operates on the index, not the working tree. If a file is not staged, it cannot enter a commit regardless of what else you do.

### "I should stage all files before doing anything"

**Wrong.** Staging is specifically for building the next commit. Files should be staged when you're ready to commit them, not as a general "safety" measure. Staging unrelated files pollutes the commit.

### "Untracked files are dangerous"

**Wrong.** Untracked files are inert. They exist only in the working tree. No Git operation will touch them (except `git clean`, which you should never run without explicit permission).

## Operations and Their Actual Requirements

| Operation | Requires clean tree? | Affects unstaged? | Affects untracked? |
|-----------|---------------------|-------------------|-------------------|
| `git switch -c <branch>` | No | No | No |
| `git switch <branch>` | No (unless conflicts) | No (unless conflicts) | No |
| `git commit` | N/A — commits staged only | No | No |
| `git push` | No | No | No |
| `git pull` | No (unless conflicts) | No (unless conflicts) | No |
| `git rebase` | Requires no staged changes | May conflict | No |
| `git merge` | No (unless conflicts) | May conflict | No |
| `git stash` | N/A — this IS the clean-tree operation | Stashes them | No (unless `--include-untracked`) |
| `git reset --hard` | N/A — **destructive** | **Discards them** | No |
| `git clean` | N/A — **destructive** | No | **Deletes them** |

## Decision Rule

Before performing any Git operation, ask: **"Does this operation actually require a clean working tree?"**

Check the table above. If the answer is no, proceed without stashing, staging, or cleaning. If unsure, attempt the operation — Git will tell you if there's a problem. Git is safe by default: it refuses destructive operations rather than silently losing data.
