#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SKILL.md bash-block harness - prose gets CI.
#
# ossify's skills ARE the product: a ceremony is prose, and a bash block inside
# it is a shipped contract. Nothing else in this suite reads that prose, so a
# skill can document a verb no dispatcher implements, a `Skill()` parameter the
# runtime does not accept, or a block that does not parse, and every gate stays
# green. This file is that gate.
#
# SCOPE - check, do not execute. Eight mechanical facts: parse-validity, verb
# resolution, Skill() arity, the command-body arg bridge, reference
# reachability, the SKILL.md line budget, command route-pointer integrity,
# and shadowed Skill(ossify:) tokens. Executing skill prose would need
# a fixture per ceremony, would have side effects, and would test the fixture
# instead of the contract.
#
# WHAT IT HONESTLY DOES NOT CATCH. Check 2 resolves `oss <subcommand>` tokens -
# ossify's own dispatcher verbs. A phantom *lib function* (the `sd_rules_apply`
# class: five citations, zero definitions) is not an `oss` subcommand and does
# not pass through here; what check 2 catches is the analogous class inside
# ossify's verb surface. And a cross-skill *semantic* contract - the `[internal]`
# marker one skill sets and another reads - is not a parse or symbol fact at
# all, so no check below can see it. Nor does check 2 read bare prose: it scans
# code contexts only (fenced blocks and inline-code spans), so `oss frobnicate`
# written in a sentence without backticks is not a contract citation and is not
# resolved. Those are the boundaries; a test credited with coverage it does not
# have is how the next phantom entry point ships.
#
# THE SELF-TEST IS THE POINT. This artifact is itself a test, so an extractor
# that silently stops extracting goes green forever and takes all eight checks
# with it - and nothing downstream can notice. Every check therefore runs twice:
# once against the shipped tree (expect zero findings) and once against a
# purpose-built fixture carrying exactly one planted defect per check (expect
# exactly that one, named). A run is only meaningful because the second half
# proves the first half was still looking.
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
OSSIFY="$(cd "$HERE/.." && pwd)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/oss-blocks.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Byte-based matching everywhere: the RSTART/RLENGTH arithmetic below is byte
# arithmetic, and a UTF-8 locale would make the two disagree.
export LC_ALL=C

_count() { # line count of a captured findings blob, 0 when empty
  if [ -z "$1" ]; then echo 0; else printf '%s\n' "$1" | wc -l | tr -d ' '; fi
}
_lines() { wc -l < "$1" | tr -d ' '; }
t_assert_ge() { # $1=floor $2=actual $3=label
  if [ "$2" -ge "$1" ] 2>/dev/null; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (expected >= $1, got '$2')"; fi
}
t_assert_grep() { # $1=file $2=ERE $3=label
  if grep -qE "$2" "$1" 2>/dev/null; then T_PASS=$((T_PASS+1))
  else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (no /$2/ in $1)"; fi
}

_md_files() { # $1=ossify-root -> every markdown file the harness owns
  local r="$1" d
  # references/ included since the route gates landed: three wrappers load
  # the plugin-root references tree directly (handoff, handoff-resume,
  # work-pr), so its prose is shipped contract with the same claim to scanning
  # as skills/. Blast radius measured before widening: the four shipped files
  # carry zero bash fences, zero Skill( forms, zero oss tokens, so checks 1-3
  # widen with no new findings (Codex r1 finding on #283).
  for d in skills commands agents references; do
    [ -d "$r/$d" ] && find "$r/$d" -type f -name '*.md'
  done | sort
}

# ---------------------------------------------------------------------------
# Extractors. Written once and shared by the checks - so a break in one takes
# the fixture plants down with it and the self-test goes red, instead of the
# shipped tree going quietly clean.
# ---------------------------------------------------------------------------

