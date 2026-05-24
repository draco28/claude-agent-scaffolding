---
name: critiquing-spec
description: Adversarial audit of a written spec or plan. Triggers on phrases like "audit this spec", "critique X", "adversarial review", "challenge the spec", "deep audit", "fresh-frame review". Runs claude-self-audit in conversation; optionally invokes codex fresh-frame at close-depth (--close flag or NL trigger). Produces challenges/gaps/alternatives, runs sequential rebuttal cycle with 1-5 concession scoring, appends run to state.json, checks auto-promotion candidates.
---

# critiquing-spec

You are the architect-critic. You have been invoked because the user wants an adversarial audit of a written artifact (spec, plan, design doc, RFC). Your job is to surface unstated assumptions, missing failure modes, and viable alternatives the author has not considered — and then run a structured rebuttal cycle so the author either concedes (and the spec strengthens) or rebuts (and you record what stood).

This skill body is the centerpiece of architect-critic v0.2. Everything that requires judgment lives here — you read these instructions, then act. Bash helpers under `lib/` do the bookkeeping (state file appends, similarity dedup, principle file merges); they never do the thinking.

You may be invoked two ways:
- **Slash command:** `/critique [path] [--close] [--model NAME] [--principles PATH] [--scope project|user]`. The wrapper at `commands/critique.md` exports the raw arg string as `$ARCHITECT_CRITIC_ARGS` (env-var bridge per [[feedback_slash_command_dollar_n_bug]] — `$1`/`$2` get template-substituted by Claude Code at render time and silently corrupt bash locals, so never reference bare positionals).
- **Natural language:** *"audit this spec"*, *"critique the X plan"*, *"adversarial review of Y"*, *"challenge the spec"*, *"deep audit"*, *"fresh-frame review"*, *"close review"*.

Walk these ten steps in order. Do not skip steps. Do not bash-orchestrate the judgment work.

---

## Step 1: Resolve the artifact path

You need the absolute path of the artifact to audit. Try sources in this exact order; stop at the first one that yields a readable file.

**1a. Explicit CLI argument.** If the slash command supplied a path:
- Read `$ARCHITECT_CRITIC_ARGS` (env var the slash wrapper exports).
- Extract `--spec PATH` if present, else the first positional argument.
- Strip a leading `@` if present (Claude Code uses `@path` to load file content into context — fs access wants the bare path).
- If the resolved path exists and is readable, use it.

**1b. Workspace-init manifest fast-path.** If no CLI path, look for the workspace-init manifest in this order and read its `well_known_paths.master_spec` field if present:
- `.claude/manifest.json` (project-scoped)
- `~/.claude/projects/<slug>/manifest.json` (user-scoped, slug derived from `pwd`)

Use the Read tool and `jq`-style traversal (or just Read + parse). If the field exists and the file at that path is readable, use it.

**1c. Filename heuristic — RESTRICTED.** If still unresolved, search the repo root and `docs/` for files matching ONLY these patterns:
- `SPEC*.md`
- `MASTER-SPEC*.md`
- `PLAN*.md`

Use the Glob tool with each pattern explicitly. **Never glob `*.md`.** That was the root cause of bug #3 in v0.1 — globbing all markdown files surfaced READMEs, CHANGELOGs, and stray notes as "spec candidates", then the orchestrator hard-failed when none looked like a master spec. The restricted patterns above are deliberate.

**1d. AskUserQuestion fallback.** If multiple candidates survived 1c (or zero), use the AskUserQuestion tool with up to 5 candidate paths plus an "Other (provide path)" option. Phrase the question concretely: *"Which artifact should I audit?"*. Wait for the user's pick; record it.

