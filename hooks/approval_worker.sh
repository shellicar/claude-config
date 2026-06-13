#!/bin/sh

# Worker for approval notifications. Runs detached from tmux's process tree,
# invoked by the approval_notify.sh trampoline. All subprocess work (alerter,
# afplay, osascript, tmux send-keys) happens here, outside tmux's heap.

LOG=~/.claude/.hook_history
SOUND_FILE=/System/Library/Sounds/Ping.aiff
SOUND_VOLUME=3
DEBUG_LOG=0
PAYLOAD="$HOOK_PAYLOAD"

# Append a timestamped debug entry to $LOG. Off by default; enable in main().
log_payload() {
  {
    printf '=== %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'stdin: [%s]\n' "$PAYLOAD"
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
  SESSION_TARGET=$($TMUX_CMD display-message -t "$TMUX_PANE" -p '#{session_name}')
  WINDOW_TARGET=$($TMUX_CMD display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}')
  PANE_TARGET=$($TMUX_CMD display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index}')
  WINDOW_TITLE=$($TMUX_CMD display-message -t "$TMUX_PANE" -p '#{?#{@title},#{@title},#{window_name}}')
  PANE_ROLE=$($TMUX_CMD display-message -t "$TMUX_PANE" -p '#{@role}')
}

# Resolve the iTerm2 window id whose tty matches the tmux client, so clicking
# the notification can raise the correct iTerm2 window.
resolve_iterm_window() {
  CLIENT_TTY=$($TMUX_CMD display-message -p '#{client_tty}')
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
# the notification appears while the sound plays. Safe to fork here because
# this process is already outside tmux's process tree.
play_sound() {
  afplay -v "$SOUND_VOLUME" "$SOUND_FILE" &
}

# True if the tmux client is on a different session/window/pane from the one
# requesting approval (i.e. the SC won't see the prompt without switching).
client_is_elsewhere() {
  CLIENT_SESSION=$($TMUX_CMD display-message -p '#{client_session}')
  CLIENT_WINDOW=$($TMUX_CMD display-message -p '#{client_session}:#{window_index}')
  CLIENT_PANE=$($TMUX_CMD display-message -p '#{client_session}:#{window_index}.#{pane_index}')
  [ "$CLIENT_SESSION" != "$SESSION_TARGET" ] || \
    [ "$CLIENT_WINDOW" != "$WINDOW_TARGET" ] || \
    [ "$CLIENT_PANE" != "$PANE_TARGET" ]
}

# Post the macOS notification via alerter. Blocks until the user responds,
# then sends the approval keystroke or navigates to the pane. Blocking is
# fine because this worker is already a detached background process.
notify() {
  TITLE="Claude Code · ${SESSION_TARGET} / ${WINDOW_TITLE}"
  MESSAGE="Approval needed: ${TOOL_NAME}${PANE_ROLE:+ (${PANE_ROLE})}"
  NAVIGATE="${EXECUTE_CMD}"
  SEND_KEYS="${TMUX_CMD} send-keys -t ${TMUX_PANE}"
  ANSWER=$(alerter --message "$MESSAGE" --title "$TITLE" --actions 'Yes,No')
  case "$ANSWER" in
    "Yes") $SEND_KEYS Y ;;
    "No") $SEND_KEYS N ;;
    "@CONTENTCLICKED") eval "$NAVIGATE" ;;
  esac
}

main() {
  [ "$DEBUG_LOG" = "1" ] && log_payload
  parse_tool_name
  gather_tmux_targets
  resolve_iterm_window
  build_execute_cmd

  if client_is_elsewhere; then
    play_sound
    notify
  fi
}

main
