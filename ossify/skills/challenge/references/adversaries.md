# The adversary ladder

Depth for `challenge/SKILL.md`, loaded by audit mode at close depth. A
close-depth audit recruits one external fresh-frame adversary. **Which one is
configuration, not code** — and unconfigured means host-only, by declaration,
not by accident.

---

## 1. Resolution — first hit wins

1. **Per-invocation override.** The calling prose or the user names an
   adversary for this run.
2. **`OSSIFY_ADVERSARY`** — a recipe name from §2, or the literal `none`
   (force host-only even where a recipe would resolve).
3. **Host-only.** The declared default. No implicit adversary is ever assumed
   from the host agent.

Audit mode announces the resolution before running (audit.md §3), and the
summary's `Adversaries used` line always names what actually ran — `host only`
is a value, not an omission.

---

## 2. Recipes

Each recipe: a probe, an invocation, the output contract (§3), a timeout, and
the failure path (§4). `codex` and `claude` are ported verbatim from
architect-critic 0.6.0's proven invocations. The others are templates: marked
unproven until validated on a real run, and the contract in §3 is what a
validated run must satisfy.

### codex — ported, proven

**Probe:** `command -v codex`.

**Invocation** (the schema file ships at
`${CLAUDE_PLUGIN_ROOT}/skills/challenge/templates/output-schema.json`):

```bash
codex exec --json \
  --output-schema "${CLAUDE_PLUGIN_ROOT}/skills/challenge/templates/output-schema.json" \
  --output-last-message "<tmpdir>/codex-audit-<id>.json" \
  --ignore-user-config --ignore-rules --skip-git-repo-check \
  "<prompt>"
```

Read the `--output-last-message` file, not stdout. Validate it against §3.

**Timeout:** 300s default; `OSSIFY_ADVERSARY_TIMEOUT_S` overrides (integer
seconds).

### claude — ported, proven

**Probe:** `command -v claude`.

**Invocation:**

```bash
claude --print \
  --output-format json \
  --json-schema "$(cat "${CLAUDE_PLUGIN_ROOT}/skills/challenge/templates/output-schema.json")" \
  --permission-mode dontAsk \
  --no-session-persistence \
  "<prompt>"
```

Validate the response against §3.

**Timeout:** 300s default; `OSSIFY_ADVERSARY_TIMEOUT_S` overrides.

### droid — template, unproven

**Probe:** `command -v droid`.

**Invocation:** use the CLI's non-interactive single-shot mode with the prompt
as input; capture its final message. Exact flags are unvalidated — on first
real use, confirm the flags against the installed version's `--help`, run one
audit, and correct this recipe in the same change.

**Contract:** whatever the flags, the final message must end with the §3 fenced
block.

### generic CLI — template

Any CLI qualifies if it: takes a prompt non-interactively, returns text on
stdout or in a file, and can be instructed to end with the §3 fenced block.
Add it as a named recipe here once validated.

---

## 3. The return contract — travels in the prompt

The adversary never sees this skill, so the contract is embedded in the prompt
verbatim, as an ordinary fenced block:

    ## Return contract
    End your final message with a fenced JSON block of this exact shape:
    ```json
    {"challenges":[{"text":"<one paragraph>","severity":"premise|gap|alternative","rationale":"<why>"}]}
    ```

Validation: a JSON object with a `challenges` array whose items each carry
string `text`, `severity` in `premise|gap|alternative`, and string `rationale`.
Anything else is invalid output and takes the §4 path.

---

## 4. Failure is host-only, loudly

Timeout, non-zero exit, missing file, invalid JSON — all four land in the same
place: **one warning naming the cause, the audit continues host-only, and the
summary records what actually ran.** Never retry mid-ceremony; never treat a
failed adversary as a passing one. The user re-runs the audit after fixing the
cause if the fresh frame matters for this artifact.
