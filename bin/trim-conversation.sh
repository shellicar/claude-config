#!/bin/sh
# Trim a Claude conversation .jsonl file along several independent axes.
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
# Images (the vision axis): this one is not about file size, it is about the
# vision limits. The Claude API downscales every image to a per-model long-edge
# ceiling before the model sees it (2576px for the high-resolution tier that
# includes Opus 4.8; 1568px for the standard tier), and separately caps each
# image at 2000px on the long edge once a request carries more than 20 images.
# An image whose raw long edge exceeds 8000px is rejected outright. So the fix
# is to *resize* rather than remove: base64 image data is decoded with sips,
# resized so its long edge is at most LONG_EDGE_MAX (dropping to
# LONG_EDGE_MAX_MANY when the image count exceeds IMAGE_SOFT_CAP -- most
# restrictive wins), re-encoded, and spliced back in place. Resizing to the
# model's own downscale point is a free loss: only pixels the API would have
# discarded anyway are shed. Because resizing preserves the image, it is not
# clamped to the protected tail -- a too-large recent image (the usual cause of
# a wedged conversation) can only be fixed by reaching into the tail. Removal
# survives only as a safety valve (MAX_IMAGES) against the API's hard per-request
# image count; it is set so high it never fires in practice, and resize does the
# real work.
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
LONG_EDGE_MAX=2576           # vision axis: resize images down to this long edge (Opus 4.8 high-resolution downscale point)
LONG_EDGE_MAX_MANY=2000      # vision axis: tighter long-edge cap once image count exceeds IMAGE_SOFT_CAP (most restrictive wins)
IMAGE_SOFT_CAP=20            # image count beyond which the API drops the per-image cap to LONG_EDGE_MAX_MANY
MAX_IMAGES=300               # removal safety valve: drop oldest images only beyond this count (half the ~600 hard per-request cap; never fires in practice)
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

if ! command -v sips >/dev/null 2>&1; then
  printf 'sips not found on PATH (required for the image resize axis)\n' >&2
  exit 1
fi

TMP=$(mktemp)
TMP_ALL=$(mktemp)
EXTRACT=$(mktemp)
RESIZED=$(mktemp)
MAPFILE=$(mktemp)
WORKDIR=$(mktemp -d)
trap 'rm -f -- "$TMP" "$TMP_ALL" "$EXTRACT" "$RESIZED" "$MAPFILE"; rm -rf -- "$WORKDIR"' EXIT

TAB=$(printf '\t')

