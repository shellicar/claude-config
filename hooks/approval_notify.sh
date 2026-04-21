#!/bin/sh

# Log the raw input (printf to preserve embedded newlines)
# printf '%s\n' "$*" >> /Users/shellicar/.claude/.hook_history

# Parse tool name from JSON
TOOL_NAME=$(printf '%s' "$*" | /usr/bin/jq -r '.name // "Unknown"' 2>/dev/null)
if [ -z "$TOOL_NAME" ] || [ "$TOOL_NAME" = "null" ]; then
  TOOL_NAME="Unknown"
fi

# Notification settings
TITLE="Claude Code"
MESSAGE="Approval needed: ${TOOL_NAME}"
SOUND="Ping"

# Get tmux socket and pane target for click-to-switch
TMUX_SOCKET=$(echo "$TMUX" | cut -d, -f1)
SESSION_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}')
WINDOW_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}')
PANE_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index}')
TMUX_CMD="/opt/homebrew/bin/tmux -S ${TMUX_SOCKET}"

# Resolve iTerm2 window ID from tmux client tty
CLIENT_TTY=$(tmux display-message -p '#{client_tty}')
ITERM_WINDOW_ID=$(osascript -e 'tell application "iTerm2"' -e 'repeat with w in every window' -e 'repeat with t in every tab of w' -e 'repeat with s in every session of t' -e "if tty of s is \"${CLIENT_TTY}\" then return id of w" -e 'end repeat' -e 'end repeat' -e 'end repeat' -e 'end tell')

# Focus iTerm2 window, switch tmux session/window/pane
FOCUS_CMD="osascript -e 'tell application \"iTerm2\"' -e 'activate' -e 'select window id ${ITERM_WINDOW_ID}' -e 'end tell'"
TMUX_SWITCH="${TMUX_CMD} switch-client -t '${SESSION_TARGET}'; ${TMUX_CMD} select-window -t '${WINDOW_TARGET}'; ${TMUX_CMD} select-pane -t '${PANE_TARGET}'"
EXECUTE_CMD="${FOCUS_CMD}; ${TMUX_SWITCH}"

# echo "$EXECUTE_CMD" >> /tmp/execute_cmd_debug.txt
terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" -execute "$EXECUTE_CMD"
