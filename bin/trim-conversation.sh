#!/bin/sh
# Trim tool_result content from a Claude conversation .jsonl file.
#
# Strategy: replace the inner text of any tool_result that is BOTH
#   - older than the last KEEP_LAST_N_TURNS message lines, AND
#   - longer than SIZE_THRESHOLD_BYTES characters
# with: <head>\n...[trimmed N characters]...\n<tail>
#
# Tool_use to tool_result pairing is preserved (the block stays in place,
# only its inner text is shortened) so the file remains a valid replay.
#
# Length is measured in Unicode code points, not raw bytes. Mostly the same
# in practice; the saved-bytes figure is approximate for non-ASCII content.
#
# Usage:
#   trim-conversation.sh <conversation.jsonl>

set -e

# ===== Configuration =====
KEEP_LAST_N_TURNS=10        # protect tool_results in this many trailing message lines
SIZE_THRESHOLD_BYTES=5000   # only trim tool_results whose text length exceeds this
HEAD_CHARS=100              # leading context to keep
TAIL_CHARS=100              # trailing context to keep
# =========================

if [ $# -ne 1 ]; then
  printf 'usage: %s <conversation.jsonl>\n' "$0" >&2
  exit 64
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
  printf 'not a file: %s\n' "$INPUT" >&2
  exit 1
fi

BACKUP="$INPUT.bak"

if [ -e "$BACKUP" ]; then
  printf 'backup already exists: %s\n' "$BACKUP" >&2
  printf 'rename or remove it before running again\n' >&2
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

mv -- "$INPUT" "$BACKUP"
mv -- "$TMP" "$INPUT"
trap - EXIT

orig_bytes=$(wc -c < "$BACKUP" | tr -d ' ')
new_bytes=$(wc -c < "$INPUT" | tr -d ' ')
saved=$((orig_bytes - new_bytes))
pct=$((saved * 100 / orig_bytes))

printf 'before: %s bytes\n' "$orig_bytes"
printf 'after:  %s bytes\n' "$new_bytes"
printf 'saved:  %s bytes (%s%%)\n' "$saved" "$pct"
printf 'backup: %s\n' "$BACKUP"
