#!/bin/sh
# Trim tool_result content and thinking text from a Claude conversation .jsonl file.
#
# Strategy: replace the inner text of any tool_result that is BOTH
#   - older than the last KEEP_LAST_N_TURNS message lines, AND
#   - longer than SIZE_THRESHOLD_BYTES characters
# with: <head>\n...[trimmed N characters]...\n<tail>
#
# Tool_use to tool_result pairing is preserved (the block stays in place,
# only its inner text is shortened) so the file remains a valid replay.
#
# Thinking blocks older than KEEP_LAST_N_TURNS message lines have their
# .thinking string emptied; .type and .signature are left in place.
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
KEEP_LAST_N_TURNS=10        # protect tool_results and thinking in this many trailing message lines
SIZE_THRESHOLD_BYTES=50     # only trim tool_results whose text length exceeds this
HEAD_CHARS=10               # leading context to keep
TAIL_CHARS=10               # trailing context to keep
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
  --argjson N "$KEEP_LAST_N_TURNS" \
  --argjson X "$SIZE_THRESHOLD_BYTES" \
  --argjson H "$HEAD_CHARS" \
  --argjson T "$TAIL_CHARS" '
  . as $msgs
  | ($msgs | length) as $n
  | $msgs
  | to_entries
  | map(
      .key as $idx
      | .value
      | if (($idx + 1) <= ($n - $N)) and ((.content // null) | type == "array") then
          .content |= map(
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
            elif .type == "thinking" then
              .thinking = ""
            else . end
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
