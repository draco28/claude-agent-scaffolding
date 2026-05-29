---
name: authoring-runbook
description: Author a new SRE-style operational runbook under `<canonical>/docs/runbooks/<topic-kebab>.md` (six sections: Overview, Symptoms, Immediate response, Diagnosis, Mitigation, Postmortem link); extracts topic inline or prompts; collision-aware (2-option menu on duplicate). Use this when the user says `author runbook for X`, `write a runbook`, `create operational runbook`, `write runbook`, or invokes `/runbook [topic]`. Does NOT execute runbooks (operator behavior).
---

# authoring-runbook

You are scaffold-dev v0.1's runbook author. One topic in (explicit or prompted), one SRE-style markdown file out under `<canonical>/docs/runbooks/`. Six sections, each populated by the user; collision-aware so a prior runbook on the same topic is never silently overwritten.

This skill is the runbook composer. It does NOT execute runbooks during incidents (operator behavior, not skill behavior), does NOT auto-extract symptoms/diagnosis content from prior postmortems (deferred to v0.2), does NOT cross-link runbooks to one another (deferred to v0.2), and does NOT archive or retire runbooks (out of scope for v0.1). On collision, you bail to a 2-option menu and let the user decide — never auto-overwrite, never silently rename.

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/authoring-runbook.md` — the three scenarios there (S1 happy path with explicit topic, S2 topic prompt-and-wait, S3 collision menu) are the binding spec.

---

## 1. Overview

When invoked, you:

1. **Discover the workspace-init pairing manifest** via `lib/manifest.sh` walk-up helpers. Refuse fail-fast if absent (mirrors `planning-vertical-slice` §3.1).
2. **Resolve `routing.runbooks`** to `<canonical>/docs/runbooks/`.
3. **Extract or prompt for the topic.** If the trigger phrase contains an explicit `for <topic>` clause (or equivalent), extract the kebab topic. If absent, prompt the user; wait for response.
4. **Check filename collision.** If `<runbooks-dir>/<topic-kebab>.md` already exists, bail to the §7 menu and wait.
5. **Collect section content** for the six SRE sections (§5 below). The user may supply all content in one paste OR section-by-section; either is acceptable.
6. **Render `templates/runbook.md.tmpl`** with the six populated sections.
7. **Write the file** at `<canonical>/docs/runbooks/<topic-kebab>.md`.
8. **Emit the final assistant message** naming the absolute path of the written file.

---

## 2. When to use

**Trigger phrases (description-match):**

- `author runbook for <topic>` (topic inline; S1)
- `write a runbook` (no topic; prompts per §4; S2)
- `create operational runbook` (S3 — topic via follow-up)
- `write runbook` / `write runbook for <topic>`
- `/runbook [topic]` (future slash command — `$ARGUMENTS` env-var bridge)

The first three phrase forms are load-bearing across S1 / S2 / S3. Do not paraphrase these in your acknowledgement.

**Do NOT auto-invoke when:**

- The user wants to *follow* a runbook (operator behavior; not this skill's lane).
- The user wants to *update* an existing runbook with a new incident dated-section — that's the S3 menu's option 1 branch; route there via collision detection, do not enter that branch from the trigger directly.
- No workspace-init pairing manifest exists. Refuse with the same verbatim string `planning-vertical-slice` uses (§3.1).

If the user types something ambiguous like "I need a doc for the redis incident", clarify: *"Author a runbook (SRE-style operational doc with Overview / Symptoms / Immediate response / Diagnosis / Mitigation / Postmortem link sections) for the redis incident?"*.

---

## 3. Pre-flight + manifest discovery

### 3.1 Manifest discovery (refuses fail-fast)

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS):

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw `jq`. All reads route through `sd_manifest_get` / `sd_manifest_resolve`. Eval S1 + S2 + S3 all check for at least one `lib/manifest.sh` helper invocation.

### 3.2 Resolve the runbooks dir

```bash
runbooks_dir="$(sd manifest_resolve "$(sd manifest_get '.routing.runbooks')")"
canonical="$(sd manifest_get '.canonical.root')"
```

The dir MUST resolve under `${canonical}` (runbooks are canonical-only per §7.1). If the dir does not exist, surface a one-line hint: *"Runbooks directory `<resolved-path>` not found; create it (`mkdir -p`) or seed it via scaffold-onboard."*. v0.1's runbooks dir creation is informally owned (no explicit `/scaffold-docs` seed in v0.1.0); the skill may proceed with a `mkdir -p` if the parent is canonical and the user confirms — but the default is bail-and-warn.

(For the evals, the fixture pre-creates the dir; this guard fires only in real-world misconfigurations.)

---

## 4. Topic extraction OR disambiguation prompt

### 4.1 Inline-topic extraction (S1)

If the trigger phrase matches the pattern `author runbook for <topic>` or `write runbook for <topic>` or `/runbook <topic>`, extract the `<topic>` token after the literal `for ` / arg position. Sanitize to kebab-case:

```bash
topic_kebab="$(printf '%s' "$user_topic" \
  | tr '[:upper:]' '[:lower:]' \
  | tr ' _' '--' \
  | sed -E 's/[^a-z0-9-]//g; s/-+/-/g; s/^-+|-+$//g')"
