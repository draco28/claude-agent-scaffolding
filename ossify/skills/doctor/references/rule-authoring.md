# Machine-checkable rule authoring

The depth behind `doctor/SKILL.md` §6. The one surface in this skill that
writes, and it writes to exactly one file.

**Two modes, and the sweep only ever gets the first.**

| Mode | When | Writes? |
|---|---|---|
| **Inspect** | a full sweep (`SKILL.md` §3), or any request that names no rule | never |
| **Author** | an explicit ask for a rule — "add a project rule", "forbid X" | appends one block, after confirmation |

**Inspect** is the sweep's verdict: read `03-code-patterns.md`, count the
`mcrule` blocks, validate each one's shape (§5), and note any carrying a type
this build does not recognise (§8). Report the count and any malformed block.
Do **not** prompt for a rule — a health check that stops to solicit an unrelated
write has stopped being a health check.

---

## 1. The file, and how to find it

```bash
bank="$(oss harvest_dir)"        # the memory-bank directory, manifest-routed
patterns="$bank/03-code-patterns.md"
```

**Never hardcode `.claude/memory-bank/03-code-patterns.md` against `$PWD`.**
The bank lives in the **AI workspace**, not beside the code, and `oss
harvest_dir` is the resolver. A cwd-rooted path writes rules into whichever repo
the session happened to start in.

`03-code-patterns.md` ships from `/start` with the
`## Machine-checkable rules` heading present and **no rules under it**
(`start/references/memory-bank-brief.md` §1). An empty section is not an absent
one, and neither is a defect.

**Lane discipline: this surface writes to `03-code-patterns.md` and nothing
else.** Never `00-project-brief.md` through `08-governance.md`, never
`CLAUDE.md`, never `MASTER-SPEC.md`.

---

## 2. Who reads an authored rule — state this accurately

Two different things, and conflating them oversells what authoring buys:

- **Today: `close`'s work-item gate, Layer 3, reads this file and judges.** An
  authored rule *is* consulted on every work-item close — as a documented
  pattern an agent reads and applies, quoting it back verbatim in any finding
  (`close/references/impl-check.md` §4).
- **Not yet: mechanical evaluation.** Nothing parses the `mcrule` blocks and
  runs them against a codebase. The evaluator is a separate v0.3 item.

So the honest line to the user is: *"this rule is now documented, validated, and
read at every work-item gate; it is not yet mechanically evaluated."* Do not
shorten that to "enforced" and do not shorten it to "not enforced" — the first
oversells, the second would tell someone to skip authoring rules that Layer 3
will genuinely apply.

---

## 3. The four types

```bash
oss rules_types
```

Field sets are **per type**, not shared. `coverage_floor` is the one type with
no optional fields at all, which is the most common authoring mistake:

| Type | Required | Optional |
|---|---|---|
| `banned_imports` | `forbid` | `in`, `where` |
| `coverage_floor` | `paths`, `threshold` | *(none)* |
| `style_invariants` | `forbid_pattern` | `in`, `exclude`, `where` |
| `required_pattern` | `require_pattern` | `in`, `exclude`, `where` |

---

## 4. Grammar

**HTML-sentinel comments, never fenced code blocks.** Each rule sits between
`<!-- mcrule:start type=<T> -->` and `<!-- mcrule:end -->`. The body is
`key: value`, one pair per line. Prose may surround blocks and is what makes the
file readable by a human.

The fenced-block alternative was drafted and **explicitly rejected**: fence
boundaries are invisible in rendered markdown, which breaks the human/machine
dual-readability the file exists for. Never emit a fenced rule block, not even
as an example inside a message.