# THE FENCE CONTRACT, and why both regexes tolerate leading whitespace:
# 8 of the shipped bash blocks are indented inside list items, and an anchored
# ^```bash$ skips them without a word. Opener ^[ \t]*```bash[ \t]*$, closer
# ^[ \t]*```[ \t]*$. The state machine also gets the nesting right - only a
# BARE fence closes a block, so a ```bash line appearing inside a ```text block
# is content, not a new opener.
cat > "$WORK/emit-blocks.awk" <<'AWK'
/^[ \t]*```/ {
  if (inblk) {
    if ($0 ~ /^[ \t]*```[ \t]*$/) { if (isbash) close(out); inblk=0; isbash=0; next }
  } else {
    info=$0; sub(/^[ \t]*```/,"",info); sub(/[ \t]*$/,"",info)
    inblk=1
    if (info=="bash") {
      n++; isbash=1; out=OUT "/blk-" n ".sh"
      printf "" >> out                       # create even a zero-line block
      print n "\t" FILENAME "\t" FNR >> MAN   # FNR = the fence line
    }
    next
  }
}
{ if (inblk && isbash) print $0 >> out }
END { print n+0 >> CNT }
AWK

# Code contexts for check 2: every content line of any fenced block, plus each
# inline-code span on lines outside fences - emitted ONE SPAN PER RECORD. Two
# spans joined by a space on one output line manufacture verbs nobody wrote
# (`bin/oss` `lib/*.sh` -> "oss lib"); that was measured, not guessed.
cat > "$WORK/code-context.awk" <<'AWK'
/^[ \t]*```/ {
  if (inblk) { if ($0 ~ /^[ \t]*```[ \t]*$/) { inblk=0; next } }
  else { inblk=1; next }
}
{
  if (inblk) { print FILENAME ":" FNR ":" $0; next }
  s=$0
  while (match(s, /`[^`]*`/)) {
    print FILENAME ":" FNR ":" substr(s,RSTART+1,RLENGTH-2)
    s=substr(s,RSTART+RLENGTH)
  }
}
AWK

# Inline-code STRIPPER for check 4: every line, with backticked spans removed,
# but only outside fenced blocks - a fenced block is real code and a positional
# in one is a real finding.
cat > "$WORK/strip-inline.awk" <<'AWK'
/^[ \t]*```/ {
  if (inblk) { if ($0 ~ /^[ \t]*```[ \t]*$/) { inblk=0; print FNR ":"; next } }
  else { inblk=1; print FNR ":"; next }
}
{
  if (inblk) { print FNR ":" $0; next }
  s=$0; r=""
  while (match(s, /`[^`]*`/)) { r = r substr(s,1,RSTART-1); s=substr(s,RSTART+RLENGTH) }
  print FNR ":" r s
}
AWK

# ---------------------------------------------------------------------------
# Check 1 - every ```bash block parses under `bash -n`.
# Reports file:SOURCE-line (bash's in-block line number mapped back through the
# fence line) so the finding points at the offending line in the shipped doc.
# ---------------------------------------------------------------------------
check_1_parse() { # $1=ossify-root $2=workdir; writes $2/blocks/{manifest.tsv,count.txt}
  local r="$1" w="$2/blocks" n f fence err bline
  rm -rf "$w"; mkdir -p "$w"; : > "$w/manifest.tsv"; : > "$w/count.txt"
  awk -v OUT="$w" -v MAN="$w/manifest.tsv" -v CNT="$w/count.txt" \
      -f "$WORK/emit-blocks.awk" $(_md_files "$r")
  [ -s "$w/count.txt" ] || echo 0 > "$w/count.txt"
  while IFS=$'\t' read -r n f fence; do
    [ -n "$n" ] || continue
    if ! err="$(bash -n "$w/blk-$n.sh" 2>&1)"; then
      bline="$(printf '%s\n' "$err" | sed -n 's/.*: line \([0-9][0-9]*\): .*/\1/p' | head -1)"
      [ -n "$bline" ] || bline=1
      echo "$f:$((fence + bline)): $(printf '%s\n' "$err" | sed -n '1p' | sed 's#^.*: line [0-9]*: ##')"
    fi
  done < "$w/manifest.tsv"
}

# An independent second opinion on the block count. Deliberately NOT the state
# machine: a plain grep for the opener, written separately, so a break in the
# extractor's indentation tolerance surfaces as a disagreement instead of two
# wrong numbers that agree with each other.
grep_fence_count() { # $1=ossify-root
  _md_files "$1" | tr '\n' '\0' | xargs -0 cat \
    | { grep -cE '^[[:space:]]*```bash[[:space:]]*$' || true; } | tr -d ' '
}

# ---------------------------------------------------------------------------
# Check 2 - every `oss <subcommand>` token in a code context resolves to a real
# oss_cmd_* in the dispatcher.
#
# TWO EXTRACTION RULES, both by rule and neither by allowlist:
#  (a) WORD BOUNDARY. `oss` must start at a non-word byte. Without it the `oss`
#      inside "acr-oss" and "l-oss" yields `oss a`, `oss all`, `oss every`,
#      `oss the`, `oss three`, `oss footgun` - 6 of the 7 false positives the
#      naive extraction produces on the shipped tree.
#  (b) WILDCARD MENTIONS. A token containing `*` or ending in `_` is a
#      deliberate family reference (`oss ledger_add_*`), not a verb. That is
#      the 7th. Excluded tokens are printed so the exclusion set stays visible
#      instead of quietly absorbing a typo.
# ---------------------------------------------------------------------------
check_2_verbs() { # $1=ossify-root $2=workdir; writes $2/check2-{verbs,ctx,tokens,excluded}.txt
  local r="$1" w="$2" loc tok
  mkdir -p "$w"
  { grep -hoE '^oss_cmd_[A-Za-z0-9_]+\(\)' "$r/bin/oss" "$r"/lib/*.sh 2>/dev/null || true; } \
    | sed -E 's/^oss_cmd_//; s/\(\)$//' | sort -u > "$w/check2-verbs.txt"
  awk -f "$WORK/code-context.awk" $(_md_files "$r") > "$w/check2-ctx.txt"
  awk '{ s=$0
         split($0, _p, ":")
         while (match(s, /(^|[^A-Za-z0-9_])oss[ \t]+[A-Za-z_][A-Za-z0-9_*-]*/)) {
           tok=substr(s,RSTART,RLENGTH)
           sub(/^[^A-Za-z0-9_]?oss[ \t]+/,"",tok)
           print _p[1] ":" _p[2] "\t" tok
           s=substr(s,RSTART+RLENGTH) } }' "$w/check2-ctx.txt" | sort -u > "$w/check2-tokens.txt"
  : > "$w/check2-excluded.txt"
  while IFS=$'\t' read -r loc tok; do
    [ -n "$tok" ] || continue
    case "$tok" in
      *\**|*_) echo "$loc: oss $tok" >> "$w/check2-excluded.txt"; continue ;;
    esac
    grep -qxF "$tok" "$w/check2-verbs.txt" \
      || echo "$loc: 'oss $tok' resolves to no oss_cmd_$tok in the dispatcher"
  done < "$w/check2-tokens.txt"
}

# ---------------------------------------------------------------------------
# Check 3 - no Skill() invocation carries an argument. The runtime takes a bare
# skill name; a documented `Skill(x, target=y)` is a contract nothing honours,
# and this branch has shipped exactly that. Scoped to ossify: scaffold-onboard
# still ships the v0.1.x parameterized form and is not this harness's business.
# ---------------------------------------------------------------------------
check_3_skill_args() { # $1=ossify-root
  local f hit
  while IFS= read -r f; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      echo "$f:${hit%%:*}: Skill() invocation carries an argument: ${hit#*:}"
    done < <({ grep -nE 'Skill\([^)]*,' "$f" || true; })
  done < <(_md_files "$1")
}