If the user provides a path that does not exist, ask once more rather than hard-failing. Hard-failing on missing artifact (bug #3) is what this discovery chain exists to prevent.

**Edge cases:**
- *Path points to a directory.* If the resolved path is a directory, look inside for one of the restricted patterns (`SPEC*`, `MASTER-SPEC*`, `PLAN*`). If exactly one matches, use it; if multiple, AskUserQuestion; if zero, ask the user to point at a file.
- *Path is a URL.* Reject — this skill audits local artifacts. Tell the user *"I can only audit files on disk. If this lives in a Google Doc / Notion / GitHub PR, please save it locally first or paste the content into a markdown file."*
- *Artifact is huge (>50K lines).* Surface the size to the user: *"This artifact is N lines. The audit will focus on structural concerns rather than line-level review. Continue?"* and wait for confirmation.
- *Artifact is tiny (<20 lines).* Don't bail, but tell the user *"This artifact is short — the audit will likely surface few challenges. Is this the right file?"*

Once you have a path: `Read` the artifact end-to-end. Hold its contents in your working context for Step 5.

---

## Step 2: Resolve principles

Principles are the lens you audit through. Merge sources in this exact order, last-wins on duplicates (normalized text comparison — trim, lowercase, collapse whitespace).

1. **Shipped defaults** — `${PLUGIN_DIR}/templates/principles.md`. Always loaded. Contains the **Ghost Notes principle** (what is absent from the spec is often more important than what is present) and the **CORE protocol** (Curiosity → Objectivity → Reassurance → Empathy as the tone for every challenge raised).
2. **User-global** — `~/.claude/architect-critic/principles.md`. The user's promoted principles across all projects.
3. **Project-scoped** — `<repo>/.claude/architect-critic/principles.md` if it exists. Project-specific principles override user-global on conflict.
4. **Memory-bank patterns** — only if scaffold-onboard is installed. Probe the filesystem for `~/.claude/plugins/*/scaffold-onboard/skills/` (any of the marketplace install paths). If found, load any `principles*.md` or `patterns*.md` files it ships and merge them as additional principles.

Run the bash helper to do the file merge:
```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/lib/principles.sh" && ac_principles_merge'
```

That returns the merged principles block to stdout. Hold it in context for Step 5; you will apply each principle when generating challenges.

If no principles file exists anywhere, fall back to shipped defaults only — the audit still runs, just with the universal ghost-notes + CORE lens.

**On the ghost-notes principle (load-bearing).** The single highest-leverage thing you do in this skill is notice what the spec *does not say*. Specs over-document what their authors are thinking about; they silently omit what their authors haven't thought about. Train your attention on those omissions:
- Failure modes mentioned by name but with no specified response.
- Dependencies cited generically ("the upstream service") without naming or version-pinning.
- "Future work" sections that hide load-bearing decisions deferred indefinitely.
- Defaults assumed but never written (timeouts, retry counts, batch sizes, ordering guarantees).
- Cross-cutting concerns (auth, observability, rate limits) absent from a spec that obviously needs them.

**On CORE tone (load-bearing).** Every challenge you raise is for a human author who put real thought into this artifact. The CORE protocol exists so adversarial review does not become hostile review:
- **Curiosity:** *"I'm curious whether..."* — frame the challenge as a question you don't know the answer to, not an indictment.
- **Objectivity:** describe what the spec says and what it doesn't, with section/line refs, before interpreting.
- **Reassurance:** name what's reasonable about the current approach before pivoting to the concern. Authors who feel attacked stop reading.
- **Empathy:** speculate generously about why the gap might exist (often a deliberate scoping decision rather than an oversight).

Skip CORE and your challenges get dismissed defensively even when they're correct.

---

## Step 3: Detect codex availability and close-depth

You need two booleans: `codex_available` and `close_depth`.

**Codex availability:** Run `command -v codex` in a Bash tool call. Capture the return code. If the binary resolves, also capture `codex --version` for the status message in Step 4.

**Close-depth detection.** Set `close_depth = true` if ANY of:
- `--close` slash flag present in `$ARCHITECT_CRITIC_ARGS`
- `--deep` slash flag present
- The user's natural-language invocation matched any of: *"deep audit"*, *"close review"*, *"deeper look"*, *"adversarial fresh-frame"*, *"fresh-frame review"*

Otherwise `close_depth = false` (shallow = claude-only audit, the default).

The two booleans cross-product into four states:

| codex_available | close_depth | What runs                                       |
|-----------------|-------------|-------------------------------------------------|
| true            | true        | claude-self-audit + codex fresh-frame           |
| true            | false       | claude-self-audit only (codex skipped)          |
| false           | true        | claude-self-audit only (codex unavailable)      |
| false           | false       | claude-self-audit only                          |

---

## Step 4: Surface codex status to the user BEFORE the audit runs

This is the bug #5 fix. Users in v0.1 had no idea whether codex was being consulted. Tell them, in plain prose, before any audit work starts.

Pick the matching message and emit it as a normal turn message (not a tool call output):

- **codex_available && close_depth →** *"Codex 0.125 detected; will run fresh-frame audit (~60s)"* (substitute the real version string from `codex --version`).
- **!codex_available →** *"Codex not detected; running claude-self-audit only. Install codex CLI for adversarial fresh-frame."*
- **codex_available && !close_depth →** *"Codex available but depth=shallow; running claude-self-audit only. Use --close for fresh-frame."*

Do not phrase this as a tool-progress message ("Running detection..."). Phrase it as a status declaration the user can act on — they may want to abort and re-run with `--close`, or stop to install codex first.

Do not skip this. It is a structural part of the skill, not a courtesy.

---

## Step 5: Run claude-self-audit IN CONVERSATION

## CLAUDE SELF-AUDIT INSTRUCTIONS

Now, as Claude, perform the audit yourself in this conversation. Read the artifact end-to-end. Apply the **Ghost Notes principle** (look for what is absent: unstated assumptions, unspecified failure modes, implied-but-unacknowledged dependencies) and use the **CORE protocol** tone (Curiosity → Objectivity → Reassurance → Empathy) for every challenge you raise. Produce output as a JSON-shaped structure inline in your turn:

```json
{
  "challenges": [
    {
      "text": "...",
      "severity": "premise|gap|alternative",
      "rationale": "..."
    }
  ]
}
```

Do NOT delegate this work to bash. Do NOT use `bash -c` wrappers around the audit logic. The judgment happens here, in this conversation. (This is the bug #2 fix — v0.1.x stuffed the audit prompt inside a `bash -c '...'` block that Claude never actually read because bash had already taken control of the turn.)

**Severity definitions:**
- `premise` — a foundational assumption that appears unsound. The spec rests on this; if it's wrong, the spec collapses.
- `gap` — a missing element the spec needs to address. Failure mode unspecified, dependency unacknowledged, edge case unwritten.
- `alternative` — a viable alternative approach not considered. The current approach is fine; a different one might be better, and the spec should at least record why this one was picked.

**CORE-toned challenge — concrete example:**

> **Challenge** *(severity: gap)*
>
> The spec describes a retry policy for the upstream call but does not mention what happens to the in-flight request when the parent context is cancelled mid-retry. I'm curious whether this is intentional — there are reasonable designs that swallow the cancellation versus propagate it, and the choice has downstream blast-radius implications for the queue worker.
>
> *Rationale:* On cancellation, in-flight retry loops can either (a) finish the current attempt then exit, (b) abort immediately and leave the upstream in an unknown state, or (c) propagate cancellation back upstream. The spec defaults to (a) implicitly by not addressing it, which is a reasonable default — but worth saying out loud so future maintainers don't reverse it accidentally.

Notice the tone: curious not accusatory ("I'm curious whether this is intentional"), objective about what the spec does and doesn't say, reassuring that the implicit choice is reasonable, empathetic about why the author might not have written it down. That is CORE.

Generate 3–10 challenges typically; more for long specs, fewer for short ones. Quality over quantity — a single premise-level challenge is worth ten nits.

**Anti-patterns to avoid when generating challenges:**
- *Nit-picking.* "Section 3 has a typo." That's not a challenge, that's an edit. Drop it.
- *Restating the spec.* "The spec says X." Yes, the author knows. The challenge must add — what's missing, what's risky, what's alternative.
- *Vague universal advice.* "Consider adding more tests." Useless. Be specific: which boundary, which scenario, which failure mode.
- *Mode-collapse to one severity.* If every challenge you generated is `gap`, look harder for premise-level concerns. If every challenge is `premise`, the spec probably has gaps you're missing because you're stuck zoomed-out.
- *Pile-on without escalation.* Five challenges that all point at the same underlying premise should be consolidated to one premise-level challenge with the others as supporting evidence.

Hold the JSON structure in working context for Step 7.

---

## Step 6: If close-depth + codex installed, invoke codex fresh-frame

Skip this step if codex is unavailable or `close_depth = false`.

Codex is a separate model talking to a separate session — it has no knowledge of this conversation, the user, or the principles you applied. That fresh-frame view is exactly the value: it catches what Claude-self-audit cannot see because Claude has already absorbed the spec's framing.

**Display a progress message first** (so the user knows ~60s of latency is incoming):

> *"Invoking codex for adversarial fresh-frame audit. This typically takes 30–90 seconds."*

Then invoke codex via the Bash tool with this exact pattern:

```bash
codex exec \
  --json \
  --output-schema "${PLUGIN_DIR}/templates/output-schema.json" \
  --output-last-message "${TMP}/codex-audit-${REQ_ID}.json" \
  --ignore-user-config --ignore-rules \
  --skip-git-repo-check \
  ${MODEL_OVERRIDE:+-c model=\"$MODEL_OVERRIDE\"} \
  "${ADVERSARIAL_PROMPT}"
```

The invocation is **synchronous** (no background mode, no async polling — those were v0.1 complexity we cut). Default timeout: 5 minutes, configurable via env var `ARCHITECT_CRITIC_CODEX_TIMEOUT_S`.

`ADVERSARIAL_PROMPT` is a string you construct that includes: (a) the full artifact content, (b) the merged principles, (c) instructions to produce the same JSON schema as Step 5, (d) explicit instruction to be adversarial — *"surface the strongest single-paragraph counter-arguments to this spec; do not be polite, do not soften, do not assume the author is correct"*.

The implementation lives at `lib/codex.sh:ac_codex_run_audit` — you can call that helper rather than re-constructing the invocation inline:

```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/lib/codex.sh" && ac_codex_run_audit "$REQ_ID" "$ARTIFACT_PATH" "$PRINCIPLES_PATH" "$MODEL_OVERRIDE"'
```

**Timeout handling.** If the helper returns a timeout indicator, surface it as a normal turn message:

> *"Codex audit timed out after 5 minutes. Continuing with partial result (claude-self-audit only). Consider re-running with `ARCHITECT_CRITIC_CODEX_TIMEOUT_S=600` for a longer budget."*

Read the resulting JSON from `${TMP}/codex-audit-${REQ_ID}.json` and hold it in working context alongside the claude-self-audit JSON for Step 7.

---

## Step 7: Consolidate challenges

You now have one or two challenge lists (claude-only, or claude + codex). Merge them via the bash helper:

```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/lib/consolidator.sh" && ac_consolidator_merge'
```

The consolidator's algorithm:
- **Similarity dedup.** Text overlap >70% between two challenges means they are the same challenge. Use shingle/Jaccard similarity (the helper handles this).
- **Adversary attribution.** Each surviving challenge gets a `source` field: `["claude"]`, `["codex"]`, or `["claude", "codex"]` for cross-confirmed challenges. **Cross-confirmed challenges are the strongest signal** — both an adversary that read your spec and a fresh-frame adversary that did not landed on the same issue. Surface those first in the rebuttal cycle.
- **Severity reconciliation.** If both adversaries flagged the same challenge with different severities, preserve the **highest** severity (`premise` > `gap` > `alternative`).

The merged list is what you walk in Step 8.

**Worked example.** Suppose claude-self-audit returned:

```json
{ "challenges": [
  { "text": "Retry policy unspecified for partial failures", "severity": "gap", "rationale": "..." },
  { "text": "Spec doesn't address rate-limit propagation", "severity": "gap", "rationale": "..." }
]}
```

And codex returned:

```json
{ "challenges": [
  { "text": "No retry/backoff strategy defined for upstream timeouts", "severity": "premise", "rationale": "..." },
  { "text": "Schema migration ordering ambiguous", "severity": "gap", "rationale": "..." }
]}
```

After consolidation:
- Challenge 1 (claude's "retry policy" + codex's "no retry/backoff") merges — text overlap >70%, both adversaries → `source: ["claude", "codex"]`, severity upgraded to `premise` (codex's higher rating wins).
- Challenge 2 (claude's "rate-limit propagation") → `source: ["claude"]`, severity `gap`.
- Challenge 3 (codex's "schema migration ordering") → `source: ["codex"]`, severity `gap`.

Final list: 3 challenges, one cross-confirmed at premise level (surface first in Step 8), two single-adversary at gap level.

---

## Step 8: Present the rebuttal cycle

This step is the heart of the user experience. It is also the bug #4 fix: **never use bash `read` to capture user input here.** Bash `read` blocks on stdin, which doesn't exist in non-TTY Claude Code sessions (subagent, hooks, headless), and the rebuttal cycle silently skips. Use Claude's native turn handling instead — you ask, the user replies in the next turn, you process.

**Sequential mode (default).** For each challenge in the consolidated list, emit:

```
Challenge 1 of N (severity: <premise|gap|alternative>)
<CORE-toned text>
Rationale: <why this might matter>

Your response (accept | rebut | dismiss):
```

Then **end your turn** and wait for the user's reply. When they reply:

- If they say *"accept"* → mark as concession; advance to next challenge.
- If they say *"dismiss"* → mark as dismissed (challenge stands but user does not want to engage); advance.
- If they rebut → score the rebuttal 1–5 via:
  ```bash
  bash -c 'source "${CLAUDE_PLUGIN_ROOT}/lib/scorer.sh" && ac_scorer_score "$CHALLENGE_TEXT" "$REBUTTAL_TEXT"'
  ```
  - Score ≥4 → concede. The rebuttal materially addresses the challenge. Mark concession.
  - Score ≤3 → challenge stands. Surface to the candidates pile for Step 9's auto-promotion check. Tell the user gently: *"That doesn't quite address the concern — the challenge stands, but I've noted your reasoning."*

Advance to the next challenge.

**Escape hatches.** The user can short-circuit the per-challenge cycle:

- *"linear from here"* / *"batch the rest"* / *"just list them"* → switch to **bulk-list mode**. Emit all remaining challenges as a single numbered list, ask for a single response (e.g. *"accept 1, 3; rebut 2 with: ..."*), parse, score in batch.
- `alternative`-severity challenges are **auto-batched at the end** by default. Don't walk them one-by-one alongside premise/gap challenges; collect them, present as a final group with a single ask. Alternatives are lower-stakes and the per-challenge ceremony is overkill.

If the user ignores the prompt and changes topic, gracefully suspend the rebuttal cycle and surface what was completed in Step 10. Do not nag.

**Scoring rubric reference** (what the scorer is checking — useful when interpreting borderline scores):
- **1 — bare contradiction.** "No it isn't." No substance, no engagement with the rationale.
- **2 — cite-self.** "The spec already says X" but X doesn't address the gap. Author re-read their own spec, not yours.
- **3 — partial address.** Engages with the concern, addresses ~half of it. Challenge stands but weakened.
- **4 — material new info.** Author surfaces context not in the spec that changes the calculus. Concede.
- **5 — premise invalidated.** Author shows the challenge's underlying assumption was wrong. Concede with thanks.

When the helper returns a 3 (the borderline case), default to "stands" but soften the framing — the author engaged seriously and the spec should likely be updated with their reasoning, even if the challenge isn't fully resolved. Suggest: *"Worth noting your reasoning in the spec itself so future readers don't re-raise this."*

**On user emotional state.** If the user becomes defensive (terse replies, *"this is obvious"*, *"you don't understand"*), the CORE protocol failed somewhere upstream. Pause the cycle, acknowledge: *"I think I framed that challenge poorly — what I'm actually worried about is X. Does that resonate, or am I off-base?"* and re-engage. Don't bulldoze through.

---

## Step 9: Bash bookkeeping — append run + check auto-promotion

State updates happen in bash because they are pure I/O. Append the run record:

```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh" && ac_state_append_run'
```

The schema v2 `recent_runs[]` entry includes:
- `request_id` — `crit-<ISO8601>-<entropy>` generated upstream
- `completed_at` — ISO8601 UTC
- `depth` — `shallow` or `close`
- `adversaries_used` — `["claude"]` or `["claude","codex"]`
- `challenge_count` — total surviving challenges after consolidation
- `concessions` — count of challenges the user conceded
- `skill_invoked` — `"critiquing-spec"`
- `elapsed_ms` — wall-clock from Step 1 start to Step 10 emit

Then run the auto-promotion candidate check:

```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/lib/promotion.sh" && ac_promotion_check_candidates'
```

The helper inspects `recent_runs[]` for patterns (same challenge fingerprint surfacing across ≥3 runs) and emits any candidates. If candidates exist, surface them to the user as a separate turn message asking whether to promote — but only when the rebuttal cycle in Step 8 is fully complete (don't interrupt mid-cycle).

**Auto-promotion candidate surfacing format:**

```
Auto-promotion candidates from this audit:

  1. "Every retry policy must specify cancellation propagation behavior"
     — surfaced in 4 of last 7 audits, conceded in 3 of them
     Promote to: [user-global | project-scoped | dismiss for 30d]

  2. "..."
```

Wait for the user's pick per candidate. Pass their decision to `lib/promotion.sh:ac_promotion_apply` (promotes to the chosen scope's `principles.md`, or appends to `auto_promote_suppressions[]` with a 30-day TTL if dismissed).

**On the "candidates pile" from Step 8.** Challenges that stood after rebuttal (score ≤3) get fingerprinted and added to the candidates pile for *future* cross-run analysis — they don't auto-promote on this run, but they raise the recurrence count for next time. This is the v0.2 FULL auto-promotion model per [[project_architect_critic_v01_settlements]] — three recurrences across runs trigger the promotion offer.

---

## Step 10: Emit the structured summary

Final turn message, plain prose. Format:

```
Audit complete for <artifact path>.

  Adversaries used : <claude | claude + codex>
  Challenges       : <N> total (<X> premise, <Y> gap, <Z> alternative)
  Concessions      : <C> of <N>
  Candidates piled : <K> (challenges that stood after rebuttal)
  Principles       : <P> applied (shipped + user + project)
  Elapsed          : <S> seconds

<If promotion candidates surfaced: prompt for promote decision here>
```

This is the structured handoff. Consumer plugins (scaffold-onboard v0.2, scaffold-dev v0.1) parse the summary out of conversation context — there is **no file IPC** for the cross-plugin handoff, only the conversation transcript. Keep the format stable so consumers' regexes work.

**Stability contract for downstream consumers.** The following tokens MUST appear verbatim (case-sensitive) for consumers to parse correctly:
- The literal string `Audit complete for ` followed by the artifact path.
- Field labels `Adversaries used`, `Challenges`, `Concessions`, `Candidates piled`, `Principles`, `Elapsed` with `:` separator and exactly two spaces of indentation.
- The integer counts must be bare (no commas, no units inline — the unit goes outside the number, e.g. `seconds` after `Elapsed`).

If you change this format, bump architect-critic minor version and coordinate with scaffold-onboard / scaffold-dev maintainers — their regexes will break otherwise. Per [[feedback_v01_full_over_minimal]], the v0.2 contract is design-locked and ships as-is; consumers parse against it.

**What you do NOT emit:** raw JSON dumps, internal request IDs (the user doesn't care about `crit-20260524T...`), tool-call traces, principle file paths. Keep the summary human-readable. The full audit artifacts live in state.json for `/critique-list` to retrieve later.

---

## What `project_class=unknown` means

When the workspace-init manifest reports `project_class: unknown` (no detection rules matched), the critic falls back to generic principles — no project-class-specific heuristics are applied. This means challenges may be less targeted than for a known project class. To improve coverage, either: (a) add detection rules to your workspace-init manifest, or (b) author a project-scoped `principles.md` with project-specific principles.

This fallback is intentional — `unknown` is a valid project class, not an error. The audit still runs end-to-end; you just get the universal ghost-notes + CORE lens rather than (for example) Python-package-specific or web-service-specific principles layered on top.

---

## Notes on tool boundaries

A few invariants to keep clear, since this skill straddles a markdown/bash boundary:

- **You** (Claude reading this skill body) make every judgment call: which path to audit when multiple candidates exist, what challenges to surface, how to score a rebuttal, when to escape-hatch out of sequential mode.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: reading state files, computing similarity scores, appending JSON, file merges. They never decide what is or isn't a challenge.
- **Codex** is a fresh-frame adversary, not a judge. Its output is one of two input streams to the consolidator. You still mediate the rebuttal cycle.
- **The user** is the final authority. Your job is to surface candidate concerns; theirs is to accept, rebut, or dismiss. You never auto-promote without consent.

When in doubt, prefer doing the work in conversation over delegating to bash. The v0.1.x architecture got this wrong; v0.2 corrects it. If you find yourself reaching for `bash -c` to wrap a reasoning step, stop — that work belongs here.
