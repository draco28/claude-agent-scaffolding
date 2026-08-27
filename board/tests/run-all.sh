#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$HERE"/test-*.sh; do
  echo "== $t"
  bash "$t" || fail=1
done
if [ "$fail" -eq 0 ]; then
  echo "ALL GREEN"
else
  echo "FAILURES"; exit 1
fi
