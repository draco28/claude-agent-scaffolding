#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$HERE"/test-*.sh; do
  echo "== $t"
  bash "$t" || fail=1
done
[ "$fail" -eq 0 ] && echo "ALL GREEN" || { echo "FAILURES"; exit 1; }
