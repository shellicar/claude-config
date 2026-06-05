#!/bin/sh

# Hook for Claude Code's tool-approval prompts.
# Posts a macOS notification, plays a sound, and clicking the notification
# focuses iTerm2 and switches tmux to the originating session/window/pane.

LOG=~/.claude/.hook_history
SOUND_FILE=/System/Library/Sounds/Ping.aiff
SOUND_VOLUME=3
DEBUG_LOG=0

# Capture stdin (the JSON payload) into $PAYLOAD. Guarded with [ -t 0 ] so an
# interactive (no-pipe) run can't hang on cat.
capture_stdin() {
  if [ ! -t 0 ]; then
    PAYLOAD=$(cat)
    STDIN_READ=1
  else
    PAYLOAD=""
    STDIN_READ=0
  fi
}

# Append a timestamped debug entry to $LOG. Off by default; enable in main().
log_payload() {
  {
    printf '=== %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    if [ "$STDIN_READ" = "1" ]; then
      printf 'stdin: [%s]\n' "$PAYLOAD"
    else
      printf 'stdin: (no pipe; skipped)\n'
    fi
  } >> "$LOG"
}

# Extract .name from the JSON payload into $TOOL_NAME; fall back to "Unknown".
parse_tool_name() {
  TOOL_NAME=$(printf '%s' "$PAYLOAD" | /usr/bin/jq -r '.name // "Unknown"' 2>/dev/null)
  if [ -z "$TOOL_NAME" ] || [ "$TOOL_NAME" = "null" ]; then
    TOOL_NAME="Unknown"
  fi
}

# Resolve tmux targets for the originating pane: SESSION_TARGET, WINDOW_TARGET,
# PANE_TARGET drive click-to-switch; WINDOW_TITLE (prefers @title, falls back
# to window name) and PANE_ROLE (empty if @role not set) feed the notification.
gather_tmux_targets() {
  TMUX_SOCKET=$(echo "$TMUX" | cut -d, -f1)
  TMUX_CMD="/opt/homebrew/bin/tmux -S ${TMUX_SOCKET}"
  SESSION_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}')
  WINDOW_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}')
  PANE_TARGET=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index}')
  WINDOW_TITLE=$(tmux display-message -t "$TMUX_PANE" -p '#{?#{@title},#{@title},#{window_name}}')
  PANE_ROLE=$(tmux display-message -t "$TMUX_PANE" -p '#{@role}')
}

# Resolve the iTerm2 window id whose tty matches the tmux client, so clicking
# the notification can raise the correct iTerm2 window.
resolve_iterm_window() {
  CLIENT_TTY=$(tmux display-message -p '#{client_tty}')
  ITERM_WINDOW_ID=$(osascript -e 'tell application "iTerm2"' -e 'repeat with w in every window' -e 'repeat with t in every tab of w' -e 'repeat with s in every session of t' -e "if tty of s is \"${CLIENT_TTY}\" then return id of w" -e 'end repeat' -e 'end repeat' -e 'end repeat' -e 'end tell')
}

# Build $EXECUTE_CMD: focus iTerm2 window, then switch tmux to the originating
# session/window/pane.
build_execute_cmd() {
  FOCUS_CMD="osascript -e 'tell application \"iTerm2\"' -e 'activate' -e 'select window id ${ITERM_WINDOW_ID}' -e 'end tell'"
  TMUX_SWITCH="${TMUX_CMD} switch-client -t '${SESSION_TARGET}'; ${TMUX_CMD} select-window -t '${WINDOW_TARGET}'; ${TMUX_CMD} select-pane -t '${PANE_TARGET}'"
  EXECUTE_CMD="${FOCUS_CMD}; ${TMUX_SWITCH}"
}

# Play the notification sound at louder-than-default volume, backgrounded so
# the script doesn't block. terminal-notifier's -sound goes through
# Notification Center at fixed system volume; afplay -v lets us turn it up.
play_sound() {
  afplay -v "$SOUND_VOLUME" "$SOUND_FILE" &
}

# True if the tmux client is on a different session/window/pane from the one
# requesting approval (i.e. the SC won't see the prompt without switching).
client_is_elsewhere() {
  CLIENT_SESSION=$(tmux display-message -p '#{client_session}')
  CLIENT_WINDOW=$(tmux display-message -p '#{client_session}:#{window_index}')
  CLIENT_PANE=$(tmux display-message -p '#{client_session}:#{window_index}.#{pane_index}')
  [ "$CLIENT_SESSION" != "$SESSION_TARGET" ] || \
    [ "$CLIENT_WINDOW" != "$WINDOW_TARGET" ] || \
    [ "$CLIENT_PANE" != "$PANE_TARGET" ]
}

# Post the macOS notification.
notify() {
  TITLE="Claude Code · ${SESSION_TARGET} / ${WINDOW_TITLE}"
  MESSAGE="Approval needed: ${TOOL_NAME}${PANE_ROLE:+ (${PANE_ROLE})}"
  terminal-notifier -title "$TITLE" -message "$MESSAGE" -execute "$EXECUTE_CMD"
}

main() {
  capture_stdin
  [ "$DEBUG_LOG" = "1" ] && log_payload
  parse_tool_name
  gather_tmux_targets
  resolve_iterm_window
  build_execute_cmd

  # Always send BEL: heard if we're on this session, marks the window if not.
  printf '\a'

  if client_is_elsewhere; then
    play_sound
    notify
  fi
}

main
