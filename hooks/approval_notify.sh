#!/bin/sh

# Capture stdin once so it can be both logged and parsed.
# Guarded with [ -t 0 ] so an interactive (no-pipe) run can't hang on cat.
if [ ! -t 0 ]; then
  PAYLOAD=$(cat)
  STDIN_READ=1
else
  PAYLOAD=""
  STDIN_READ=0
fi

# Log the payload for debugging.
{
  printf '=== %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  if [ "$STDIN_READ" = "1" ]; then
    printf 'stdin: [%s]\n' "$PAYLOAD"
  else
    printf 'stdin: (no pipe; skipped)\n'
  fi
} >> ~/.claude/.hook_history

# Parse tool name from JSON (payload arrives on stdin, captured above)
TOOL_NAME=$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.name // "Unknown"' 2>/dev/null)
if [ -z "$TOOL_NAME" ] || [ "$TOOL_NAME" = "null" ]; then
  TOOL_NAME="Unknown"
fi

# Get tmux socket and pane target for click-to-switch
TMUX_SOCKET=$(echo "$TMUX" | cut -d, -f1)
SESSION_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}')
WINDOW_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}')
PANE_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index}')
TMUX_CMD="/opt/homebrew/bin/tmux -S ${TMUX_SOCKET}"

# Window title for the notification (prefer @title, fall back to window name)
WINDOW_TITLE=$(tmux display-message -t "$TMUX_PANE" -p '#{?#{@title},#{@title},#{window_name}}')

# Notification settings
TITLE="Claude Code · ${SESSION_TARGET} / ${WINDOW_TITLE}"
MESSAGE="Approval needed: ${TOOL_NAME}"
SOUND="Ping"

# Resolve iTerm2 window ID from tmux client tty
CLIENT_TTY=$(tmux display-message -p '#{client_tty}')
ITERM_WINDOW_ID=$(osascript -e 'tell application "iTerm2"' -e 'repeat with w in every window' -e 'repeat with t in every tab of w' -e 'repeat with s in every session of t' -e "if tty of s is \"${CLIENT_TTY}\" then return id of w" -e 'end repeat' -e 'end repeat' -e 'end repeat' -e 'end tell')

# Focus iTerm2 window, switch tmux session/window/pane
FOCUS_CMD="osascript -e 'tell application \"iTerm2\"' -e 'activate' -e 'select window id ${ITERM_WINDOW_ID}' -e 'end tell'"
TMUX_SWITCH="${TMUX_CMD} switch-client -t '${SESSION_TARGET}'; ${TMUX_CMD} select-window -t '${WINDOW_TARGET}'; ${TMUX_CMD} select-pane -t '${PANE_TARGET}'"
EXECUTE_CMD="${FOCUS_CMD}; ${TMUX_SWITCH}"

# Always send BEL: if we're on this session we hear it, if not it marks the window
printf '\a'

# Only send macOS notification if the client is on a different session, window, or pane
CLIENT_SESSION=$(tmux display-message -p '#{client_session}')
CLIENT_WINDOW=$(tmux display-message -p '#{client_session}:#{window_index}')
CLIENT_PANE=$(tmux display-message -p '#{client_session}:#{window_index}.#{pane_index}')
if [ "$CLIENT_SESSION" != "$SESSION_TARGET" ] || [ "$CLIENT_WINDOW" != "$WINDOW_TARGET" ] || [ "$CLIENT_PANE" != "$PANE_TARGET" ]; then
  terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" -execute "$EXECUTE_CMD"
fi