# ---- Pass A: extract every image (coordinate, media type, base64), plus the total count. ----
# One line per image: "<msg>/<block>/<inner>\t<media_type>\t<base64>"  (inner -1 = top-level image)
# First line is "COUNT\t<total images>".
jq -rs '
  . as $msgs
  | ([ $msgs[] | (.content // []) | if type == "array" then .[] else empty end
       | if .type == "image" then 1
         elif (.type == "tool_result" and ((.content // null) | type == "array"))
           then (.content | map(select(.type == "image")) | length)
         else 0 end ] | add // 0) as $itotal
  | ("COUNT\t\($itotal)"),
    ( range(0; ($msgs | length)) as $i
      | ($msgs[$i].content // []) as $c
      | range(0; ($c | length)) as $bi
      | ($c[$bi]) as $blk
      | if $blk.type == "image"
          then "\($i)/\($bi)/-1\t\($blk.source.media_type)\t\($blk.source.data)"
        elif ($blk.type == "tool_result" and (($blk.content // null) | type == "array"))
          then (range(0; ($blk.content | length)) as $ni
                | select($blk.content[$ni].type == "image")
                | "\($i)/\($bi)/\($ni)\t\($blk.content[$ni].source.media_type)\t\($blk.content[$ni].source.data)")
        else empty end )
' "$INPUT" > "$EXTRACT"

# ---- sips loop: decode, resize any image whose long edge exceeds the ceiling, re-encode. ----
ITOTAL=0
RESIZE_COUNT=0
RESIZE_SAVED=0
CEILING="$LONG_EDGE_MAX"

: > "$RESIZED"

while IFS="$TAB" read -r key media data; do
  if [ "$key" = "COUNT" ]; then
    ITOTAL="$media"
    # Most restrictive wins: tighten to LONG_EDGE_MAX_MANY once past the soft cap.
    if [ "$ITOTAL" -gt "$IMAGE_SOFT_CAP" ] && [ "$LONG_EDGE_MAX_MANY" -lt "$LONG_EDGE_MAX" ]; then
      CEILING="$LONG_EDGE_MAX_MANY"
    fi
    continue
  fi

  case "$media" in
    image/png)  ext=png ;;
    image/jpeg) ext=jpg ;;
    *)          ext="" ;;   # unsupported by this axis; leave the image untouched
  esac
  [ -z "$ext" ] && continue

  IN="$WORKDIR/in.$ext"
  OUT="$WORKDIR/out.$ext"

  # printf is a shell builtin, so a multi-megabyte base64 argument does not hit ARG_MAX.
  printf '%s' "$data" | base64 -D > "$IN" 2>/dev/null || continue

  dims=$(sips -g pixelWidth -g pixelHeight "$IN" 2>/dev/null) || continue
  w=$(printf '%s\n' "$dims" | awk '/pixelWidth/{print $2}')
  h=$(printf '%s\n' "$dims" | awk '/pixelHeight/{print $2}')
  [ -z "$w" ] || [ -z "$h" ] && continue

  long="$w"
  [ "$h" -gt "$w" ] && long="$h"
  [ "$long" -le "$CEILING" ] && continue

  sips --resampleHeightWidthMax "$CEILING" "$IN" --out "$OUT" >/dev/null 2>&1 || continue
  newdata=$(base64 -i "$OUT" | tr -d '\n')
  [ -z "$newdata" ] && continue

  printf '%s\t%s\n' "$key" "$newdata" >> "$RESIZED"
  RESIZE_COUNT=$((RESIZE_COUNT + 1))
  RESIZE_SAVED=$((RESIZE_SAVED + ${#data} - ${#newdata}))
done < "$EXTRACT"

# ---- Build the coordinate -> new-base64 map for the splice pass. ----
if [ -s "$RESIZED" ]; then
  jq -Rn '[inputs | (index("\t")) as $t | {key: .[0:$t], value: .[($t+1):]}] | from_entries' "$RESIZED" > "$MAPFILE"
else
  printf '{}\n' > "$MAPFILE"
fi

# ---- Pass B: splice resized images in place, then apply the thinking / tool_result / removal axes. ----
jq -sc \
  --slurpfile MAP "$MAPFILE" \
  --argjson N "$KEEP_LAST_N_MESSAGES" \
  --argjson P "$SAVE_THINKING_TARGET_PCT" \
  --argjson X "$SIZE_THRESHOLD_BYTES" \
  --argjson H "$HEAD_CHARS" \
  --argjson T "$TAIL_CHARS" \
  --argjson M "$MAX_IMAGES" '
  ($MAP[0]) as $map
  | def trimmed_text($t):
      ($t[:$H]) + "\n...[trimmed " + (($t | length) - $H - $T | tostring) + " characters]...\n" + ($t[-$T:]);
  def img_placeholder: {type: "text", text: "[image removed]"};
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
  # image axis (removal, safety valve only): total image count across both depths
  | ([ $msgs[] | (.content // []) | .[]
       | if .type == "image" then 1
         elif (.type == "tool_result" and ((.content // null) | type == "array"))
           then (.content | map(select(.type == "image")) | length)
         else 0 end ] | add // 0) as $itotal
  | (if $itotal > $M then $itotal - $M else 0 end) as $idrop
  # coordinates of every droppable image (outside the protected tail), document order, oldest first
  | ([ range(0; $n) as $i
       | select($i < ($n - $N))
       | ($msgs[$i].content // []) as $c
       | range(0; ($c | length)) as $bi
       | ($c[$bi]) as $blk
       | if $blk.type == "image" then {i: $i, b: $bi, k: -1}
         elif ($blk.type == "tool_result" and (($blk.content // null) | type == "array"))
           then (range(0; ($blk.content | length)) as $ni
                 | select($blk.content[$ni].type == "image")
                 | {i: $i, b: $bi, k: $ni})
         else empty end ]) as $icoords
  | (reduce ($icoords[0:$idrop][]) as $x ({};
       .[($x.i | tostring) + "/" + ($x.b | tostring) + "/" + ($x.k | tostring)] = true)) as $dropset
  # per-axis breakdown for thinking / tools / removal (resize is reported by the shell)
  | ([ range(0; $n) as $i | select($i < $eff)
       | ($msgs[$i].content // []) | .[] | select(.type == "thinking") ]) as $tdrop
  | ([ range(0; $n) as $i | select(($i + 1) <= ($n - $N))
       | ($msgs[$i].content // []) | .[]
       | select(.type == "tool_result" and ((.content // null) | type == "array"))
       | .content[] | select(.type == "text") | .text
       | select((length) > $X and (length) > ($H + $T + 50)) ]) as $ttexts
  | ([ $icoords[0:$idrop][] as $co
       | if $co.k == -1 then $msgs[$co.i].content[$co.b]
         else $msgs[$co.i].content[$co.b].content[$co.k] end ]) as $idroplist
  | { thinking: { blocks: ($tdrop | length),
                  bytes: ([ $tdrop[] | tojson | length ] | add // 0) },
      tools:    { blocks: ($ttexts | length),
                  bytes: ([ $ttexts[] | (length) - (trimmed_text(.) | length) ] | add // 0) },
      images:   { blocks: ($idroplist | length),
                  bytes: (([ $idroplist[] | tojson | length ] | add // 0)
                          - (($idroplist | length) * (img_placeholder | tojson | length))) } } as $stats
  | $msgs
  | to_entries
  | map(
      .key as $idx
      | .value
      | if ((.content // null) | type == "array") then
          .content |= (
            # vision axis: splice resized image data by coordinate (all messages, not tail-protected)
            (to_entries | map(
               .key as $bi | .value
               | ($map[($idx | tostring) + "/" + ($bi | tostring) + "/-1"] // null) as $new
               | if (.type == "image" and $new != null) then .source.data = $new
                 elif (.type == "tool_result" and ((.content // null) | type == "array")) then
                   .content |= (to_entries | map(
                     .key as $ni | .value
                     | ($map[($idx | tostring) + "/" + ($bi | tostring) + "/" + ($ni | tostring)] // null) as $inew
                     | if (.type == "image" and $inew != null) then .source.data = $inew
                       else . end))
                 else . end))
            # image removal (safety valve): replace dropped images with a placeholder
            | (if $idx < ($n - $N) then
                 (to_entries | map(
                   .key as $bi | .value
                   | if (.type == "image" and ($dropset[($idx | tostring) + "/" + ($bi | tostring) + "/-1"] // false))
                       then img_placeholder
                     elif (.type == "tool_result" and ((.content // null) | type == "array")) then
                       .content |= (to_entries | map(
                         .key as $ni | .value
                         | if (.type == "image" and ($dropset[($idx | tostring) + "/" + ($bi | tostring) + "/" + ($ni | tostring)] // false))
                             then img_placeholder
                           else . end))
                     else . end))
               else . end)
            | (if $idx < $eff then map(select(.type != "thinking")) else . end)
            | (if ($idx + 1) <= ($n - $N) then
                map(
                  if .type == "tool_result" and ((.content // null) | type == "array") then
                    .content |= map(
                      if .type == "text" then
                        .text as $t
                        | if ($t | length) > $X and ($t | length) > ($H + $T + 50) then
                            .text = trimmed_text($t)
                          else . end
                      else . end
                    )
                  else . end
                )
              else . end)
          )
        else . end
    ) as $out
  | ($stats), ($out[])
' "$INPUT" > "$TMP_ALL"

# The jq program emits the per-axis stats object as its first line, then one
# transformed message per line. Peel the stats off; the remainder is the .jsonl.
STATS=$(head -n 1 "$TMP_ALL")
tail -n +2 "$TMP_ALL" > "$TMP"

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

# Per-axis breakdown. Approximate: these count content code points, not file
# bytes, so the figures will not sum exactly to the total saved above. The
# resize figure comes from the sips loop; the rest from the jq stats object.
printf 'by axis (approx):\n'
printf '  resize:   %s bytes in %s images (long edge -> %spx)\n' "$RESIZE_SAVED" "$RESIZE_COUNT" "$CEILING"
printf '%s\n' "$STATS" | jq -r '
  "  thinking: \(.thinking.bytes) bytes in \(.thinking.blocks) blocks",
  "  tools:    \(.tools.bytes) bytes in \(.tools.blocks) trimmed",
  "  images:   \(.images.bytes) bytes in \(.images.blocks) removed"'

if [ "$DESTRUCTIVE" -eq 1 ]; then
  if [ "$FORCE" -eq 1 ] && [ -e "$BACKUP" ]; then
    printf '%bWARNING: overwriting existing backup at %s%b\n' "$RED" "$BACKUP" "$NC"
  fi
  mv -- "$INPUT" "$BACKUP"
  mv -- "$TMP" "$INPUT"
  trap - EXIT
  # WORKDIR and the other temps are still cleaned; re-arm a minimal cleanup.
  rm -f -- "$TMP_ALL" "$EXTRACT" "$RESIZED" "$MAPFILE"
  rm -rf -- "$WORKDIR"
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
