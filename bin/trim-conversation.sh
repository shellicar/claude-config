#!/bin/sh
# Trim a Claude conversation .jsonl file along two independent axes.
#
# Thinking (the heavy axis): on Claude 4 models almost all of a thinking
# block's weight is the encrypted signature, not the readable text, so
# emptying .thinking reclaims almost nothing. Instead, drop whole thinking
# blocks oldest-first until SAVE_THINKING_TARGET_PCT of the file's total
# thinking bytes is reclaimed. The cut is clamped so it never enters the last
# KEEP_LAST_N_MESSAGES messages -- the target yields to that floor, so a small
# conversation may save less than the target. Dropping whole prior-turn
# thinking blocks is API-sanctioned; keeping a block while altering its
# signature would be rejected on replay.
#
# Tool_results (the light axis): the inner text of any tool_result older than
# the last KEEP_LAST_N_MESSAGES messages and longer than SIZE_THRESHOLD_BYTES
# is shortened to <head>\n...[trimmed N characters]...\n<tail>. The block stays
# in place, so tool_use/tool_result pairing -- and the replay -- is preserved.
#
# Length is measured in Unicode code points, not raw bytes. Mostly the same
# in practice; the saved-bytes figure is approximate for non-ASCII content.
#
# Usage:
#   trim-conversation.sh <conversation.jsonl>             # dry run (default)
#   trim-conversation.sh -d <conversation.jsonl>          # apply (renames original to .bak)
#   trim-conversation.sh -d -f <conversation.jsonl>       # apply, overwrite existing .bak

set -e

# ===== Configuration =====
KEEP_LAST_N_MESSAGES=10      # protected tail: never drop thinking or trim tool_results in this many trailing messages
SAVE_THINKING_TARGET_PCT=50  # drop oldest whole thinking blocks until this % of total thinking bytes is reclaimed (clamped by the tail)
SIZE_THRESHOLD_BYTES=50      # only trim tool_results whose text length exceeds this
HEAD_CHARS=10                # leading context to keep in a trimmed tool_result
TAIL_CHARS=10                # trailing context to keep in a trimmed tool_result
# =========================

DESTRUCTIVE=0
FORCE=0
INPUT=""

# TTY-aware red: marks the dangerous combination of -f and an existing .bak.
if [ -t 1 ]; then
  RED='\033[1;31m'
  NC='\033[0m'
else
  RED=''
  NC=''
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--destructive) DESTRUCTIVE=1; shift ;;
    -f|--force) FORCE=1; shift ;;
    -h|--help)
      printf 'usage: %s [-d|--destructive] [-f|--force] <conversation.jsonl>\n' "$0"
      exit 0
      ;;
    -*)
      printf 'unknown option: %s\n' "$1" >&2
      exit 64
      ;;
    *)
      if [ -n "$INPUT" ]; then
        printf 'too many arguments\n' >&2
        exit 64
      fi
      INPUT="$1"; shift
      ;;
  esac
done

if [ -z "$INPUT" ]; then
  printf 'usage: %s [-d|--destructive] [-f|--force] <conversation.jsonl>\n' "$0" >&2
  exit 64
fi

if [ ! -f "$INPUT" ]; then
  printf 'not a file: %s\n' "$INPUT" >&2
  exit 1
fi

BACKUP="$INPUT.bak"

if [ "$DESTRUCTIVE" -eq 1 ] && [ -e "$BACKUP" ] && [ "$FORCE" -eq 0 ]; then
  printf 'backup already exists: %s\n' "$BACKUP" >&2
  printf 'rename or remove it, or use -f to overwrite\n' >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq not found on PATH\n' >&2
  exit 1
fi

TMP=$(mktemp)
trap 'rm -f -- "$TMP"' EXIT