Worked examples, one per type:

    We forbid synchronous HTTP libraries in async paths — they block the loop.

    <!-- mcrule:start type=banned_imports -->
    in: src/**/*.py
    where: any_function_marked_async
    forbid: [requests, urllib3, httpx.Client]
    <!-- mcrule:end -->

    The API layer holds an 80% coverage floor.

    <!-- mcrule:start type=coverage_floor -->
    paths: [src/api/]
    threshold: 80
    <!-- mcrule:end -->

    Never `print()` outside tests.

    <!-- mcrule:start type=style_invariants -->
    in: src/**/*.py
    exclude: tests/**/*.py
    forbid_pattern: '\bprint\('
    <!-- mcrule:end -->

    Every API handler documents Args and Returns.

    <!-- mcrule:start type=required_pattern -->
    in: src/api/handlers/*.py
    require_pattern: 'Args:\s+.*\s+Returns:'
    where: function_def
    <!-- mcrule:end -->

**Quote regex values in single quotes.** It protects `\b`, `\s`, `(` and friends
from being eaten by an intermediate parser. The validator treats values as
opaque — only the *key* is charset-checked — so a quoted regex passes through
whole.

---

## 5. Validation, before every write

**Pass the body through a QUOTED heredoc. Never interpolate it into the command
line.**

```bash
body="$(cat <<'MCRULE'
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '\bprint\('
MCRULE
)"
oss rules_validate style_invariants "$body"
```

This is a security boundary, not a style preference. Rule values are regexes and
path globs, they routinely contain `$`, backticks and parentheses, and they
arrive from a user's prompt or from a pattern already sitting in the repo.
Written the obvious way — `oss rules_validate <type> "<block body>"` with the
body pasted in — a value containing `$(…)` or a backtick is **executed by the
shell before `rules_validate` ever sees it**, during what the user was told is a
shape-only check. The single quotes §4 recommends around regexes do not save
you: they are inside the outer double-quoted argument, so the shell has already
finished expanding by the time they are just characters.

The quoted delimiter (`<<'MCRULE'`, not `<<MCRULE`) is what disarms it — a
quoted heredoc performs no expansion at all — and `"$body"` then passes the text
as one argument that is not re-scanned.

| rc | Meaning | Do |
|---|---|---|
| 0 | well-formed | write it |
| 1 | not well-formed | surface stderr **verbatim**, then re-prompt |
| 2 | usage | your call was wrong, not the user's rule |

It checks four things: every line is `key: value`, the key charset, the type is
known, every required field is present, and no field is unknown for that type.
**Shape only** — it does not compile regexes and does not evaluate anything.

The unknown-field check is the one that earns its keep. A typo'd
`forbid_patern` would otherwise author a block whose required field is absent —
green at authoring time, and skipped by every future parser for the rest of the
project's life.

A typo in a *required* field reports as `requires field '<correct name>'`
rather than `unknown field '<what you typed>'`. That ordering is deliberate: it
hands the author the correct spelling instead of confirming their typo.

---

## 6. The authoring conversation

One rule per invocation:

1. **Restate the intent and name the type.** *"You want `requests` and
   `urllib3` forbidden inside async functions under `src/` — that's a
   `banned_imports` rule with a `where:` predicate. Right?"* If two types could
   fit, name both and ask which direction: forbid-a-pattern or require-one.
2. **Prompt only for missing required fields.** Do not walk the whole field list
   when the ask already answered half of it.
3. **Propose optional fields with defaults** drawn from the project's tech
   context (`04-tech-context.md` if it exists — do not block on it). Skip the
   ones the user does not care about; optional means optional.
4. **Preview the composed block** in your message and wait for confirmation.
   The user should see the exact bytes before they land.
5. **Validate** (§5).
6. **Append** (§7).
7. **Confirm** with the absolute path written and one line on what the rule now
   does — using §2's accurate phrasing.

**On a failing validation, loop once.** Surface the validator's stderr verbatim
plus a concrete suggestion, then re-prompt. If a second pass still fails, offer
the choice — hand-author the block per §4's grammar, or drop it for now — and
never silently abort.

---

## 7. Append semantics

Append; never rewrite.

1. **Locate `^## Machine-checkable rules`.** If the heading is absent, append it
   at EOF and treat the new block as the first under it.
2. **Insert after the last `<!-- mcrule:end -->`** within the section, preceded
   by a blank line. The section's lower boundary is the next `##` heading, or
   EOF. With no blocks yet, insert directly under the heading.
3. **Idempotent on an identical block.** Scan the section first; if a block with
   a byte-identical body (after whitespace normalisation) exists, skip the write
   and say so. Do not duplicate.
4. **Never overwrite an existing rule**, and **never touch prose between
   blocks** — the human context is half the file's value.

---

## 8. Unknown types are preserved, never deleted

A block carrying a type this build does not know (`type=dependency_age`, say,
authored against a later version) must **survive** an authoring run untouched.

- The section scan must not crash on one. Treat it as an opaque block and skip
  over it.
- Say so in one line: *"preserved a `type=dependency_age` block this build does
  not recognise."*
- **Skip means skip during processing, not delete from disk.**

If the *user* asks for an unsupported type, do not silently re-classify their
ask into one of the four. Name the four, say the block can be hand-authored
ahead of parser support per §4's grammar, and note it will not be recognised
until parsers catch up.
