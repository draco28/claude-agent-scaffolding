#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Layer 4 delegated-verification gates (#139).
#
# T1 - static purity over ossify/workflows/*.js: the script is orchestration
#      and must stay that way (skill-first, C1). Parses as JS; no require/
#      import, no fs/process/child_process/exec/spawn, no node: specifiers,
#      no string literal that looks like a path (the script receives every
#      path via args).
# T2 - lens-id parity: the ids declared in impl-check.md §4b and the ids the
#      close passes in args (work-item-close.md §2) are the same set. A lens
#      added to one file and not the other must go RED here.
#
# Self-test: both checks run a second time against a planted-defect fixture
# and must report exactly that defect (testing discipline: a green sweep that
# was never proved to be looking certifies nothing).
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
T_FAIL=0
ck() { if [ "$1" -gt 0 ]; then T_FAIL=$((T_FAIL+1)); fi; }

# --- T1: static purity -----------------------------------------------------
WF="$ROOT/workflows"
[ -d "$WF" ] || { echo "FAIL: no workflows/ directory"; exit 1; }
purify() { # file -> violations on stdout
  local f="$1"
  # NOT `node --check`: workflow scripts run wrapped in an async context the
  # Workflow tool supplies (top-level `return`/`await` are the documented,
  # correct shape - see workflow-authoring's own worked examples). Checking
  # this file as a standalone ESM module (this repo's package.json sets
  # "type": "module") makes top-level `return` a SyntaxError and would reject
  # every legitimate workflow script. Static purity is a grep concern, not a
  # parser concern - T1's own scope (spec T1) never asked for a parse check.
  grep -nE '\brequire[ (]|\bimport\b|\bprocess\.|child_process|\bexec(Sync)?\s*\(|\bspawn(Sync)?\s*\(|\bfs\.|node:' "$f"
  # Absolute (/x), dot-relative (./x, ../x), AND bare relative (docs/spec.md) -
  # a quote immediately followed by word characters then a slash. Anchored to
  # right-after-the-quote so a mid-sentence slash in ordinary prose - e.g. the
  # meta block's own "one Sonnet/medium reader per lens" - does not false-fire;
  # only a slash that could plausibly start a path does.
  grep -nE '["'"'"'](\.{1,2}/|/|[A-Za-z0-9_.-]+/)' "$f"
}
VIOL=""
for f in "$WF"/*.js; do
  [ -e "$f" ] || continue
  # A direct call in THIS shell, never `find -exec sh -c 'purify ...'` — that
  # spawns a subshell with no visibility into a bash function, "command not
  # found" on stderr, and VIOL captures only stdout: a purity checker that
  # silently never runs and reports the file clean regardless of content.
  VIOL="$VIOL$(purify "$f")"
done
[ -z "$VIOL" ] || { echo "FAIL: workflow purity violations:"; echo "$VIOL"; ck 1; }

# --- T2: lens-id parity ----------------------------------------------------
IC="$ROOT/skills/close/references/impl-check.md"
WC="$ROOT/skills/close/references/work-item-close.md"
# NOT `tr -d '`- '`: with the hyphen between two other characters, GNU tr on
# the CI runner parses it as the range `` `-<space> `` (backtick to space) -
# a REVERSED range since backtick's code point is higher - and errors out,
# leaving sec4b empty and this check failing for the wrong reason (caught on
# PR #380's own CI; BSD tr on this machine accepted it silently). A bracket
# expression with the hyphen placed FIRST is unambiguous on both.
sec4b="$(awk '/^## 4b\./{f=1;next} /^## 5\./{f=0} f' "$IC" | grep -oE '^- `[a-z]+`' | sed 's/[-` ]//g' | sort -u)"
wipass="$(awk '/^## 2\. The gate/{f=1;next} /^## 3\./{f=0} f' "$WC" | grep -oE '`[a-z]+`' | tr -d '`' | sort -u | grep -E '^(fidelity|pattern|absence)$')"
EXPECT="$(printf 'absence\nfidelity\npattern')"
[ "$sec4b" = "$EXPECT" ] || { echo "FAIL: impl-check §4b lens ids are: [$sec4b]"; ck 1; }
[ "$wipass" = "$EXPECT" ] || { echo "FAIL: work-item-close.md §2 passes lenses: [$wipass]"; ck 1; }

# --- self-test: planted defects must be caught -----------------------------
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf 'const x = require("fs");\nconst p = "/etc/passwd";\nconst q = "docs/spec.md";\n' > "$TMP/bad.js"
BAD="$(purify "$TMP/bad.js")"
[ -n "$BAD" ] || { echo "FAIL: purity checker missed the planted require/fs/path defects"; ck 1; }
printf '%s\n' "$BAD" | grep -q 'docs/spec.md' \
  || { echo "FAIL: purity checker missed the planted BARE-RELATIVE path (docs/spec.md) - the anchored regex may be too narrow again"; ck 1; }

AWK1="$(awk '/^## 4b\./{f=1;next} /^## 5\./{f=0} f' "$IC" | grep -cE '^- `[a-z]+`')"
[ "$AWK1" -ge 3 ] || { echo "FAIL: §4b lens extractor is blind (found $AWK1 ids)"; ck 1; }

[ "$T_FAIL" -eq 0 ] && echo "test-workflows: ALL GREEN" || exit 1