# ---------------------------------------------------------------------------
# Check 4 - no positional $1/$2/$N in commands/*.md, matched only OUTSIDE
# inline-code spans.
#
# All five command files carry, at line 7, the bridge convention itself -
# "no positional `$1`/`$2`/`$N`" - with the positionals inside backticks. A
# check that flags prose telling you not to do the thing is broken, not the
# prose; there is not one real positional in commands/. Hence the stripper.
# THE ACCEPTED BLIND SPOT: a real positional written inside backticks as
# example code is invisible here. Accepted because the bridge line is a shipped
# convention in all five files and a backticked positional is not a form anyone
# writes by accident. Fenced blocks are NOT stripped - a positional in one is
# real code and is reported.
# ---------------------------------------------------------------------------
check_4_positionals() { # $1=ossify-root
  local f hit
  for f in "$1"/commands/*.md; do
    [ -e "$f" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      echo "$f:${hit%%:*}: positional argument outside inline code - a command body parses \$ARGUMENTS via the env-var bridge: ${hit#*:}"
    done < <(awk -f "$WORK/strip-inline.awk" "$f" | { grep -E '\$\{?([1-9][0-9]*|N)\}?' || true; })
  done
}

# ---------------------------------------------------------------------------
# Check 5 - reference reachability, two halves.
#
# ORPHANS: every references/*.md under a skill must be named by that skill's own
# SKILL.md. A pointer from a sibling reference does not make a file reachable -
# the agent reads SKILL.md, not the directory listing. This supersedes the
# per-skill loop that lived in test-close.sh, which enforced the same rule for
# one skill only.
#
# DANGLING: the resolution base, stated explicitly. A pointer written
# `references/foo.md` resolves against the SKILL DIRECTORY - not the repo root,
# and not the citing file's own directory (which for a reference file would
# give references/references/). Three pointer forms exist in the tree:
#   references/X.md                -> <skill-dir>/references/X.md
#   <skill>/references/X.md        -> <ossify-root>/skills/<skill>/references/X.md
#   skills/<skill>/references/X.md -> <ossify-root>/skills/...
# ${CLAUDE_PLUGIN_ROOT}-rooted pointers are runtime-expanded and are skipped by
# the extraction regex, which refuses a `}` or `/` immediately before the match.
#
# CROSS-SKILL, reported and not failed: some shipped pointers are written bare
# but name a sibling skill's file, with the owning skill supplied by the
# possessive prose immediately before it ("Same rules as `start`'s
# `references/bones-registry.md`"). Qualifying those would read "`start`'s
# `start/references/...`" - worse prose for no gain, since the file exists. They
# are reported as exclusions, on the same discipline as check 2, and only a
# pointer that resolves NOWHERE fails. THE ACCEPTED BLIND SPOT: an intra-skill
# typo that happens to collide with a sibling skill's filename lands in the
# reported set instead of failing.
# ---------------------------------------------------------------------------
check_5_refs() { # $1=ossify-root $2=workdir; writes $2/check5-{crossskill,pointers}.txt
  local r="$1" w="$2" sk skill ref base f p
  mkdir -p "$w"; : > "$w/check5-crossskill.txt"; : > "$w/check5-pointers.txt"
  # (a) orphans
  for sk in "$r"/skills/*/; do
    [ -d "$sk/references" ] || continue
    for ref in "$sk"references/*.md; do
      [ -e "$ref" ] || continue
      grep -Fq "references/$(basename "$ref")" "$sk/SKILL.md" 2>/dev/null \
        || echo "$ref: orphan - $(basename "${sk%/}")/SKILL.md never names references/$(basename "$ref")"
    done
  done
  # (b) dangling
  while IFS= read -r f; do
    skill=""
    case "$f" in "$r"/skills/*) skill="$r/skills/$(printf '%s' "${f#"$r"/skills/}" | cut -d/ -f1)" ;; esac
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      echo "$p" >> "$w/check5-pointers.txt"
      case "$f" in
        # A citing file under the plugin-root references/ tree resolves its
        # references/... pointers against the PLUGIN ROOT, not a skill dir
        # (Codex r1 on #284 - before this arm those files had base "" and
        # every valid root-relative pointer reported dangling).
        "$r"/references/*) case "$p" in
                              references/*) base="$r" ;;
                              *)            base="" ;;
                            esac ;;
        *) case "$p" in
             skills/*)       base="$r" ;;
             */references/*) base="$r/skills" ;;
             *)              base="$skill" ;;
           esac ;;
      esac
      if [ -n "$base" ] && [ -f "$base/$p" ]; then continue; fi
      # Bare form only: does the named file exist under some sibling skill?
      case "$p" in
        references/*)
          if ls "$r"/skills/*/"$p" >/dev/null 2>&1; then
            echo "$f: cross-skill pointer '$p' (resolves under a sibling skill; base named in prose)" >> "$w/check5-crossskill.txt"
            continue
          fi ;;
      esac
      echo "$f: dangling pointer '$p' resolves to no file (base ${base:-<no skill dir>})"
    done < <({ grep -ohE '(^|[^A-Za-z0-9_/${}-])(skills/)?([A-Za-z0-9_-]+/)?references/[A-Za-z0-9_.-]+\.md' "$f" || true; } \
               | sed -E 's#^[^A-Za-z0-9_]##' | sort -u)
  done < <(_md_files "$r")
}

