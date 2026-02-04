#!/bin/sh

input=$(cat)

case "$input" in
  *xargs*)           echo "BLOCKED: xargs" >&2; exit 2 ;;
  *sed*)             echo "BLOCKED: sed" >&2; exit 2 ;;
  *"git checkout"*)  echo "BLOCKED: git checkout" >&2; exit 2 ;;
  *'"rm '*|*'"rm"'*) echo "BLOCKED: rm" >&2; exit 2 ;;
esac

exit 0
