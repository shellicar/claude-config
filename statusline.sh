#!/bin/bash
# Enhanced status line with context usage, model, and session info

input=$(cat)

# Extract data from JSON input
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
dir_basename=$(basename "${current_dir:-$HOME}")
model_name=$(echo "$input" | jq -r '.model.display_name')
session_name=$(echo "$input" | jq -r '.session_name // empty')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
DURATION_SEC=$((DURATION_MS / 1000))
MINS=$((DURATION_SEC / 60))
SECS=$((DURATION_SEC % 60))
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
ctx_used=$(echo "$input" | jq -r '(.context_window.current_usage | (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

# Current timestamp
timestamp=$(date '+%d/%m %H:%M:%S')

# Build status line components
status=""

# Timestamp first (dim, matching tmux/prompt format)
status+=$(printf '\e[0;90m%s\e[0m ' "$timestamp")

# User@host and directory (green user, blue host, magenta dir)
status+=$(printf '\e[0;32m%s\e[0m@\e[1;34m%s\e[0m \e[0;35m%s\e[0m' \
  "$(whoami)" "$(hostname -s)" "$dir_basename")

# Session name if set (cyan)
if [ -n "$session_name" ]; then
  status+=$(printf ' \e[0;36m[%s]\e[0m' "$session_name")
fi

# Model name (yellow)
if [ -n "$model_name" ]; then
  status+=$(printf ' \e[0;33m%s\e[0m' "$model_name")
fi

# Output style if not default (magenta)
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  status+=$(printf ' \e[0;35m(%s)\e[0m' "$output_style")
fi

# Cost (cyan)
cost_fmt=$(printf '%.2f' "${cost:-0}")
status+=$(printf ' \e[0;36m$%s\e[0m' "$cost_fmt")

# Duration (white)
status+=$(printf ' 🕐%02d:%02d' "$MINS" "$SECS")

# Input/output tokens (white)
fmt_tokens() {
  local t=$1
  if [ "$t" -ge 1000000 ]; then
    printf '%.1fM' "$(echo "$t / 1000000" | bc -l)"
  elif [ "$t" -ge 1000 ]; then
    printf '%.1fk' "$(echo "$t / 1000" | bc -l)"
  else
    printf '%d' "$t"
  fi
}
status+=$(printf ' \e[0;37m↓%s ↑%s\e[0m' "$(fmt_tokens "$input_tokens")" "$(fmt_tokens "$output_tokens")")

# Context window usage
ctx_used_fmt=$(fmt_tokens "$ctx_used")
ctx_size_fmt=$(fmt_tokens "$ctx_size")
status+=$(printf ' 💬%s/%s' "$ctx_used_fmt" "$ctx_size_fmt")

# Context usage with color coding
if [ -n "$remaining_pct" ]; then
  # Color based on remaining percentage:
  # Green: >50%, Yellow: 20-50%, Red: <20%
  if (( $(echo "$remaining_pct > 50" | bc -l) )); then
    color='\e[0;32m'  # Green
  elif (( $(echo "$remaining_pct > 20" | bc -l) )); then
    color='\e[0;33m'  # Yellow
  else
    color='\e[0;31m'  # Red
  fi
  status+=$(printf " ${color}%s%%\e[0m" "${remaining_pct%.*}")
fi

echo -n "$status"