# ---------------------------------------------------------------------------
# Check 6 - every SKILL.md is <= 500 lines, whole-file `wc -l`. Two shipped
# files sit at exactly 499, so this is a HARD fail with no rounding headroom;
# each file's current count is reported so the ceiling is visible before an edit
# reaches it.
# ---------------------------------------------------------------------------
check_6_budget() { # $1=ossify-root $2=workdir; writes $2/check6-report.txt
  local f n
  mkdir -p "$2"; : > "$2/check6-report.txt"
  for f in "$1"/skills/*/SKILL.md; do
    [ -e "$f" ] || continue
    n="$(wc -l < "$f" | tr -d ' ')"
    echo "     $n  $(basename "$(dirname "$f")")/SKILL.md  (headroom $((500 - n)))" >> "$2/check6-report.txt"
    [ "$n" -le 500 ] || echo "$f:$n: SKILL.md is $n lines, over the 500-line budget by $((n - 500))"
  done
}

# ---------------------------------------------------------------------------
# check 7 - the EVERY-CALL listing budget, over the strings that LOAD.
#
# check 6 guards the SKILL.md *body* (500 lines), which costs nothing until a
# skill is entered. This guards the listing that loads on every single call -
# and that listing carries the COMMAND descriptions, not the SKILL.md ones:
# measured 2026-08-22 from a live session's own recorded skill_listing
# attachment (issue #263), all ten commands/*.md descriptions load verbatim
# and none of the six skills/*/SKILL.md descriptions load at all -
# commands/<name>.md shadows skills/<name>/SKILL.md on the ossify:<name>
# token, and the #274 fix changed the loading ROUTE, not the listing SOURCE.
# Until this re-point the check summed strings that never load: a green gate
# certifying nothing, the same shadowing one level up.
#
# CEILING - derived from the spec band, never from history. §9.1
# (poc-first-lifecycle-design.md :115-119, :467) targets every-call listing
# cost at 0.3-0.4% of the window: 0.4% of 200k tokens = 800 tokens; at the
# 4.0 chars/token ratio the C1 numbers embed (3121 bytes = 0.39% = 780
# tokens - internally consistent), the band edge is 800 x 4.0 = 3200 bytes.
# The previous constant 3121 was the C1 trim's LANDING POINT (4180 -> 3121,
# 0.52% -> 0.39%), 79 bytes inside the edge: a historical accident, not the
# band. Nothing enforced any of it before C1, and the trim had drifted back
# to 3135 by v0.2 planning - a budget nobody measures is not a budget.
#
# MEASUREMENT is description-only, in bytes under the LC_ALL=C exported at
# the top of this file - the same method the ceiling is derived in. The
# listing's "- ossify:<name>: " prefixes add real cost (194 bytes at the
# ten-command set, name-length-dependent) but are harness rendering this
# test does not own; recorded here, not measured.
#
# HONESTY LINE: the ten-command surface measures 1467/3200 = 0.18% of the
# window - 2.2x headroom, and BELOW §9.1's 0.3-0.4% band, because three of
# the ten are standalone utilities §9.1 intended to surface name-only
# (issue #282 records that divergence and why trimming is the wrong fix:
# budget nobody is short of, traded against routing triggers). This check
# is a regression guard against growth, not a tight budget; it cannot fire
# until the surface more than doubles. Know that is what it is.
#
# DIVERGENCES recorded here, fixed elsewhere:
#   D-2: §9.1 says "<=6 fully-described entry skills" and lists six;
#        run-spine is a de-facto seventh full entry (lifecycle baton target),
#        and #267's adopt is an eighth unless §9.1 is amended deliberately -
#        the amendment is #267's to make. This check enforces bytes, not
#        count, on purpose.
#   D-3: §9.1's doctor row still allocates the phase-2 migration entry point
#        the adopt-forward spec rejected on doctor's report-only contract;
#        falls to the same §9.1 amendment.
#
# The floor assertion is not decoration: a glob that silently matches nothing
# sums to 0, which sails under any ceiling. That is the same vacuity mode
# check 5 guards against, and it is why this reports rather than just totals.
# The floor moved with the glob (skills -> commands) at this re-point.
# ---------------------------------------------------------------------------
check_7_descriptions() { # $1=ossify-root $2=workdir; writes $2/check7-report.txt
  local f d n total=0
  mkdir -p "$2"; : > "$2/check7-report.txt"
  for f in "$1"/commands/*.md; do
    [ -e "$f" ] || continue
    # Frontmatter-scoped on purpose: the listing loads the frontmatter value,
    # and a `description: ` line in the BODY is prose. The old whole-file sed
    # counted body lines (Codex r1 on #283) - a wrapper whose frontmatter
    # description was lost but whose body happened to carry such a line kept
    # a green budget and a silent no-description miss.
    d="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 && /^description: / {sub(/^description: /,""); print; exit}' "$f")"
    [ -n "$d" ] || { echo "$f: no frontmatter description"; continue; }
    echo "     ${#d}  commands/$(basename "$f")" >> "$2/check7-report.txt"
    total=$(( total + ${#d} ))
  done
  echo "     TOTAL $total  (budget 3200, headroom $((3200 - total)))" >> "$2/check7-report.txt"
  [ "$total" -le 3200 ] || echo "command descriptions total $total bytes, over the 3200 every-call budget by $(( total - 3200 ))"
  n="$(ls -1 "$1"/commands/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" -ge 10 ] || echo "check 7 saw only $n command files; the budget loop is not measuring the whole set"
}

# ---------------------------------------------------------------------------
# Check 8 - every command wrapper's entry route resolves.
#
# Post-#274 the sanctioned entry is path-routing: each wrapper carries a
# "Read ${CLAUDE_PLUGIN_ROOT}/<target> and follow it" line. Check 5's
# extractor deliberately skips PLUGIN_ROOT-rooted pointers (it resolves
# skill-relative references only), so nothing verifies the TARGET exists -
# a rename of skills/close/ or a typo while editing a wrapper passes every
# gate and every invocation of that command dies at runtime on a Read
# error. That reintroduces the #262/#267 "no entry point" symptom through a
# one-file edit no gate could see (#263's review, finding 1).
#
# ENTRY ROUTE vs SUBSIDIARY REFERENCE, disjoint by construction (Codex r1
# on #283): the entry route is the sanctioned INSTRUCTION - a line carrying
# Read AND a PLUGIN_ROOT target. A subsidiary pointer (handoff's
# sections.md) existence-checks but can never satisfy entry, so deleting
# the Read line goes red even when every subsidiary resolves. The two
# token sets are extracted from DISJOINT line sets - a Read-line token
# cannot also fire the reference arm, and vice versa. (The disjointness
# discipline itself came from this check's own plant refusing its first
# draft on #283, which double-reported a wrapper whose only route failed
# to resolve.)
#
# The per-file report is the vacuity floor - a broken extraction matches
# nothing, which would otherwise read as "all resolved".
# ---------------------------------------------------------------------------
# Route tokens come from BACKTICK SPANS, not from an unanchored character-class
# grep (Codex r1 on #284): a span carries the path as written, so a suffix like
# `SKILL.md#oops` reaches -f as the full string and fails, instead of being
# silently truncated to the existing .md prefix. The ENTRY arm requires the
# sanctioned instruction SHAPE - Read, optional space, optional backtick, then
# the PLUGIN_ROOT span - so a "Read-out" line cannot route a subsidiary
# pointer through the entry arm.
_c8_routes() { # $1=file $2=read|notread -> backtick-span route tokens, one per line
  awk -v mode="$2" '
    { keep = 0
      if (mode == "read") keep = ($0 ~ /Read[ \t]*`?\$\{CLAUDE_PLUGIN_ROOT\}/)
      else                keep = ($0 !~ /Read[ \t]*`?\$\{CLAUDE_PLUGIN_ROOT\}/)
      if (!keep) next
      s = $0
      while (match(s, /`[^`]*\$\{CLAUDE_PLUGIN_ROOT\}[^`]*`/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2)
        sub(/^\$\{CLAUDE_PLUGIN_ROOT\}/, "", t)
        print t
        s = substr(s, RSTART + RLENGTH) } }' "$1"
}

check_8_routes() { # $1=ossify-root $2=workdir; writes $2/check8-report.txt
  local f tok target nme nrs nsub entry ok
  mkdir -p "$2"; : > "$2/check8-report.txt"
  for f in "$1"/commands/*.md; do
    [ -e "$f" ] || continue
    nme=0; nrs=0; nsub=0; entry=""
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      nme=$((nme+1))
      target="$1$tok"
      if [ -f "$target" ]; then
        nrs=$((nrs+1)); [ -z "$entry" ] && entry="$tok"
      else
        echo "$(basename "$f"): Read-route resolves to nothing: $tok"
      fi
    done < <(_c8_routes "$f" read)
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      target="$1$tok"
      if [ ! -f "$target" ]; then
        nsub=1
        echo "$(basename "$f"): reference resolves to nothing: $tok"
      fi
    done < <(_c8_routes "$f" notread)
    # Cross-wire guard (Codex r1 on #284): existence-only checking passed a
    # wrapper repointed at ANOTHER skill's entry. When a same-named skill body
    # exists, the entry set must include it - /close must route to close's
    # SKILL.md, not doctor's. Utilities and run-spine (no same-named skill)
    # stay existence-checked.
    nme2="$(basename "$f" .md)"
    if [ "$nme" -gt 0 ] && [ -f "$1/skills/$nme2/SKILL.md" ] && [ "$entry" != "/skills/$nme2/SKILL.md" ]; then
      echo "$(basename "$f"): cross-wired entry $entry - skills/$nme2/SKILL.md exists and is this command's body"
    fi
    if [ "$nme" -eq 0 ]; then
      echo "$(basename "$f"): carries no Read \${CLAUDE_PLUGIN_ROOT} route - not path-routed, unreachable per #262"
    elif [ "$nme" -eq "$nrs" ] && [ "$nsub" -eq 0 ]; then
      echo "     ok  $(basename "$f")" >> "$2/check8-report.txt"
    fi
  done
}

# ---------------------------------------------------------------------------
# Check 9 - no shadowed Skill(ossify:<name>) tokens anywhere the harness owns.
#
# The bare form that CAUSED #262: Skill(ossify:close) is shadowed by
# commands/close.md, so the call loads the ~20-line wrapper, not the skill
# body, and dead-ends. Check 3 catches only comma-bearing invocations
# (Skill\(x, target=y\)); a prose edit restoring a bare token - from git
# history, a regenerated wrapper, a reference doc - passes every gate
# (#263's review, finding 2). The sanctioned route is the wrapper's Read
# line (check 8) or a cross-PLUGIN call like Skill(architect-critic:...) -
# only ossify's OWN token is shadowed. Baseline verified clean at plant
# time; any hit is a finding. The scan owns the plugin-root references/
# tree too, because three wrappers load it directly (Codex r1 on #283).
# ---------------------------------------------------------------------------
check_9_shadowed_tokens() { # $1=ossify-root
  local f hit
  while IFS= read -r f; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      echo "$f:${hit%%:*}: shadowed token ${hit#*:} - Skill(ossify:<name>) is dead-ended by the same-named command (#262); route by the wrapper's Read line instead"
    done < <({ grep -nE 'Skill\(ossify:' "$f" || true; })
  done < <(_md_files "$1")
}

# ===========================================================================
# PART 1 - the shipped tree. Expect zero findings from every check.
# ===========================================================================
echo "-- ossify tree: $OSSIFY"

# The two extractors hand their file list to awk as unquoted words, which a path
# containing whitespace would split. Assert it instead of extracting nonsense
# quietly - a silent split shows up as a *lower* block count, which is exactly
# the failure this file exists to make impossible.
t_assert_eq 0 "$(_md_files "$OSSIFY" | { grep -cE '[[:space:]]' || true; } | tr -d ' ')" \
  "no markdown path contains whitespace (the awk file-list contract)"

C1="$(check_1_parse "$OSSIFY" "$WORK/real")"
BLOCKS="$(cat "$WORK/real/blocks/count.txt")"
GREPN="$(grep_fence_count "$OSSIFY")"
echo "-- check 1: $BLOCKS bash blocks extracted (independent grep opener count: $GREPN)"
t_assert_eq 0 "$(_count "$C1")" "check 1: every shipped bash block parses under bash -n${C1:+ -- $C1}"
t_assert_eq "$GREPN" "$BLOCKS" "check 1: state-machine block count agrees with the independent grep opener count"
t_assert_ge 100 "$BLOCKS" "check 1: the block extractor is live (count has not collapsed)"

C2="$(check_2_verbs "$OSSIFY" "$WORK")"
echo "-- check 2: $(_lines "$WORK/check2-tokens.txt") oss-verb citations against $(_lines "$WORK/check2-verbs.txt") dispatcher verbs, $(_lines "$WORK/check2-excluded.txt") excluded as wildcard mentions"
[ -s "$WORK/check2-excluded.txt" ] && sed 's/^/     excluded: /' "$WORK/check2-excluded.txt"
t_assert_eq 0 "$(_count "$C2")" "check 2: every cited oss verb resolves to a dispatcher oss_cmd_*${C2:+ -- $C2}"
t_assert_ge 40 "$(_lines "$WORK/check2-tokens.txt")" "check 2: the code-context extractor is live (verb citations found)"
# The four verbs whose usage signatures this task re-quoted must STILL be visible
# to check 2. Quoting keeps those blocks inside check 1's coverage and keeps
# their verbs resolvable here; re-fencing them to ```text would have removed
# them from both, silently.
for v in ledger_supersede ledger_retire ledger_quarantine fake_status; do
  t_assert_grep "$WORK/check2-tokens.txt" "	$v\$" \
    "check 2 still resolves 'oss $v' (a re-fence or a broken extractor would hide it)"
done

C3="$(check_3_skill_args "$OSSIFY")"
t_assert_eq 0 "$(_count "$C3")" "check 3: no Skill() invocation carries an argument${C3:+ -- $C3}"

C4="$(check_4_positionals "$OSSIFY")"
t_assert_eq 0 "$(_count "$C4")" "check 4: no positional args in commands/*.md outside inline code${C4:+ -- $C4}"

C5="$(check_5_refs "$OSSIFY" "$WORK")"
echo "-- check 5: $(ls "$OSSIFY"/skills/*/references/*.md 2>/dev/null | wc -l | tr -d ' ') reference files, $(_lines "$WORK/check5-pointers.txt") pointers, $(_lines "$WORK/check5-crossskill.txt") cross-skill"
[ -s "$WORK/check5-crossskill.txt" ] && sed 's/^/     cross-skill: /' "$WORK/check5-crossskill.txt"
t_assert_eq 0 "$(_count "$C5")" "check 5: no orphaned reference and no dangling pointer${C5:+ -- $C5}"
t_assert_ge 40 "$(ls "$OSSIFY"/skills/*/references/*.md 2>/dev/null | wc -l | tr -d ' ')" "check 5: the orphan loop is not vacuous (reference files found)"
t_assert_ge 50 "$(_lines "$WORK/check5-pointers.txt")" "check 5: the dangling loop is not vacuous (pointers found)"

C6="$(check_6_budget "$OSSIFY" "$WORK")"
echo "-- check 6: SKILL.md line budgets"
cat "$WORK/check6-report.txt"
t_assert_eq 0 "$(_count "$C6")" "check 6: every SKILL.md is within the 500-line budget${C6:+ -- $C6}"
t_assert_ge 5 "$(_lines "$WORK/check6-report.txt")" "check 6: the budget loop saw every entry skill"

C7="$(check_7_descriptions "$OSSIFY" "$WORK")"
echo "-- check 7: command-description budget (the every-call listing cost)"
cat "$WORK/check7-report.txt"
t_assert_eq 0 "$(_count "$C7")" "check 7: command descriptions are within the 3200-byte every-call budget${C7:+ -- $C7}"
t_assert_ge 11 "$(_lines "$WORK/check7-report.txt")" "check 7: the description loop saw every command (10 rows + the total)"

C8="$(check_8_routes "$OSSIFY" "$WORK")"
echo "-- check 8: command route-pointer integrity"
cat "$WORK/check8-report.txt"
t_assert_eq 0 "$(_count "$C8")" "check 8: every command's Read-route resolves and every wrapper carries one${C8:+ -- $C8}"
t_assert_ge 10 "$(_lines "$WORK/check8-report.txt")" "check 8: the route loop saw every command wrapper (vacuity floor)"

C9="$(check_9_shadowed_tokens "$OSSIFY")"
echo "-- check 9: shadowed Skill(ossify:) tokens"
t_assert_eq 0 "$(_count "$C9")" "check 9: no shadowed Skill(ossify:) tokens anywhere the harness owns${C9:+ -- $C9}"

# ===========================================================================
# PART 2 - the permanent self-test.
#
# One planted defect per check, each in its OWN file so no single mutation can
# disarm a plant by way of another one's precondition. The check-1 plant is
# deliberately INDENTED: it is extracted only if both fence regexes tolerate
# leading whitespace, so losing that tolerance costs a named RED here as well
# as the count mismatch above.
# ===========================================================================
FIX="$WORK/fixture"
mkdir -p "$FIX/bin" "$FIX/lib" "$FIX/commands" "$FIX/agents" \
         "$FIX/skills"/{c1,c2,c3,c5o,c5d,c6}/references

cat > "$FIX/bin/oss" <<'EOF'
#!/usr/bin/env bash
oss_cmd_help() { :; }
EOF
cat > "$FIX/lib/commands.sh" <<'EOF'
oss_cmd_alpha() { :; }
oss_cmd_beta() { :; }
EOF

# --- check 1 plant: an INDENTED block with an unquoted <placeholder> ---------
cat > "$FIX/skills/c1/SKILL.md" <<'EOF'
# c1
Read `references/c1ref.md`.

1. Run it:

   ```bash
   oss alpha <line-id>
   ```
EOF
echo "# c1ref" > "$FIX/skills/c1/references/c1ref.md"

# --- check 2 plant: one unresolvable verb, plus a bait for each exclusion rule
cat > "$FIX/skills/c2/SKILL.md" <<'EOF'
# c2
Read `references/c2ref.md`.

```bash
# runs across all spines, across every release, across the lines
oss alpha
oss nosuchverb "<arg>"
oss ledger_add_*
oss ledger_add_
```
EOF
echo "# c2ref" > "$FIX/skills/c2/references/c2ref.md"

# --- check 3 plant: a parameterized Skill() ---------------------------------
cat > "$FIX/skills/c3/SKILL.md" <<'EOF'
# c3
Read `references/c3ref.md`.

Invoke Skill(ossify:c3, target=spine) and wait.
EOF
echo "# c3ref" > "$FIX/skills/c3/references/c3ref.md"

# --- check 4 plant: a real positional, alongside the backticked warning ------
cat > "$FIX/commands/c4.md" <<'EOF'
# c4
Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then hand off. This body reads $1 directly, which is the defect.
EOF

# --- check 5 plants: an orphan and a dangling pointer, in separate skills ----
cat > "$FIX/skills/c5o/SKILL.md" <<'EOF'
# c5o
Read `references/named.md`.
EOF
echo "# named" > "$FIX/skills/c5o/references/named.md"
echo "# orphan" > "$FIX/skills/c5o/references/orphan.md"

cat > "$FIX/skills/c5d/SKILL.md" <<'EOF'
# c5d
Read `references/c5dref.md`, then `references/nowhere.md`.
EOF
echo "# c5dref" > "$FIX/skills/c5d/references/c5dref.md"

# check 5 root-reference plants (Codex r1 on #284): one root-relative pointer
# that RESOLVES against the plugin root (must stay silent), one that dangles
# (must fire). Before the root-base arm, both reported dangling. Created HERE,
# before the F5 assertions run - plant order is execution order.
mkdir -p "$FIX/references"
echo "# root target" > "$FIX/references/rtarget.md"
printf -- '# rr\nSee `references/rtarget.md` for the template.\n' > "$FIX/references/rr.md"
printf -- '# rq\nSee `references/rnothing.md`.\n' > "$FIX/references/rq.md"

# --- check 6 plant: 501 lines -----------------------------------------------
{
  echo "# c6"
  echo "Read \`references/c6ref.md\`."
  i=3; while [ "$i" -le 501 ]; do echo "budget filler line $i"; i=$((i+1)); done
} > "$FIX/skills/c6/SKILL.md"
echo "# c6ref" > "$FIX/skills/c6/references/c6ref.md"

echo "# agent" > "$FIX/agents/a.md"

# --- check 7 plants: TWO DEDICATED ROOTS, deliberately not the shared $FIX ---
# The shared fixture's commands/c4.md carries no frontmatter description (it
# is check 4's plant), so running check 7 against $FIX would emit a
# no-description finding and couple this plant's count to check 4's fixture -
# the fixtures-coupled-through-shared-state vacuity mode. Separate roots keep
# the count exact and stable when a check 8 is added later.
FIX7="$WORK/fixture7"; FIX7B="$WORK/fixture7b"
_c7_command() { # $1=root $2=name $3=description-length
  mkdir -p "$1/commands"
  { echo "---"; echo "name: $2"
    printf 'description: '; printf 'd%.0s' $(seq 1 "$3"); echo
    echo "---"; echo "# $2"; } > "$1/commands/$2.md"
}
# Plant A: 10 commands x 350 bytes = 3500, over the 3200 budget by 300 - and
# at the full ten-file count, so ONLY the ceiling arm fires.
for s in c7a c7b c7c c7d c7e c7h c7i c7j c7k c7l; do _c7_command "$FIX7" "$s" 350; done
# Plant B: only 2 commands, each comfortably under budget - the TOTAL passes,
# so the only thing that can fire is the floor guard. That is the assertion
# that makes check 7 unable to pass by measuring nothing.
for s in c7f c7g; do _c7_command "$FIX7B" "$s" 100; done
# Plant C: description only in the BODY, frontmatter empty of one - the whole
# file sed counted it and stayed green; the frontmatter-scoped extractor must
# call it what it is (no description, not counted).
FIX7C="$WORK/fixture7c"
mkdir -p "$FIX7C/commands"
printf -- '---\nname: c7m\n---\ndescription: %s\n# c7m\n' "$(printf 'd%.0s' $(seq 1 60))" > "$FIX7C/commands/c7m.md"

echo "-- self-test fixture: $FIX"

F1="$(check_1_parse "$FIX" "$WORK/fix1")"
FB="$(cat "$WORK/fix1/blocks/count.txt")"
# EXACT count, not a floor: an extractor returning zero blocks passes every
# parse check, and only an exact count on a controlled corpus can say otherwise.
t_assert_eq 2 "$FB" "self-test: exactly 2 bash blocks extracted from the fixture (one of them indented)"
t_assert_eq 1 "$(_count "$F1")" "self-test: check 1 finds exactly its 1 planted parse failure${F1:+ -- $F1}"
t_assert_contains "$F1" "c1/SKILL.md:7" "self-test: check 1 names the planted file and the mapped source line"

F2="$(check_2_verbs "$FIX" "$WORK/fix2")"
t_assert_eq 1 "$(_count "$F2")" "self-test: check 2 finds exactly its 1 planted unresolvable verb${F2:+ -- $F2}"
t_assert_contains "$F2" "'oss nosuchverb'" "self-test: check 2 names the planted verb"
t_assert_grep "$WORK/fix2/check2-excluded.txt" 'oss ledger_add_\*$' "self-test: check 2 excludes the * wildcard mention by rule"
t_assert_grep "$WORK/fix2/check2-excluded.txt" 'oss ledger_add_$' "self-test: check 2 excludes the trailing-underscore mention by rule"

F3="$(check_3_skill_args "$FIX")"
t_assert_eq 1 "$(_count "$F3")" "self-test: check 3 finds exactly its 1 planted parameterized Skill()${F3:+ -- $F3}"
t_assert_contains "$F3" "c3/SKILL.md:4" "self-test: check 3 names the planted file and line"

F4="$(check_4_positionals "$FIX")"
t_assert_eq 1 "$(_count "$F4")" "self-test: check 4 finds exactly its 1 planted positional, not the backticked warning${F4:+ -- $F4}"
t_assert_contains "$F4" "c4.md:3" "self-test: check 4 names the planted line, not line 2's backticked warning"

F5="$(check_5_refs "$FIX" "$WORK/fix5")"
t_assert_eq 3 "$(_count "$F5")" "self-test: check 5 finds exactly its 3 planted defects (1 orphan, 1 skill dangling, 1 root-reference dangling)${F5:+ -- $F5}"
t_assert_contains "$F5" "orphan.md: orphan" "self-test: check 5 names the planted orphan"
t_assert_contains "$F5" "dangling pointer 'references/nowhere.md'" "self-test: check 5 names the planted dangling pointer"
t_assert_contains "$F5" "dangling pointer 'references/rnothing.md'" "self-test: check 5 names the root-reference dangling pointer"

F6="$(check_6_budget "$FIX" "$WORK/fix6")"
t_assert_eq 1 "$(_count "$F6")" "self-test: check 6 finds exactly its 1 planted over-budget SKILL.md${F6:+ -- $F6}"
t_assert_contains "$F6" "c6/SKILL.md:501" "self-test: check 6 names the planted file and its line count"

F7="$(check_7_descriptions "$FIX7" "$WORK/fix7")"
t_assert_eq 1 "$(_count "$F7")" "self-test: check 7 finds exactly its 1 planted over-budget command set${F7:+ -- $F7}"
t_assert_contains "$F7" "total 3500 bytes" "self-test: check 7 names the measured total, not just that it is over"
t_assert_contains "$F7" "over the 3200 every-call budget by 300" "self-test: check 7 names the exact overage"
# The floor guard: a root the loop under-measures must RED even though its
# total is far under budget. Without this, a glob that matched nothing would
# sum to 0 and sail through - the way a budget check ends up unable to fail.
F7B="$(check_7_descriptions "$FIX7B" "$WORK/fix7b")"
t_assert_eq 1 "$(_count "$F7B")" "self-test: check 7 fires on an under-measured set even though its total passes${F7B:+ -- $F7B}"
t_assert_contains "$F7B" "saw only 2 command files" "self-test: check 7's floor guard names how many it actually saw"
F7C="$(check_7_descriptions "$FIX7C" "$WORK/fix7c")"
t_assert_eq 2 "$(_count "$F7C")" "self-test: check 7 flags a body-only description AND its floor (2 findings, not a green budget)${F7C:+ -- $F7C}"
t_assert_contains "$F7C" "c7m.md: no frontmatter description" "self-test: check 7 names the body-only-description wrapper"
t_assert_grep "$WORK/fix7c/check7-report.txt" 'TOTAL 0 ' "self-test: the 60-byte body line is NOT counted toward the budget"

# --- check 8 and 9 plants: DEDICATED ROOTS, for the same coupling reason as
# check 7's - the shared fixture cannot host them: commands/c4.md (check 4's
# plant) carries no CLAUDE_PLUGIN_ROOT route, and skills/c3's body (check 3's
# plant) literally contains Skill(ossify:c3, ...) - each would cross-fire the
# other check and couple plant counts across fixtures.
FIX8="$WORK/fixture8"; FIX9="$WORK/fixture9"
mkdir -p "$FIX8/commands" "$FIX8/skills/real" "$FIX9/skills/c9"
echo "# real target" > "$FIX8/skills/real/SKILL.md"
printf -- '---\ndescription: good wrapper\n---\nRead `${CLAUDE_PLUGIN_ROOT}/skills/real/SKILL.md` and follow it.\n' > "$FIX8/commands/r8good.md"
printf -- '---\ndescription: broken route\n---\nRead `${CLAUDE_PLUGIN_ROOT}/skills/missing/SKILL.md` and follow it.\n' > "$FIX8/commands/r8bad.md"
printf -- '---\ndescription: no route at all\n---\nJust prose. Nothing to read.\n' > "$FIX8/commands/r8none.md"
# r8sub is the T2 shape exactly: a RESOLVING subsidiary reference on a non-Read
# line, no Read-route. Counting any reference as entry kept this green; the
# Read-route requirement must name it.
printf -- '---\ndescription: subsidiary only\n---\nGuidance lives in `${CLAUDE_PLUGIN_ROOT}/skills/real/SKILL.md`.\n' > "$FIX8/commands/r8sub.md"
# r8subword (Codex r1 on #284): a RESOLVING span on a "Read-out" line - the
# substring match routed it through the entry arm; the instruction-shape regex
# must not.
printf -- '---\ndescription: readout bait\n---\nRead-out summary `${CLAUDE_PLUGIN_ROOT}/skills/real/SKILL.md` for the record.\n' > "$FIX8/commands/r8subword.md"
# r8suf (Codex r1 on #284): a suffix on the path. The class-based extractor
# truncated at .md and -f passed; the span carries the full string and fails.
printf -- '---\ndescription: suffix junk\n---\nRead `${CLAUDE_PLUGIN_ROOT}/skills/real/SKILL.md#oops` and follow it.\n' > "$FIX8/commands/r8suf.md"
# r8wire (Codex r1 on #284): every route resolves, but a same-named skill body
# exists and the entry points elsewhere - the cross-wire guard must fire.
mkdir -p "$FIX8/skills/r8wire"
echo "# r8wire body" > "$FIX8/skills/r8wire/SKILL.md"
printf -- '---\ndescription: cross-wired\n---\nRead `${CLAUDE_PLUGIN_ROOT}/skills/real/SKILL.md` and follow it.\n' > "$FIX8/commands/r8wire.md"
printf -- '# c9\nInvoke Skill(ossify:c9) and wait.\n' > "$FIX9/skills/c9/SKILL.md"
# r9 is the T1 shape: a shadowed token in the plugin-root references tree that
# _md_files did not own before the widening.
mkdir -p "$FIX9/references"
printf -- '# r9\nAlso invoke Skill(ossify:r9) here.\n' > "$FIX9/references/r9.md"

F8="$(check_8_routes "$FIX8" "$WORK/fix8")"
t_assert_eq 6 "$(_count "$F8")" "self-test: check 8 finds exactly its 6 planted route defects (unresolvable, absent, subsidiary, substring-bait, suffix, cross-wire)${F8:+ -- $F8}"
t_assert_contains "$F8" "r8bad.md: Read-route resolves to nothing" "self-test: check 8 names the unresolvable Read-route"
t_assert_contains "$F8" "r8none.md: carries no Read" "self-test: check 8 names the routeless wrapper"
t_assert_contains "$F8" "r8sub.md: carries no Read" "self-test: check 8 refuses a resolving subsidiary as an entry route"
t_assert_contains "$F8" "r8subword.md: carries no Read" "self-test: a Read-out line cannot satisfy the entry arm"
t_assert_contains "$F8" "r8suf.md: Read-route resolves to nothing: /skills/real/SKILL.md#oops" "self-test: a suffixed path is not truncated to its .md prefix"
t_assert_contains "$F8" "r8wire.md: cross-wired entry" "self-test: a same-named skill body pins the entry"
t_assert_ge 1 "$(_lines "$WORK/fix8/check8-report.txt")" "self-test: check 8's ok-report still saw the good wrapper (extraction alive)"

F9="$(check_9_shadowed_tokens "$FIX9")"
t_assert_eq 2 "$(_count "$F9")" "self-test: check 9 finds both planted shadowed tokens, in skills AND in the references tree${F9:+ -- $F9}"
t_assert_contains "$F9" "c9/SKILL.md:2" "self-test: check 9 names the skills-tree plant"
t_assert_contains "$F9" "references/r9.md:2" "self-test: check 9 names the references-tree plant"

t_summary
