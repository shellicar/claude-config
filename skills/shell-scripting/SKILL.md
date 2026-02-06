---
name: shell-scripting
description: Guidelines for portable, POSIX-compliant shell scripts. Apply when writing, reviewing, or modifying shell scripts or .sh files.
user-invocable: false
---

# Shell Scripting Guidelines

Write portable shell scripts that work across systems.

## Quick Reference

| Use This (POSIX) | Not This (Bash) |
|------------------|-----------------|
| `#!/bin/sh` | `#!/bin/bash` |
| `[ -z "$VAR" ]` | `[[ -z "$VAR" ]]` |
| `[ "$A" = "B" ]` | `[[ "$A" == "B" ]]` |
| `$(command)` | `` `command` `` |
| `${VAR:-default}` | (same, this is POSIX) |

## Shebang

Always use POSIX Bourne shell:

```sh
#!/bin/sh
```

**Never use** `#!/bin/bash` unless bash-specific features are absolutely required and documented.

## Error Handling

Use `set +e` by default - handle errors explicitly rather than exiting on first failure:

```sh
set +e
```

## POSIX Compatibility

### Test Constructs

Use single brackets `[` instead of double brackets `[[`:

```sh
# CORRECT (POSIX)
if [ -z "$VAR" ]; then
if [ "$VAR" = "value" ]; then
if [ "$A" = "B" ] || [ "$C" = "D" ]; then

# WRONG (bash-specific)
if [[ -z "$VAR" ]]; then
if [[ "$VAR" == "value" ]]; then
if [[ "$A" == "B" || "$C" == "D" ]]; then
```

### String Comparison

Use `=` not `==`:

```sh
# CORRECT (POSIX)
if [ "$VAR" = "value" ]; then

# WRONG (bash-specific)
if [ "$VAR" == "value" ]; then
```

### Arrays

POSIX shell does not support arrays. Use positional parameters or separate variables:

```sh
# CORRECT (POSIX)
set -- "item1" "item2" "item3"
for item in "$@"; do
  echo "$item"
done

# WRONG (bash-specific)
arr=("item1" "item2" "item3")
for item in "${arr[@]}"; do
```

### Function Definitions

Use portable function syntax:

```sh
# CORRECT (POSIX)
my_function() {
  echo "hello"
}

# Also acceptable
my_function() { echo "hello"; }

# WRONG (bash-specific)
function my_function {
  echo "hello"
}
```

### Local Variables

`local` is not strictly POSIX but widely supported. If maximum portability is needed, avoid it:

```sh
# Widely portable (but not strictly POSIX)
my_function() {
  local var="value"
}

# Strictly POSIX (use naming conventions)
my_function() {
  _my_function_var="value"
}
```

### Command Substitution

Use `$()` instead of backticks for readability and nesting:

```sh
# PREFERRED
result=$(command)
nested=$(echo $(date))

# AVOID (hard to read and nest)
result=`command`
```

### Here Documents

Use quoted delimiter to prevent variable expansion when needed:

```sh
# Variables expanded
cat <<EOF
Hello $USER
EOF

# Variables NOT expanded (note quotes)
cat <<'EOF'
Hello $USER prints literally
EOF
```

### Arithmetic

Use `$(( ))` for arithmetic, not `let` or `(( ))`:

```sh
# CORRECT (POSIX)
count=$((count + 1))
result=$((a * b))

# WRONG (bash-specific)
let count++
((count++))
```

## Common Portable Commands

### Output

```sh
# CORRECT - printf is more portable than echo
printf '%s\n' "$message"
printf '%s' "$no_newline"

# echo behavior varies - use for simple cases only
echo "simple message"
```

### Emojis in Output

Prefer emojis over unicode characters for user feedback - they have color and more variety:

```sh
# Emojis (preferred)
echo "✅ Operation successful"
echo "❌ Operation failed"

# Unicode characters (also fine)
echo "✓ Operation successful"
echo "✗ Operation failed"
```

Modern terminals handle UTF-8 emojis correctly.

### Reading Input

```sh
# Read a line
read -r line

# Always use -r to prevent backslash interpretation
```

### Temporary Files

```sh
# CORRECT (POSIX)
tmp_file=$(mktemp)

# Clean up on exit
trap 'rm -f "$tmp_file"' EXIT
```

### Finding Commands

```sh
# CORRECT (POSIX)
if command -v git >/dev/null 2>&1; then
  echo "git is installed"
fi

# WRONG (bash-specific)
if type -t git >/dev/null; then
if hash git 2>/dev/null; then
```

## Required Parameters

When scripts interact with external systems (APIs, different tenants, orgs), make identifying parameters **required**, not optional:

```sh
# CORRECT - org is required
if [ -z "$ORG" ]; then
  echo "Error: --org is required" >&2
  exit 1
fi

# WRONG - defaulting could hit wrong system
ORG="${ORG:-default}"
```

This prevents accidentally operating on the wrong system.

## Argument Parsing

Use a while loop with case statement:

```sh
while [ $# -gt 0 ]; do
  case $1 in
    --org)
      ORG="$2"
      shift 2
      ;;
    --id)
      ID="$2"
      shift 2
      ;;
    --flag)
      FLAG=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done
```

## File Tests

All standard file tests are POSIX:

```sh
[ -f "$file" ]   # regular file exists
[ -d "$dir" ]    # directory exists
[ -e "$path" ]   # path exists
[ -r "$file" ]   # readable
[ -w "$file" ]   # writable
[ -x "$file" ]   # executable
[ -s "$file" ]   # file exists and not empty
[ -z "$var" ]    # string is empty
[ -n "$var" ]    # string is not empty
```

## Quoting

Always quote variables to handle spaces and special characters:

```sh
# CORRECT
echo "$variable"
[ -f "$file" ]
command "$arg1" "$arg2"

# WRONG - breaks on spaces
echo $variable
[ -f $file ]
command $arg1 $arg2
```

## Validation

Check scripts with ShellCheck in POSIX mode:

```sh
# If installed locally
shellcheck -s sh script.sh

# Via Docker
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable -s sh /mnt/script.sh
```

## Security

Use `--` to separate options from arguments (prevents injection):

```sh
rm -- "$file"
grep -- "$pattern" "$file"
```

## Script Template

```sh
#!/bin/sh
# Description of what this script does
#
# Usage:
#   script.sh --org <ORG> --id <ID> [--flag]

set +e

# Parse arguments
ORG=""
ID=""
FLAG=0

while [ $# -gt 0 ]; do
  case $1 in
    --org)
      ORG="$2"
      shift 2
      ;;
    --id)
      ID="$2"
      shift 2
      ;;
    --flag)
      FLAG=1
      shift
      ;;
    -h|--help)
      echo "Usage: script.sh --org <ORG> --id <ID> [--flag]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$ORG" ]; then
  echo "Error: --org is required" >&2
  exit 1
fi

if [ -z "$ID" ]; then
  echo "Error: --id is required" >&2
  exit 1
fi

# Main logic here
```
