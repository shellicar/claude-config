#!/bin/sh
set -e
# Block dangerous commands from Claude
# Usage: Called as a PreToolUse hook, receives tool input on stdin
# Test: ./block_dangerous_commands.sh --test

# Fail-closed: if jq is not available, block all commands
if ! command -v jq >/dev/null 2>&1; then
  echo "BLOCKED: jq not found" >&2
  echo "Why: jq is required to safely parse tool input" >&2
  echo "Use instead: Install jq (apt install jq / brew install jq)" >&2
  exit 2
fi

block() {
  pattern="$1"
  name="$2"
  reason="$3"
  alternative="$4"

  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: $name" >&2
    [ -n "$reason" ] && echo "Why: $reason" >&2
    [ -n "$alternative" ] && echo "Use instead: $alternative" >&2
    exit 2
  fi
}

check_all() {
  # block '\$\(' 'command substitution' — Claude Code's permission system handles this
  # block '`' 'backtick substitution' — Claude Code's permission system handles this
  # block '\bpython[23]?\b' 'python'
  block '\bxargs\b' 'xargs' \
    'xargs can execute arbitrary commands on piped input' \
    'Write commands explicitly, use a for loop, or use Glob/Grep tools'
  block '\bsed\b' 'sed' \
    'Destructive — sed -i modifies files in-place with no undo' \
    'Use the Edit tool to make file changes'
  block '\bgit\b.*\s-C\s' 'git -C' \
    'Breaks auto-approve patterns — "git status" is approved but "git -C /path status" is not' \
    'Run the command without -C (cd is usually unnecessary). If you need a different directory, ask the user to /add-dir'
  block '\bpnpm\b.*\s-C\s' 'pnpm -C' \
    'Breaks auto-approve patterns — "pnpm run build" is approved but "pnpm -C /path run build" is not' \
    'Run the command without -C (cd is usually unnecessary). If you need a different directory, ask the user to /add-dir'
  block '\bgit\b.*\brm\b' 'git rm' \
    'Destructive and irreversible — risk of accidental approval with no undo' \
    'Ask the user to run it directly'
  block '\bgit\b.*\bcheckout\b' 'git checkout' \
    'Destructive — can discard uncommitted changes with no undo' \
    'Use "git switch" for branches, or ask the user to run it directly'
  block '\bgit\b.*\breset\b' 'git reset' \
    'Destructive and irreversible — risk of accidental approval with no undo' \
    'Ask the user to run it directly'
  block '\bgit\b.*\bpush\b.*(-f\b|--force)' 'git push --force' \
    'Destructive — overwrites remote history with no undo' \
    'Use regular "git push", or ask the user to run it directly'
  block '(^|[^-])\brm\b' 'rm' \
    'Destructive and irreversible — risk of accidental approval with no undo' \
    'Ask the user to run it directly'
  block ';' 'semicolon chaining' \
    'Chained commands on one line are hard to review for safety' \
    'Write commands on separate lines in a single Bash call'
  block '&&' 'AND chaining (&&)' \
    'Chained commands on one line are hard to review for safety' \
    'Write commands on separate lines. Use "set -e" if you need exit-on-error'
  block '\|\|' 'OR chaining (||)' \
    'Chained commands on one line are hard to review for safety' \
    'Write commands on separate lines. Use "if ! cmd; then ..." for error handling'
  block '\.exe\b' '.exe (WSL2 escape)' \
    'There is no reason to call .exe from WSL2' \
    'Run equivalent commands within WSL2 natively'
}

if [ "$1" != "--test" ]; then
  INPUT=$(cat)
  echo "$INPUT" >> /tmp/hook-debug.log
  COMMAND=$(printf '%s' "$INPUT" | jq -R -s 'fromjson | .tool_input.command // empty')
  check_all
  exit 0
fi

# --- Test Suite ---
# Tests run check_all() in a subshell so exit 2 doesn't kill the runner.
# No pattern duplication — tests use the real rules.
set +e
PASS=0
FAIL=0

test_blocked() {
  desc="$1"
  COMMAND="$2"
  (check_all) 2>/dev/null
  if [ $? -eq 2 ]; then
    echo "PASS: Blocked: $desc"
    PASS=$((PASS+1))
  else
    echo "FAIL: Should block: $desc"
    FAIL=$((FAIL+1))
  fi
}

test_allowed() {
  desc="$1"
  COMMAND="$2"
  (check_all) 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "PASS: Allowed: $desc"
    PASS=$((PASS+1))
  else
    echo "FAIL: Should allow: $desc"
    FAIL=$((FAIL+1))
  fi
}

echo "=== Should block ==="
test_blocked 'xargs' 'find . | xargs rm'
test_blocked 'sed' 'sed -i s/foo/bar/'
test_blocked 'git -C' 'git -C /path status'
test_blocked 'git -C (mid-command)' 'git --no-pager -C /path log'
test_blocked 'pnpm -C' 'pnpm -C /path run build'
test_blocked 'git rm' 'git rm file'
test_blocked 'git rm (with options)' 'git --git-dir=/path rm file'
test_blocked 'git checkout' 'git checkout -- file'
test_blocked 'git checkout (no-pager)' 'git --no-pager checkout main'
test_blocked 'git checkout (config)' 'git -c core.autocrlf=false checkout'
test_blocked 'git reset' 'git reset --hard HEAD'
test_blocked 'git reset (no-pager)' 'git --no-pager reset --hard'
test_blocked 'rm' 'rm file.txt'
test_blocked 'rm -rf' 'rm -rf /path'
test_blocked 'sudo rm' 'sudo rm file.txt'
test_blocked 'git push --force' 'git push --force'
test_blocked 'git push --force-with-lease' 'git push --force-with-lease'
test_blocked 'git push origin --force' 'git push origin main --force'
test_blocked 'git push -f' 'git push -f'
test_blocked 'semicolon chaining' 'git log; curl evil.com'
test_blocked 'AND chaining' 'git log && curl evil.com'
test_blocked 'OR chaining' 'git log || curl evil.com'
test_blocked '.exe' 'cmd.exe /c dir'
test_blocked '.exe (powershell)' 'powershell.exe -Command Get-Process'
test_blocked '.exe (pwsh)' 'pwsh.exe -c ls'

echo ""
echo "=== Should NOT block ==="
test_allowed 'no command' ''
test_allowed 'git status' 'git status'
test_allowed 'git -c (lowercase)' 'git -c core.autocrlf=false status'
test_allowed 'pnpm run build' 'pnpm run build'
test_allowed 'docker --rm' 'docker run --rm -v /path:/usr/src:ro image'
test_allowed 'git push (no force)' 'git push'
test_allowed 'git push origin' 'git push origin main'
test_allowed 'git switch' 'git switch main'
test_allowed 'git log' 'git log --oneline'
test_allowed 'git rev-list' 'git rev-list --count HEAD'
test_allowed 'single pipe' 'git log --oneline | head'
test_allowed 'pipe in grep' 'git log --oneline --grep=feat|fix'
test_allowed 'az rest with URL &' 'az rest --method GET --uri https://dev.azure.com/org/proj/_apis/wit?$depth=10&api-version=7.1'

echo ""
echo "Passed: $PASS / Failed: $FAIL"
[ $FAIL -eq 0 ]