jq -sc \
  --argjson N "$KEEP_LAST_N_MESSAGES" \
  --argjson P "$SAVE_THINKING_TARGET_PCT" \
  --argjson X "$SIZE_THRESHOLD_BYTES" \
  --argjson H "$HEAD_CHARS" \
  --argjson T "$TAIL_CHARS" '
  . as $msgs
  | ($msgs | length) as $n
  # thinking-byte weight of each message, oldest first
  | ([ $msgs[]
       | ([ (.content // [])
            | if type == "array" then .[] else empty end
            | select(.type == "thinking") | (tostring | length) ] | add // 0) ]) as $tb
  | ($tb | add // 0) as $total
  | ($total * $P / 100) as $target
  # fewest oldest messages whose thinking reaches the target
  | (if $P <= 0 then 0
     else (reduce range(0; $n) as $i ({s: 0, k: null};
             if .k != null then .
             else (.s + $tb[$i]) as $ns
               | if $ns >= $target then {s: $ns, k: ($i + 1)} else {s: $ns, k: null} end
             end) | .k // $n)
     end) as $cut
  # clamp so the cut never enters the protected tail of $N trailing messages
  | ([[$cut, ($n - $N)] | min, 0] | max) as $eff
  | $msgs
  | to_entries
  | map(
      .key as $idx
      | .value
      | if ((.content // null) | type == "array") then
          .content |= (
            (if $idx < $eff then map(select(.type != "thinking")) else . end)
            | (if ($idx + 1) <= ($n - $N) then
                map(
                  if .type == "tool_result" and ((.content // null) | type == "array") then
                    .content |= map(
                      if .type == "text" then
                        .text as $t
                        | if ($t | length) > $X and ($t | length) > ($H + $T + 50) then
                            .text = (($t[:$H])
                                     + "\n...[trimmed "
                                     + (($t | length) - $H - $T | tostring)
                                     + " characters]...\n"
                                     + ($t[-$T:]))
                          else . end
                      else . end
                    )
                  else . end
                )
              else . end)
          )
        else . end
    )
  | .[]
' "$INPUT" > "$TMP"

# Sanity: record count must match (one JSON object per line in .jsonl).
# Using awk NR rather than wc -l so a missing trailing newline doesn't trip the check.
orig_records=$(awk 'END{print NR}' "$INPUT")
new_records=$(awk 'END{print NR}' "$TMP")
if [ "$orig_records" != "$new_records" ]; then
  printf 'record count mismatch: orig=%s new=%s\n' "$orig_records" "$new_records" >&2
  printf 'leaving original in place; transformed output is at %s\n' "$TMP" >&2
  trap - EXIT
  exit 1
fi

orig_bytes=$(wc -c < "$INPUT" | tr -d ' ')
new_bytes=$(wc -c < "$TMP" | tr -d ' ')
saved=$((orig_bytes - new_bytes))
pct=$((saved * 100 / orig_bytes))

printf 'before: %s bytes\n' "$orig_bytes"
printf 'after:  %s bytes\n' "$new_bytes"
printf 'saved:  %s bytes (%s%%)\n' "$saved" "$pct"

if [ "$DESTRUCTIVE" -eq 1 ]; then
  if [ "$FORCE" -eq 1 ] && [ -e "$BACKUP" ]; then
    printf '%bWARNING: overwriting existing backup at %s%b\n' "$RED" "$BACKUP" "$NC"
  fi
  mv -- "$INPUT" "$BACKUP"
  mv -- "$TMP" "$INPUT"
  trap - EXIT
  printf 'backup: %s\n' "$BACKUP"
else
  printf 'DRY RUN — no files changed. Re-run with -d to apply.\n'
  if [ -e "$BACKUP" ]; then
    if [ "$FORCE" -eq 1 ]; then
      printf '%bWARNING: destructive run would OVERWRITE existing backup at %s%b\n' "$RED" "$BACKUP" "$NC"
    else
      printf 'note: destructive run would refuse — backup already exists at %s\n' "$BACKUP"
    fi
  fi
fi
