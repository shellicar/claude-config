#!/bin/sh

# Trampoline for Claude Code tool-approval hooks.
# Reads stdin and forks once to hand off to the worker. All heavy subprocess
# work (alerter, afplay, osascript) runs in the worker's process tree,
# outside tmux's heap.

PAYLOAD=""
if [ ! -t 0 ]; then
  PAYLOAD=$(cat)
fi

# BEL: heard if on this session, marks the window if not.
printf '\a'

# Hand off to worker, detached. TMUX and TMUX_PANE are already inherited.
HOOK_PAYLOAD="$PAYLOAD" \
  nohup ~/.claude/hooks/approval_worker.sh >/dev/null 2>&1 &