```

If the trigger phrase already supplied a kebab-case token (S1: `redis-cache-stale-after-failover`), the sanitize is a no-op. Proceed to §5 (collision check).

### 4.2 Topic disambiguation prompt (S2)

If the trigger phrase has no explicit topic (S2: bare `write a runbook`), surface this prompt as the FIRST user-facing question:

> What's the topic for this runbook? Use a short kebab-case identifier describing the incident scenario — e.g., `redis-cache-stale-after-failover`, `database-failover`, `auth-token-rotation-stall`. The filename will be `<topic>.md` under `docs/runbooks/`.

Wait for the user's response. Eval S2 explicitly checks:

- The topic-disambiguation prompt appears BEFORE any section-content prompts AND BEFORE any Write tool call.
- The skill does NOT silently pick a topic, does NOT fall back to a generic name like `runbook.md` / `untitled.md`.
- No file is written under any name other than the user-supplied topic.

After capturing the response, sanitize per §4.1.

---

## 5. Collision check (S3 menu)

```bash
target_path="${runbooks_dir%/}/${topic_kebab}.md"
if [[ -f "$target_path" ]]; then
  # surface §6 menu, wait — do NOT proceed to content collection
fi
```

The check MUST appear in the tool-call log BEFORE any content prompt OR Write attempt. Eval S3 looks for a `test -f`, Read attempt, `ls`, or equivalent against the resolved path.

---

## 6. Collision menu (S3 contract)

When the target file already exists, surface this menu and wait — do NOT auto-pick:

> A runbook at `<target_path>` already exists. Pick one:
>
> 1. **Append section** — add a new dated section (e.g., `## Incident YYYY-MM-DD`) to the existing runbook, preserving its content. Use this when this incident is a recurrence and the existing runbook's diagnosis/mitigation still applies.
> 2. **New filename** — author under a different kebab topic (you'll be prompted for a new topic). Use this when the new incident is distinct and warrants its own runbook.

Eval S3 explicitly checks for at least 2 distinct numbered options with text identifying "append" / "append section" / "add to existing" (option 1) AND "new filename" / "different name" / "rename" (option 2). Paraphrase is acceptable; collapsing to a single auto-overwrite choice is a FAIL.

**Binding constraints (eval S3 assertions):**

- No `Write` or `Edit` of the existing file appears in the tool-call log on this turn — the skill bails to the menu BEFORE any mutation attempt.
- No `Write` of a new-filename file appears either — the alternative filename is composed only AFTER the user picks option 2 and supplies the new topic.
- The existing runbook's content is byte-identical before and after the menu turn (judge diffs the file pre/post).
- The final assistant message names the existing-runbook path explicitly so the user can identify what would have been overwritten.

The downstream branches (option 1 append-dated-section flow; option 2 re-prompt for new kebab) are implementation downstream — S3 verifies only that the menu is surfaced.

---

## 7. Section content collection (the 6 SRE sections)

Once the topic is locked and no collision blocks the path, collect content for the six required sections. The user may paste all sections at once OR walk through them section-by-section; both are acceptable.

The six sections (6-section invariant per eval cross-scenario):

1. **Overview** — what is this incident scenario, in 1-3 paragraphs. Names the system / component / symptom in plain terms.
2. **Symptoms** — bulleted list of observable signals (alerts, error messages, user reports, dashboard metrics). At least 1 bullet.
3. **Immediate response** — ordered list of actions to take in the first minutes (silence noisy alerts, page on-call, snapshot state for forensics, etc.). At least 1 step.
4. **Diagnosis** — ordered list of investigation steps (commands to run, dashboards to check, log queries) that confirm the scenario matches this runbook vs. a sibling. At least 1 step.
5. **Mitigation** — ordered list of remediation actions that restore service. At least 1 step.
6. **Postmortem link** — slot for a postmortem URL (e.g., `[Postmortem 2026-05-25](https://...)`). A placeholder like `link TBD after incident review` is acceptable for the initial authoring; eval S1's fixture uses exactly this placeholder.

**Substantive-content invariant (binding per eval S1 + S2):** each section MUST have at least one line of substantive content. Empty headings are a FAIL. A single `TBD` token in a section is a FAIL EXCEPT in the Postmortem link section where a placeholder URL / "link TBD" is acceptable.

If the user's draft is sparse for one of the sections, push back once: *"The `<section>` section is the load-bearing part of an SRE runbook — even a one-line placeholder pointing at the right dashboard or the right command beats empty. What's the minimum useful content?"*. If the user genuinely has nothing, accept a one-sentence note describing the gap (e.g., "diagnosis is still being mapped; check the architect-critic findings from incident 2026-05-25").

---

## 8. Render + write

Render `templates/runbook.md.tmpl` (Phase 2 T2.5) via `lib/render.sh`'s `{{var}}` substitution. The template produces the six section headings in declared order.

Template variables (illustrative):

```
{{topic}}              Redis Cache Stale After Failover (human-readable form)
{{topic_kebab}}        redis-cache-stale-after-failover
{{date_authored}}      YYYY-MM-DD
{{overview_body}}      USER-AUTHORED
{{symptoms_list}}      USER-AUTHORED (bullets)
{{immediate_steps}}    USER-AUTHORED (ordered)
{{diagnosis_steps}}    USER-AUTHORED (ordered)
{{mitigation_steps}}   USER-AUTHORED (ordered)
{{postmortem_link}}    URL or "link TBD after incident review"
```

Write atomically:

```bash
SD_PLUGIN_ROOT="$(dirname "$(dirname "$(command -v sd)")")"
tmp_path="${target_path}.tmp.$$"
sd render_template "${SD_PLUGIN_ROOT}/templates/runbook.md.tmpl" > "$tmp_path"
mv "$tmp_path" "$target_path"
```

If Phase 2 inlines the section list instead of templating (per PLAN T1.8's implementation choice), compose the six headings directly via heredoc and Write. The 6-section invariant is what binds; the template-vs-inline rendering is downstream.

---

## 9. Final assistant message

After the write, emit a one-paragraph confirmation naming:

1. **The absolute path of the written file.** Render as a code-formatted block. Eval S1 + S2 explicitly check for the absolute path.
2. **The topic + section count.** E.g., *"Authored runbook for `redis-cache-stale-after-failover` with 6 sections at `<abs-path>`."*.
3. **(Optional) a follow-up hint** for committing the runbook. Runbooks in canonical typically get committed alongside the post-incident commit batch.

Do NOT close with self-congratulatory boilerplate.

---

## 10. Anti-patterns (do not do these)

- **Auto-picking a topic when the trigger phrase has none.** Eval S2 explicitly checks for the topic-disambiguation prompt as the FIRST user-facing question. Falling back to a generic name like `runbook.md` or inferring from session context is a FAIL.
- **Overwriting an existing runbook on topic collision.** Eval S3 explicitly checks no `Write`/`Edit` of the colliding file appears in the tool-call log on the collision turn. The skill bails to the menu and waits.
- **Auto-picking a menu option on collision.** Eval S3 verifies the menu is surfaced AND the existing file is unchanged — the user picks downstream.
- **Pre-creating an alternative-filename file before the user picks option 2.** Eval S3 checks no Write of any new file under the runbooks dir appears on the collision turn.
- **Writing an empty section or `TBD` placeholder in a content section.** Eval S1 explicitly checks each of the 6 sections has substantive content — Overview ≥ 1 paragraph, Symptoms ≥ 1 bullet, the rest ≥ 1 step. Only the Postmortem link section accepts a placeholder URL.
- **Mutating any peer runbook.** Eval S1 confirms the pre-existing `database-failover.md` peer file is byte-identical before and after the Write. Reading it is fine; mutating it is a FAIL.
- **Writing under `<ai-workspace>/` instead of `<canonical>/`.** Eval S1 explicitly checks the Write target is under canonical. Runbooks are production-facing per §7.1; the AI workspace is the wrong half of the dual-repo.
- **Reading manifest fields via raw `jq`.** All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve`.
- **Letting this body exceed 250 lines.** Hard cap per PLAN T1.8 line budget.

---

## 11. Notes on tool boundaries

- **You** make every judgment call: how to phrase the topic-disambiguation prompt when the trigger phrase is ambiguous, how to walk the user through the six sections when their draft is uneven, how to phrase the collision menu so option 1 (append-section) is distinguishable from option 2 (new filename).
- **Bash helpers** (`lib/manifest.sh`, `lib/render.sh`) handle manifest reads and template substitution.
- **`templates/runbook.md.tmpl`** owns the section structure; you populate the variables.
- **The user** picks on collision; you never auto-decide. The same discipline as `recording-architecture-decision`'s product-vs-process prompt — user decision boundaries are surfaced, not optimized away.

When in doubt, prefer prompting over inferring. Topic and content are both user-authored every time; collision is a user decision boundary every time.
