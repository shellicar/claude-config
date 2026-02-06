#!/bin/sh
# Block dangerous commands from Claude
# Usage: Called as a PreToolUse hook, receives tool input on stdin
# Test: ./block_dangerous_commands.sh --test

if [ "$1" = "--test" ]; then
  TEST_MODE=true
else
  TEST_MODE=false
fi

block() {
  pattern="$1"
  name="$2"

  if [ "$TEST_MODE" = true ]; then
    echo "$INPUT" | grep -qE "$pattern" && return 0 || return 1
  else
    echo "$INPUT" | grep -qE "$pattern" && { echo "BLOCKED: $name in: $INPUT" >&2; exit 2; }
  fi
}

check_all() {
  block '\bpython[23]?\b' 'python'
  block '\bxargs\b' 'xargs'
  block '\bsed\b' 'sed'
  block '\bgit\b.*\brm\b' 'git rm'
  block '\bgit\b.*\bcheckout\b' 'git checkout'
  block '\bgit\b.*\breset\b' 'git reset'
  block '\bgit\b.*\bpush\b.*(-f\b|--force)' 'git push --force'
  block '"rm ' 'rm'
}

if [ "$TEST_MODE" = false ]; then
  INPUT=$(cat)
  check_all
  exit 0
fi

# --- Test Suite ---
PASS=0
FAIL=0

test_blocked() {
  INPUT="$1"
  block "$3" "$2"
  [ $? -eq 0 ] && { echo "PASS: Blocked '$2' in: $1"; PASS=$((PASS+1)); } || { echo "FAIL: Should block '$2' in: $1"; FAIL=$((FAIL+1)); }
}

test_allowed() {
  INPUT="$1"
  block "$3" "$2"
  [ $? -eq 1 ] && { echo "PASS: Allowed '$2' in: $1"; PASS=$((PASS+1)); } || { echo "FAIL: False positive '$2' in: $1"; FAIL=$((FAIL+1)); }
}

echo "=== Should block ==="
test_blocked '{"command": "find . | xargs rm"}' 'xargs' '\bxargs\b'
test_blocked '{"command": "sed -i s/foo/bar/"}' 'sed' '\bsed\b'
test_blocked '{"command": "git rm file"}' 'git rm' '\bgit\b.*\brm\b'
test_blocked '{"command": "git -C /path rm -r"}' 'git rm' '\bgit\b.*\brm\b'
test_blocked '{"command": "git --git-dir=/path rm file"}' 'git rm' '\bgit\b.*\brm\b'
test_blocked '{"command": "git checkout -- file"}' 'git checkout' '\bgit\b.*\bcheckout\b'
test_blocked '{"command": "git -C /path checkout main"}' 'git checkout' '\bgit\b.*\bcheckout\b'
test_blocked '{"command": "git --no-pager checkout main"}' 'git checkout' '\bgit\b.*\bcheckout\b'
test_blocked '{"command": "git -c core.autocrlf=false checkout"}' 'git checkout' '\bgit\b.*\bcheckout\b'
test_blocked '{"command": "git reset --hard HEAD"}' 'git reset' '\bgit\b.*\breset\b'
test_blocked '{"command": "git -C /path reset HEAD~1"}' 'git reset' '\bgit\b.*\breset\b'
test_blocked '{"command": "git --no-pager reset --hard"}' 'git reset' '\bgit\b.*\breset\b'
test_blocked '{"command": "rm file.txt"}' 'rm' '"rm '
test_blocked '{"command": "python script.py"}' 'python' '\bpython[23]?\b'
test_blocked '{"command": "python3 script.py"}' 'python' '\bpython[23]?\b'
test_blocked '{"command": "python2 script.py"}' 'python' '\bpython[23]?\b'
test_blocked '{"command": "git push --force"}' 'git push --force' '\bgit\b.*\bpush\b.*(-f\b|--force)'
test_blocked '{"command": "git push --force-with-lease"}' 'git push --force' '\bgit\b.*\bpush\b.*(-f\b|--force)'
test_blocked '{"command": "git push origin main --force"}' 'git push --force' '\bgit\b.*\bpush\b.*(-f\b|--force)'
test_blocked '{"command": "git push -f"}' 'git push --force' '\bgit\b.*\bpush\b.*(-f\b|--force)'
test_blocked '{"command": "git -C /path push -f"}' 'git push --force' '\bgit\b.*\bpush\b.*(-f\b|--force)'

echo ""
echo "=== Should NOT block ==="
test_allowed '{"content": "unstaged changes"}' 'sed' '\bsed\b'
test_allowed '{"content": "based on this"}' 'sed' '\bsed\b'
test_allowed '{"content": "git commit confirmation"}' 'git rm' '\bgit\b.*\brm\b'
test_allowed '{"content": "git commit form validation"}' 'git rm' '\bgit\b.*\brm\b'
test_allowed '{"content": "perform action"}' 'rm' '"rm '
test_allowed '{"content": "confirm"}' 'rm' '"rm '
test_allowed '{"content": "checkout process"}' 'git checkout' '\bgit\b.*\bcheckout\b'
test_allowed '{"content": "reset the form"}' 'git reset' '\bgit\b.*\breset\b'
test_allowed '{"command": "git push"}' 'git push --force' '\bgit\b.*\bpush\b.*(-f\b|--force)'
test_allowed '{"command": "git push origin main"}' 'git push --force' '\bgit\b.*\bpush\b.*(-f\b|--force)'

echo ""
echo "Passed: $PASS / Failed: $FAIL"
[ $FAIL -eq 0 ]
