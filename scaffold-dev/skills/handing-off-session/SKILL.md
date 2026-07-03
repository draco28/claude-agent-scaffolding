---
name: handing-off-session
description: Compose a forward or return session handoff doc for out-of-slice transitions (sprint-boundary carry-forward, mid-slice context-bloat, bug-fix detour). Use this when the user says `handoff to next session`, `hand this off`, `context bloated`, `fresh session for VS-N.M.K`, `compose a handoff`, `write a return handoff`, or invokes `/handoff [--return ...]`. NEVER edits `.gitignore`, NEVER commits; `scaffold-dev:implementer-agent` is forbidden from invoking this skill.
---

# handing-off-session

You are scaffold-dev v0.1's handoff escape valve. The implementer-agent subagent (per SPEC §6) handles *planned work-item execution inside a slice*; you handle anything that takes the orchestrator *out* of that planned slice work — sprint boundary carry-forward, slice boundary breath, mid-slice context-bloat recovery, mid-slice bug-fix / tech-debt detour. The §6b.2 use-case table is the authoritative trigger inventory; this body is the executor.

One trigger phrase in, one markdown file out under `<ai-workspace>/.workspace/handoffs/`, with all 12 sections from §6b.5 populated (a `Next-session focus` lead field + the References and Suggested-skills sections are the #38 additions), a redaction pass run before the write, and a gitignore exit-check confirming the storage path is excluded from VCS. The work is markdown composition, not bash heavy-lifting — `lib/manifest.sh` and `lib/state.sh` give you the pointers; the judgment calls (what belongs in section 4, what the next intended action is, which candidates the redaction pass flags are real secrets) happen in conversation.

**`--ephemeral` mode (#38 leg 5):** an opt-in variant that renders the same doc to **stdout instead of writing a file** — no manifest required, no `.workspace/handoffs/` artifact, no gitignore check. Everything else (all 12 sections, the redaction pass) still applies. See §2, §3.1, and §8.

This skill is the handoff composer. It does NOT plan slices (that's `planning-vertical-slice` per §5), does NOT execute work items (that's `executing-work-item` / the implementer-agent subagent per §6), does NOT close slices (that's `closing-vertical-slice` per §14), and does NOT harvest handoff section-4 promote candidates into memory bank (that's `closing-vertical-slice`'s §15.2 step 2 sweep — downstream of this skill; your job ends at *authoring* section 4 with substantive content).

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/handing-off-session.md` — the five scenarios there (S1 sprint-boundary carry-forward, S2 mid-slice bug-fix forward, S3 return handoff, S4 mid-slice context bloat, S5 first-invocation `mkdir -p` + collision-free short-ids) are the binding spec.

---

## 1. Overview

When invoked, you:

1. **Parse `$ARGUMENTS`** via the env-var bridge (per `feedback_slash_command_dollar_n_bug`): `--scope`, `--purpose`, optional `--return <short-id>` or `--return-of <forward-filename>`, and the boolean `--ephemeral` (#38 leg 5). Missing args are resolved from conversation context (active sprint/slice cursor + the trigger phrase wording) rather than guessed silently.
2. **Discover the workspace-init pairing manifest** via `lib/manifest.sh` walk-up helpers. Refuse fail-fast if absent (same refusal text as `planning-vertical-slice` §3.1 — handoffs require the dual-repo manifest contract) — **unless `--ephemeral` is set**, which bypasses the manifest requirement entirely (§3.1).
3. **Resolve the handoffs directory** via `sd_manifest_resolve` against `routing.handoffs_dir` (or fall back to `<ai_workspace.root>/.workspace/handoffs/`); `mkdir -p` it if absent (lazy creation per §6b.1; workspace-init seeded the parent `.workspace/` per its §4.3).
4. **Validate scope** against the §6b.1 enum (`sprint`, `slice`, `mid-slice`, `bugfix`, `techdebt`, plus the `sprint-N` and `vs-N.M.K` numbered variants that appear in the §6b.1 filename examples) and **sanitize purpose** to kebab-case.
5. **Detect forward-vs-return.** If `--return <short-id>` or `--return-of <forward-filename>` is present OR the trigger phrase context indicates this session IS a fork session reporting back (per §6b.4 chain model), this is a return handoff: reuse the original short-id, emit a `-return.md` filename, mark Header type=`return`. Otherwise this is a forward handoff: generate a fresh 4-char hex short-id.
6. **Gather state pointers** via `lib/state.sh::sd_state_read_cursor` (active sprint, active slice, active work-item position, worktree paths) and `lib/manifest.sh::sd_manifest_get` (ai_workspace.root, canonical.root, branch_naming, worktrees_dir).
7. **Compose the 12 sections** per §6b.5 using `templates/handoff.md.tmpl` + `lib/render.sh` `{{var}}` substitution, plus the `Next-session focus` lead field. Sections 4 (What's NOT in memory bank yet) and 9 (Next intended action(s)) are the two REQUIRED user-prompted sections (see §6 and §7 below); auto-extract candidates from session context first, but refuse to write the file if either is empty. Author the new References (§8) and Suggested-skills (§10) sections and the focus field per §5.4.
8. **Run the redaction pass, then write.** Before writing (or printing), scan the composed content in memory for secret/PII candidates and resolve them warn-and-confirm (§8.1). Then **write the safe content atomically** to the resolved path (temp sibling + `mv`) — OR, if `--ephemeral`, **print to stdout** and skip the write, the gitignore check, and step 9.
9. **Read `.gitignore`** at `<ai-workspace>/.gitignore` and verify the pattern `.workspace/handoffs/` (or a superset like `.workspace/`) is present (durable mode only; skipped under `--ephemeral`). If missing, surface a warning in the final assistant message naming the pattern AND suggest the user re-run `workspace-init` or append the line manually — do NOT auto-edit `.gitignore` (workspace-init's §8.3 lane).
10. **Emit the final assistant message.** Durable mode names the absolute path of the written file AND the opening prompt for the next session: `Read the handoff at <abs-path> and proceed`. `--ephemeral` mode prints only the handoff text; it makes no file-path claim.

---

## 2. When to use

**Trigger phrases (description-match):**

- `handoff to next session` (both forward and return — context determines which; see §3.4)
- `hand this off`
- `context bloated` (orchestrator-side recovery; scope widens to `sprint-N` per §6b.1)
- `fresh session for VS-N.M.K` (mid-slice handoff, slice-scoped)
- `compose a handoff`, `write a handoff`, `write a return handoff`
- `/handoff [--scope ...] [--purpose ...] [--return ...]` (slash command — see §10 for the `$ARGUMENTS` env-var bridge)

All six phrase forms are load-bearing in the description block above — the five eval scenarios trigger via description-match on the first four (S1 and S3 reuse the same `handoff to next session` phrase to verify context-discrimination; S2 uses `hand this off`; S4 uses `context bloated`; S5 uses `fresh session for VS-1.1.1`).

**Do NOT auto-invoke when:**

- The user wants to *plan* a slice (that's `planning-vertical-slice`), *execute* a work item (that's `executing-work-item` / the implementer-agent subagent), *verify* a completed work item (that's `implementation-checking`), or *close* a slice (that's `closing-vertical-slice`).
- You ARE the `scaffold-dev:implementer-agent` subagent. Per SPEC §6b.7 subagent boundary rule, the implementer-agent MUST NOT invoke `handing-off-session`. Out-of-slice transitions belong to the orchestrator; the subagent ARE the planned slice work and should not compose a session handoff from inside its run. If you find yourself reading this body from inside a subagent context, stop and surface `"handing-off-session is forbidden from the implementer-agent per SPEC §6b.7"` in your structured return.
- No workspace-init pairing manifest exists AND `--ephemeral` is NOT set. The durable handoff storage path is anchored at `<ai-workspace>/.workspace/handoffs/`; without a manifest there is no anchor. Refuse with the same verbatim string `planning-vertical-slice` uses (see §3.1). **Exception:** `--ephemeral` prints to stdout and needs no anchor, so it bypasses this refusal (§3.1) — it's the supported path for non-dual-repo projects and ad-hoc compaction moments.

If the user types something ambiguous like "save state" or "I'm tired", ask: *"Compose a session handoff (writes a markdown file under `.workspace/handoffs/` for the next session to read)?"*. Don't infer-and-compose silently — a handoff is a deliberate ceremony, not a passive save.

---

## 3. Pre-flight + arg parsing

### 3.1 Manifest discovery (refuses fail-fast, unless `--ephemeral`)

**Ephemeral short-circuit (#38 leg 5).** If `--ephemeral` is set (`SCAFFOLD_DEV_EPHEMERAL=true`), SKIP manifest discovery entirely: there is no durable path to anchor, so no manifest is needed. Jump straight to arg parsing (§3.3) and section composition; manifest/state-derived fields render as `n/a — ephemeral handoff, no workspace manifest` where unavailable. `--return <short-id>` works normally because it carries the chain id inline. `--return-of <forward-filename>` may read the named forward only when the value is an absolute/readable path; otherwise parse the short-id from the filename, mark forward-derived context unavailable, and stop only if the filename does not contain a 4-char hex handoff id. Ephemeral output goes to stdout (§8), never to disk.

Otherwise (durable mode), call `sd_manifest_discover` (lib/manifest.sh) to walk up from `pwd` for `.workspace/pairing.json`. If discovery returns absent — i.e. `sd_manifest_require` exits non-zero — surface this verbatim refusal and stop:

> scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first.

The literal slash-command tokens `/init-workspace` and `/pair-workspace` are load-bearing — they mirror the refusal text from `planning-vertical-slice` §3.1 so the user sees a consistent recovery path across scaffold-dev skills. Do NOT proceed to parse args, do NOT compute any short-id, do NOT touch `.workspace/handoffs/`. (This refusal never fires under `--ephemeral` — that path is the deliberate escape hatch for manifest-less projects.)

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS and bare `source` of these libs crashes with `BASH_SOURCE[0]: parameter not set`):

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

### 3.2 Read manifest fields

All manifest field reads go through `sd_manifest_get` / `sd_manifest_resolve` (binding per `planning-vertical-slice` §3.2; never raw `jq` against `pairing.json`).

```bash
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
canonical="$(sd manifest_get '.canonical.root')"
handoffs_dir="$(sd manifest_resolve "$(sd manifest_get '.routing.handoffs_dir')")"
worktrees_dir="$(sd manifest_get '.during_dev.worktrees_dir')"
branch_naming="$(sd manifest_get '.during_dev.branch_naming')"
```

If `routing.handoffs_dir` is absent from the manifest (older workspace-init versions), fall back to `${ai_workspace}/.workspace/handoffs/`. The fallback is silent — the v0.1.0 workspace-init seeds this path by default; only pre-v0.1 manifests would lack the routing entry.

### 3.3 Parse `$ARGUMENTS`

Parse the raw arg string (Mode: slash-command invocation; see §10 for the env-var bridge). Never reference `$1` / `$2` directly — Claude Code substitutes positionals at template-render time and silently corrupts them.

Extract:

- **`--scope <enum>`** — one of `sprint`, `slice`, `mid-slice`, `bugfix`, `techdebt`, OR a numbered variant: the **sprint** form `^sprint-[0-9]+(\.[0-9]+)?$` (#28: the active sprint id is the dotted `sprint_id`, e.g. `sprint-1.1`; a bare `sprint-N` is tolerated for back-compat) or the **3-part** slice form `^vs-[0-9]+\.[0-9]+\.[0-9]+$` (slice ids are `vs-<phase>.<sprint>.<slice>`, e.g. `vs-1.1.1`, so the slice-scoped prefix the close-time harvest globs is `vs-1.1.1-*`). The §6b.1 filename examples use the numbered forms (`vs-1.1.1-bugfix-auth-a1b2.md`, `sprint-1.1-context-bloat-c3d4.md`, `sprint-1.1-to-1.2-handoff-g7h8.md`), so the numbered forms ARE valid scopes — they expand the §6b.1 enum, they do not violate it. Reject anything outside this set with a one-line error naming the rejected value AND the accepted enum.
- **`--purpose <slug>`** — the human-readable purpose token. Sanitize to kebab-case with dotted sprint ids preserved: lowercase, replace whitespace + underscores with `-`, strip everything not in `[a-z0-9.-]`, collapse repeated dashes, trim leading/trailing dashes. Examples: `"to-4-handoff"`, `"to-1.2-handoff"`, `"bugfix-auth"`, `"context-bloat"`, `"techdebt-logging"`.
- **`--return <short-id>`** OR **`--return-of <forward-filename>`** (optional, mutually exclusive) — presence flips this to a return handoff per §3.4. The `--return` form takes a 4-char hex short-id; the `--return-of` form takes a full forward filename (e.g., `vs-1.1.1-bugfix-auth-a1b2.md`) which you parse to extract the short-id. Both produce the same effect: reuse the existing short-id rather than generate a new one.
- **`--ephemeral`** (optional, boolean — no value; #38 leg 5) — opt into stdout-only mode. When present (`sd handoff_parse_flags` emits `true` on its 5th line → the `/handoff` wrapper exports `SCAFFOLD_DEV_EPHEMERAL=true`), skip manifest discovery (§3.1), render the full doc to stdout, and skip the file write + gitignore check (§8). No short-id/path/mkdir work is needed since nothing persists — but a short-id may still be minted for the Header for readability.

If `--scope` or `--purpose` is missing from `$ARGUMENTS`, attempt resolution from conversation context (the trigger phrase + the active-context cursor); see §3.5. If still unresolved, ask the user one specific question (not "what scope?" — *"Is this a sprint-N→N+1 carry-forward, a mid-slice detour, a context-bloat recovery, or a slice boundary breath?"*) and wait.

### 3.4 Forward vs return detection

Two signals; either flips this to return-mode:

1. **Explicit flag.** `--return <short-id>` or `--return-of <name>` is present in `$ARGUMENTS`.
2. **Conversation context.** The session was opened by reading an existing forward handoff (the user's opening message names a forward handoff path; or the active-context cursor records "session opened from `.workspace/handoffs/<forward-name>.md`"); the user now wants to report back per the §6b.4 chain model.

If either fires:

- Mark Header type=`return` in the rendered template.
- Reuse the existing short-id (parse from `--return-of` filename or take `--return` directly). Do NOT generate a new short-id; the chain model requires the forward + return pair to share an ID so a downstream main session C can grep them as a unit.
- Append the `-return.md` suffix to the filename: `<scope>-<purpose>-<short-id>-return.md`.
- Read the existing forward handoff before composing the return — confirm the short-id, read the forward's Next intended action(s) section (section 9 in the #38 layout; section 8 in pre-#38 forwards — match by name, not number) to ground the return's Section 2 (Purpose: "what the fork session accomplished against the forward's next-action").

If neither signal fires, this is a forward handoff: generate a fresh 4-char hex short-id (§3.6), mark Header type=`forward`.

### 3.5 Conversation-context fallback for missing args

If `--scope` is missing, resolve from the trigger phrase first, then from the active-context cursor:

- `context bloated` → scope = `sprint-N` where N is the active sprint (whole-session recovery widens scope past the active slice per §6b.1 example `sprint-3-context-bloat-c3d4.md`).
- `fresh session for VS-N.M.K` → scope = `vs-N.M.K` (slice-narrow, mid-slice).
- `handoff to next session` at a sprint-close boundary → scope = `sprint-N` with purpose defaulting to `to-(next_sprint_id)-handoff` (carry-forward, §6b.6; preserve dots, e.g. `to-1.2-handoff`).
- `hand this off` mid-slice with a known bug detour intent → scope = `vs-N.M.K`.

If `--purpose` is missing, prompt the user with one concrete question naming the resolved scope: *"What's the purpose slug for this `<scope>` handoff? (kebab-case; e.g., `bugfix-auth`, `to-1.2-handoff`, `context-bloat`)"*. Wait for the user's response; do not invent a slug.

### 3.6 Short-id generation (forward handoffs only)

Generate a 4-char lowercase hex short-id. Use `/dev/urandom` for entropy:

```bash
short_id=$(od -An -tx1 -N2 /dev/urandom | tr -d ' \n')
```

The 4-char hex space (16⁴ = 65,536 IDs) is adequate for v0.1 collision avoidance because handoffs are sprint-scoped and a sprint rarely accumulates more than ~10 of them per §6b.6. If you ever need to compose two handoffs of identical `<scope>-<purpose>` in the same session (S5's second sub-run), regenerate — do NOT skip generation. Eval S5 explicitly verifies that back-to-back invocations with identical scope+purpose produce DISTINCT short-ids.

For return handoffs, skip generation — reuse the source forward's short-id per §3.4.

---

## 4. Compose the file path + ensure handoffs/ subdir exists

### 4.1 Path composition

```bash
filename="${scope}-${purpose}-${short_id}.md"
[[ -n "$is_return" ]] && filename="${scope}-${purpose}-${short_id}-return.md"
target_path="${handoffs_dir%/}/${filename}"
```

Forward example: `<ai-workspace>/.workspace/handoffs/vs-1.1.1-bugfix-auth-a1b2.md`
Return example: `<ai-workspace>/.workspace/handoffs/vs-1.1.1-bugfix-auth-a1b2-return.md`
Carry-forward example: `<ai-workspace>/.workspace/handoffs/sprint-3-to-4-handoff-g7h8.md`
Context-bloat example: `<ai-workspace>/.workspace/handoffs/sprint-3-context-bloat-c3d4.md`

**Filename pattern invariant (binding per eval cross-scenario):** every filename you write MUST match `^[a-z0-9.-]+-[a-z0-9.-]+-[0-9a-f]{4}\.md$` for forward handoffs OR `^[a-z0-9.-]+-[a-z0-9.-]+-[0-9a-f]{4}-return\.md$` for return handoffs. The judge rejects: timestamps in the filename, short-ids of fewer or more than 4 hex chars, uppercase hex, missing `.md` extension, scope segments that don't match the invocation context (e.g., `sprint-3-...` when the scenario invoked from VS-3.2 mid-slice), or dotted sprint carry-forward purposes collapsed from `to-1.2-handoff` to `to-12-handoff`.

### 4.2 Lazy mkdir on first invocation

Before writing, ensure the `handoffs/` subdir exists. workspace-init seeded the parent `.workspace/` (per workspace-init SPEC §4.3) and the `.gitignore` line `.workspace/handoffs/` (per its §8.3), but NOT the `handoffs/` subdir itself — that's this skill's responsibility on first invocation, per SPEC §6b.1 "lazily creates the `handoffs/` subdir on first invocation via `mkdir -p`".

```bash
if [[ ! -d "$handoffs_dir" ]]; then
  mkdir -p "$handoffs_dir"
fi
```

On subsequent invocations the directory exists; the `[[ -d ]]` guard makes `mkdir -p` a no-op skip rather than running unconditionally. Eval S5 verifies BOTH halves of this contract: first sub-run runs `mkdir -p` (against the absent subdir); second sub-run (run on first sub-run's post-state, no fixture reset between them) does NOT run `mkdir -p` (skip-on-present is binding).

The mkdir invocation MUST appear in your tool-call log BEFORE the `Write` of the handoff file — you can't write into a directory you haven't created yet. The judge keys off relative tool-call position.

---

## 5. Gather state + compose sections

### 5.1 State cursor (active sprint, slice, work-item position)

```bash
sd state_read_cursor    # populates: ACTIVE_SPRINT, ACTIVE_SLICE, ACTIVE_WORK_ITEM, ACTIVE_BRANCH, ACTIVE_WORKTREE
```

(All `sd <fn-suffix>` invocations go through the `sd` dispatcher per §3.1 above.)

If the state cursor is empty (no active slice — e.g., between sprints, or fresh project pre-orchestration), the slice-scoped sections (3 State pointers, 6 In-flight state) render with `n/a — no active slice at handoff time` rather than fabricated values. Sprint-boundary carry-forward handoffs (S1) often run with the just-closed sprint as `ACTIVE_SPRINT` and no `ACTIVE_SLICE` — that's expected.

### 5.2 Compose the 12 sections + focus field (verbatim titles per §6b.5)

Render `templates/handoff.md.tmpl` via `lib/render.sh`'s `{{var}}` substitution. Above section 1, emit the **`Next-session focus:`** lead field (#38 leg 4) — one plain-language line on what the next session should do first; see §5.4. Then the 12 sections MUST appear with these EXACT titles, in this order, as `##` level markdown headings:

1. **Header** — handoff type (`forward` | `return`), scope, purpose, short-id, source-session label, composed-on date, project name, branch. Auto-fill from manifest + state cursor + clock; the user does not author Header content.
2. **Purpose** — one paragraph: why handing off. Forward handoffs name the reason for the out-of-slice transition (sprint boundary / context bloat / bug-fix detour). Return handoffs name what the fork session accomplished against the forward's Next intended action(s) section.
3. **State pointers** — workspace paths (ai_workspace.root, canonical.root), active sprint/slice/work-item IDs, active worktree absolute path, active branch name. Auto-fill from §5.1; the user does not author State pointers content.
4. **What's NOT in memory bank yet** — REQUIRED, user-prompted (§6 below). The ephemeral pre-codification content; the value-add over memory bank.
5. **Workflow deviations** — any deviations from standard scaffold-dev workflow active in this session (e.g., "single-repo development, not dual-repo", "subagent dispatches replaced with inline reasoning per §6.4 fallback", "round 2 was retried with a fresh subagent after gaps-mode loop hit the 3-iteration cap"). May be empty (heading still appears).
6. **In-flight state** — open work items, partial commits, branches needing merge, subagents dispatched but not yet returned. Auto-extract from state cursor + recent tool-call history where possible; user clarifies the rest if needed.
7. **Must read before doing anything** — specific files beyond Tier 0 auto-load. Concrete absolute paths only — no vague "the spec file" without path (eval S4 explicitly rejects vague references). Typical entries: work-item spec path, VS README path, ROADMAP entry path, recent ADR path, the forward handoff path (return handoffs only).
8. **References** — NEW (#38 leg 2). A dispatchable index of artifacts the next session can point subagents straight at: specs, ADRs, commits (by SHA), GitHub issues/PRs, diffs, docs — each cited by path / URL / commit-SHA with a one-line "what's here", NEVER pasted content. May be empty (heading still appears). See §5.4.
9. **Next intended action(s)** — REQUIRED, user-prompted (§7 below). Single specific action OR ranked list of options. Concrete, actionable, names the cursor unambiguously.
10. **Suggested skills / plugins** — NEW (#38 leg 1). Advisory list of likely next-session capabilities named as `plugin:skill` (e.g. `scaffold-dev:orchestrate`, `architect-critic:critiquing-spec`, `ai-mentor:grill-me`, or bare `GitHub`/`browser` tools), reasoned from the next-action + must-read context. Advisory only — the next agent verifies applicability before invoking; never collapse plugin boundaries. May be empty (heading still appears). See §5.4.
11. **Anti-actions** — explicit "do NOT do X" warnings. Carries over §6b.2 / §6.6 anti-patterns AND any session-specific anti-actions the user names (e.g., "do NOT retry the auth fix attempt that failed for reason Y").
12. **Return-handoff template stub** — REQUIRED on forward handoffs; populated with sub-headings `Summary`, `Deferrals`, `Cautions`, `Memory bank promotion candidates` (per the master-session `docs/HANDOFF-scaffold-dev-build.md` prototype, which IS the working example of this pattern). On return handoffs, this heading still appears (parser-friendly 12-section contract is binding) but rendered as `n/a — this IS a return handoff` or equivalent.

**12-section invariant (binding per eval cross-scenario):** EVERY handoff file you write — forward OR return — contains all 12 headings in order, with the exact titles above, AND the `Next-session focus:` lead field above section 1. The judge scans for each title as a level-agnostic markdown heading (`##` or `###`); a missing or renamed section is a FAIL. Section 9's `(s)` suffix is the only paraphrase the judge accepts ("Next intended actions" with or without parens). The two REQUIRED-non-empty user-prompted sections are 4 and 9; sections 8 (References) and 10 (Suggested skills) may be empty (heading present) when genuinely none apply.

### 5.3 Template + substitution

The template file is `templates/handoff.md.tmpl` (authored in Phase 2 T2.3 of the PLAN). Substitutable vars, matching that template's `<!-- vars: -->` contract exactly:

```
{{handoff_type}}               forward | return
{{scope}}                      sprint | slice | mid-slice | bugfix | techdebt
{{scope_specifier}}            e.g. "VS-3.2 in sprint-3"
{{purpose_slug}}               kebab-case filename purpose
{{short_id}}                   4-char hex; paired forward/return id
{{source_session_metadata}}    authoring session + context metadata
{{references_forward_handoff}} paired forward filename, or "n/a"
{{purpose_paragraph}}          one paragraph explaining why this exists
{{state_pointers_block}}       workspace paths, sprint/slice IDs, worktrees, branches
{{not_in_memory_bank_block}}   USER-AUTHORED — see §6
{{workflow_deviations}}        deviations from standard workflow, or "None."
{{in_flight_state_block}}      open work, partial commits, dispatched subagents
{{must_read_before_doing}}     specific files beyond Tier 0 auto-load
{{next_intended_actions}}      USER-AUTHORED — see §7
{{anti_actions_block}}         "do NOT" bullets
{{return_template_stub}}       section 12 body
{{next_session_focus}}         #38 leg 4 lead field (§5.4)
{{references_block}}           #38 leg 2 artifact index (§5.4)
{{suggested_skills_block}}     #38 leg 1 advisory plugin:skill list (§5.4)
```

Use `lib/render.sh`'s `{{var}}` substitution pattern (matches the scaffold-onboard / architect-critic / closing-vertical-slice precedent). Never inline-render with `sed` or `printf`; the helper handles escaping consistently.

### 5.4 Authoring the #38 additions (focus field, References §8, Suggested-skills §10)

These three are agent-authored by reasoning over session context — not user-prompted like sections 4 and 9, and not required-non-empty (References and Suggested-skills may be empty when none apply).

- **Next-session focus field** (leg 4). One plain-language sentence naming what the receiving session should do FIRST — the "why you're here" orientation, distinct from the `--purpose` filename slug (a slug) and from section 9 (a concrete action cursor). Example: `Land the auth-expiry bug-fix so VS-3.2 can resume; the failing test is already written.` Always author it; it's the lead line a fresh session reads.
- **References §8 — artifact-reference discipline** (leg 2). This leg is BOTH a section AND a cross-cutting discipline: **prefer references over pasting**. Throughout the whole doc, cite specs / ADRs / commits (SHA) / GitHub issues·PRs / diffs / docs by path·URL·SHA instead of copying large content — it de-bloats the handoff AND lets the receiving main session dispatch subagents straight at the reference. Section 8 consolidates the key artifacts as a scannable index, one line each: `` `docs/…/spec.md` `` — what's here. Empty (heading only) is fine if the must-read list (§7) already covers everything.
- **Suggested skills / plugins §10** (leg 1). Reason from section 9's next-action + section 7's must-reads to name the capabilities the next session will likely need, as `plugin:skill` tokens (`scaffold-dev:orchestrate`, `architect-critic:critiquing-spec`, `ai-mentor:grill-me`) or bare tool families (`GitHub`, `browser`). ADVISORY — the next agent still verifies applicability before invoking; never merge or blur plugin boundaries. Empty is fine when the work is generic.

---

## 6. Section 4 — REQUIRED, user-prompted, never empty

Section 4 ("What's NOT in memory bank yet") is the value-add over memory bank per §6b.5 emphasis. Memory bank captures *codified* state; section 4 captures the ephemeral pre-codification content: slice-specific decisions, conversation deltas, negative-space ("we tried X and rejected it because Y"), time-sensitive constraints, half-formed hypotheses, tool-call insights that didn't make it to artifacts.

### 6.1 Auto-extract candidates first

Before prompting, scan the recent session context for candidate section-4 content:

- Decisions reached in conversation that haven't been written to a spec, ADR, or memory-bank file.
- Approaches the user explicitly rejected ("we tried X and it didn't work because Y" — the negative-space the next session shouldn't re-derive).
- Half-formed hypotheses the user wants the next session to start from rather than re-derive.
- Specific commit SHAs, file paths, or branch names referenced in the last several turns that the next session needs.
- Anti-patterns the user named but that aren't yet in `09-known-issues.md` or `03-code-patterns.md`.

Present the auto-extracted candidates as a draft bulleted list and ask: *"Section 4 draft — keep / edit / add anything? (this section is the value-add over memory bank; the next session will rely on it for context the memory bank doesn't yet hold)"*.

### 6.2 User prompt (REQUIRED, refuses empty)

If auto-extraction produces no candidates (fresh session, sparse context, edge cases), prompt the user directly with this verbatim text:

> What's NOT in memory bank yet? List slice-specific decisions, deviations, conversation deltas, anti-patterns, half-formed hypotheses, or any other pre-codification context the next session needs. This is the value-add over memory bank.

Wait for the user's response. Do NOT proceed to write the file with section 4 empty.

### 6.3 Non-empty invariant (binding per eval cross-scenario)

The section-4 non-empty invariant is BINDING per `evals/handing-off-session.md`'s cross-scenario contract. Section 4 MUST contain at least one substantive bullet OR one prose paragraph of substantive content. The judge rejects:

- An empty heading (heading followed by blank line, then section 5).
- A single-token placeholder: `TBD`, `(none)`, `n/a`, `pending`, `—`.
- A file written without the user-prompt round-trip when section 4 would otherwise be blank.

If the user responds to the prompt with one of the rejected placeholders ("just put TBD"), push back once: *"Section 4 is the value-add over memory bank; an empty section 4 makes this handoff worth less than a memory-bank entry. Anything from the last hour of work that's not yet codified? A surprising spec gap, a defensible-but-not-locked decision, a thread the next session shouldn't have to re-pick-up?"*. If the user genuinely has nothing (e.g., a trivial sprint-boundary carry-forward where everything material is already in memory bank), accept their second response — but the file content MUST have at least one prose sentence describing why section 4 is sparse this time, not the literal placeholder.

---

## 7. Section 9 (Next intended action(s)) — REQUIRED, user-prompted

Section 9 ("Next intended action(s)") names what the next session should do first. Per the §6b.5 description, it's a "single specific action OR ranked list of options" — concrete enough that the receiving session can act without re-deriving. (This was section 8 before #38 inserted the References section at position 8; the content and its required-non-empty contract are unchanged — only the position moved.)

### 7.1 Auto-extract from state cursor

If the state cursor names an `ACTIVE_WORK_ITEM`, the default Section 9 candidate is the orchestrator action that was about to fire when the handoff was triggered:

- Mid-slice with a work-item-spec just authored → "dispatch implementer-agent subagent for `work-N.NN-<kebab>` per its handoff doc at `<abs-path>`".
- Mid-slice with a subagent return just received → "run `implementation-checking` against the work-item's `report.md` at `<abs-path>`".
- Sprint boundary → "kick off sprint-(N+1) planning by invoking `planning-vertical-slice` for VS-(N+1).1".

Present the auto-extracted candidate and ask: *"Section 9 draft — is this the next intended action? Edit if not."*.

### 7.2 User prompt (REQUIRED)

If auto-extraction produces no candidate, prompt the user:

> What's the next intended action for the receiving session? Be specific — name the file path, the work item, the subagent dispatch, or the slice cursor. Not "continue work"; not "resume slice".

Eval S4 explicitly rejects vague phrasings ("continue work", "resume slice"); the judge requires the action verb AND the cursor reference (work-item ID, slice-ID, or file path) to appear in section 9 content.

For return handoffs (per S3), section 9 names what the consuming main session C should do — typically a directive like "resume VS-N.M.K from `work-N.NN` with the auth fix landed; revisit auth TTL hard-code in next tech-debt round". Same concreteness bar.

---

## 8. Redaction pass, then write (or print if ephemeral)

Compose the rendered markdown into a shell variable via `lib/render.sh::sd_render_template`. **Before it lands anywhere** — durable file OR ephemeral stdout — run the redaction pass (§8.1). Then either write the resolved safe content (§8.2, durable) or print it (§8.3, `--ephemeral`).

```bash
# Discover scaffold-dev plugin root via the dispatcher on $PATH
# (works under zsh; does NOT depend on $CLAUDE_PLUGIN_ROOT which the host
# runtime does not export to Bash subprocesses per anthropics/claude-code#48230).
SD_PLUGIN_ROOT="$(dirname "$(dirname "$(command -v sd)")")"

rendered_markdown="$(sd render_template "${SD_PLUGIN_ROOT}/templates/handoff.md.tmpl" "$vars_json")"
safe_markdown="$rendered_markdown"
```

### 8.1 Redaction pass (#38 leg 3 — runs in BOTH modes, before anything lands)

The pass is **hybrid**: a mechanical bash candidate-surfacer flags likely secrets/PII by pattern; **you (the agent) judge each candidate in context** and drive a warn-and-confirm loop. Redaction judgment is reasoning — it is yours, not the surfacer's (North Star §1).

1. Surface candidates: `printf '%s\n' "$safe_markdown" | sd redact_candidates -` → emits `<lineno>\t<category>\t<match>` lines (categories: github-token, openai-key, aws-access-key, slack-token, pem-private-key, url-credentials, email, labeled-secret). Empty output ⇒ nothing to review; proceed to the write/print.
2. Judge each candidate **in context**. Most are real (a live `ghp_…` token, a `password: …` line). Some are benign — e.g. the author's own email in the Header's source-session metadata, or a placeholder like `sk-EXAMPLE`. Use the surrounding line to decide.
3. If ANY candidate is a real secret/PII, **halt before the write/print** and surface each finding to the user with a proposed replacement (`[REDACTED-GITHUB-TOKEN]`, `[REDACTED-EMAIL]`, …). Resolve **per-finding**: `redact` (replace in `safe_markdown`), `keep-this-one` (benign / intentional), or `edit` (custom replacement); or the user may `cancel` the whole handoff. **Nothing is written or printed while a real finding is unresolved.**
4. There is NO blanket `--no-redact` bypass — the per-finding `keep-this-one` IS the escape hatch, and it requires a deliberate choice, satisfying the "no secret written without user confirmation" contract.

False-positive cost is one keystroke (`keep-this-one`); the residual false-negative risk is whatever the pattern set + your judgment both miss — acceptable for a handoff, not a substitute for real secret hygiene.

### 8.2 Durable write (atomic mv)

For a normal (non-ephemeral) handoff, after redaction resolves, write `safe_markdown` to a sibling temp file and move it into place:

```bash
tmp_path="${target_path}.tmp.$$"
printf '%s\n' "$safe_markdown" > "$tmp_path"
mv "$tmp_path" "$target_path"
```

The atomic-mv pattern matches the scaffold-onboard / closing-vertical-slice precedent. Because the temp file is created only after redaction resolves, a cancel/crash before then leaves no pre-redaction handoff content on disk.

After write, verify the file is on disk and matches the filename invariant (§4.1). If `ls "$target_path"` fails, surface the failure and stop — do NOT proceed to the gitignore exit-check, do NOT emit a success message naming a path that doesn't exist.

**Do NOT** edit, delete, or rename any other file under `.workspace/handoffs/`. The skill never deletes peer handoffs (eval S5 explicitly verifies no `rm` or `git rm` against the first sub-run's file appears in the second sub-run's tool-call log); cleanup is `closing-vertical-slice`'s lane (§15.2) and sprint-close's lane (§6b.6).

### 8.3 Ephemeral print (#38 leg 5 — `--ephemeral`, stdout only)

If `SCAFFOLD_DEV_EPHEMERAL=true`, do NOT write a file and do NOT touch `.workspace/handoffs/`. After redaction (§8.1) resolves on the composed content, **print `safe_markdown` to the conversation** as a copy-paste fresh-session prompt. SKIP §9 (gitignore exit-check) entirely — there is no persisted artifact to gitignore. The content is the SAME 12-section doc as durable mode; only the destination differs. This is the supported path for non-dual-repo projects and ad-hoc compaction where the user wants a prompt but not a durable artifact.

---

## 9. Gitignore exit-check (binding, read-only — durable mode only)

**Skipped entirely under `--ephemeral`** (§8.3): there is no persisted file to gitignore. This section applies only to durable handoffs.

Before emitting the final assistant message, Read `<ai-workspace>/.gitignore` and verify the literal pattern `.workspace/handoffs/` (or a superset like `.workspace/` that subsumes it) is present.

```
Read: <ai-workspace>/.gitignore
```

**This is a Read, not a Bash `cat`.** The tool-call log distinguishes Read invocations from Bash; the eval's judge looks for the literal Read entry against the `.gitignore` absolute path AFTER the handoff file Write AND BEFORE the final assistant message. The position is binding — the check is an exit-check, not a pre-flight check.

Three outcomes:

1. **Pattern present.** Surface no warning; proceed to §10.
2. **Pattern missing.** Surface a one-paragraph warning in the final assistant message naming the missing pattern AND suggesting the user re-run `workspace-init` (which seeds the pattern per its §8.3) OR manually append the line `.workspace/handoffs/` to `<ai-workspace>/.gitignore`. The skill itself NEVER auto-edits `.gitignore` — that's workspace-init's lane, and a stray edit here would create a write-conflict with workspace-init's own future updates per the §17 write-conflict separation principle.
3. **Gitignore file absent.** Surface the same warning shape as outcome 2; the pattern is moot if the file doesn't exist at all. Suggest re-running `workspace-init`.

The handoff file write itself is NOT rolled back on a missing-pattern outcome — the file lives at the gitignored path either way; the warning is informational so the user knows their next `git status` may surface the file as untracked. The skill's job is to surface the gap, not to remediate it.

**Read-only contract (binding):** the tool-call log MUST NOT contain any `Write` or `Edit` against `.gitignore`, any `git add .gitignore` invocation, any `sed -i` against `.gitignore`, or any other mutation. The eval's judge scans for these across all five scenarios; any mutation is a FAIL.

---

## 10. Slash-command interaction (`/handoff [--scope ...] [--purpose ...] [--return ...]`)

The `/handoff` slash command (`commands/handoff.md`, Phase 2 wrapper) exports the raw arg string as `$ARGUMENTS` per the env-var bridge (per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1` / `$2` / etc. at template-render time and silently corrupts bash positionals).

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2`:

```bash
# $ARGUMENTS is the raw arg string, e.g.:
#   --scope vs-1.1.1 --purpose bugfix-auth
#   --scope sprint --purpose to-4-handoff
#   --scope vs-1.1.1 --purpose bugfix-auth --return a1b2
#
# Parse by regex via BASH_REMATCH — NEVER bare $1/$2 in a case loop: the
# slash-command renderer freezes bare positionals at template-render time, so
# `case "$1"` matches against a frozen literal and every flag comes out empty
# (#19). The /handoff wrapper delegates this to the shared, unit-tested helper
# `sd handoff_parse_flags`; the equivalent inline form is:

args="$ARGUMENTS"
scope=""; purpose=""; return_id=""; return_of=""
[[ "$args" =~ --scope[[:space:]=]+([^[:space:]]+) ]]     && scope="${BASH_REMATCH[1]}"
[[ "$args" =~ --purpose[[:space:]=]+([^[:space:]]+) ]]   && purpose="${BASH_REMATCH[1]}"
[[ "$args" =~ --return-of[[:space:]=]+([^[:space:]]+) ]] && return_of="${BASH_REMATCH[1]}"
[[ "$args" =~ --return[[:space:]=]+([^[:space:]]+) ]]    && return_id="${BASH_REMATCH[1]}"
# The [[:space:]=]+ separator makes the --return pattern reject --return-of
# ('-of' is neither whitespace nor '='), so the two never collide. Each flag
# also accepts the --flag=value form.
```

If `$ARGUMENTS` is empty, the slash command falls through to description-match handling — the trigger phrase context drives scope/purpose resolution per §3.5. If both `$ARGUMENTS` is empty AND no trigger phrase context is available (rare; the slash command was invoked from a fresh session with no preceding conversation), prompt for both per §3.3 + §3.5.

Per-arg validation:

- Unknown `--scope` value → one-line error naming the rejected value AND the accepted enum (per §3.3); stop.
- Unknown flag (e.g., `--ttl`, `--priority`) → silent skip (the `*) shift ;;` branch). Future flags can be added in v0.2 without breaking v0.1 callers.
- `--return` AND `--return-of` both present → one-line error: `--return and --return-of are mutually exclusive; pick one`. Stop.

---

## 11. Final assistant message

After durable writes, emit a final assistant message with these load-bearing components:

1. **Absolute path of the written file.** Always an absolute path, never a tilde-abbreviated or relative path — the next session may open from a different cwd and needs an unambiguous reference. Render as a code-formatted block: `<abs-path>`.
2. **The opening prompt for the next session** (copy-paste form): *"Read the handoff at `<abs-path>` and proceed"*. For forward handoffs expecting a return, extend with: *"; on completion, write the return handoff at `<abs-path with -return.md suffix>`"*. The receiving-session prompt is the master-HANDOFF pattern (see `docs/HANDOFF-scaffold-dev-build.md`'s closing block as the worked example).
3. **Scenario-specific framing.** Per the eval's per-scenario assertions:
   - **Sprint-boundary carry-forward (S1):** name the carry-forward semantics — "this handoff survives sprint-N close per §6b.6 cleanup" or "carry-forward to sprint-(N+1) bootstrap" — so the user knows it won't be swept by the next sprint-close cleanup.
   - **Mid-slice bug-fix forward (S2):** name the expected return-filename pattern so the fork session knows where to write its return: "the fork session writes its return at `<abs-path with -return.md suffix>`".
   - **Return handoff (S3):** reference the §6b.4 chain model — "main session C should read both the forward (`<forward-abs-path>`) and this return to resume; this completes the A→B→C chain".
   - **Mid-slice context bloat (S4):** instruct the user to open the new session by reading the §7 must-read files first, before anything else.
   - **First-invocation `mkdir -p` (S5):** name the newly created `.workspace/handoffs/` directory in the message; second invocation surfaces no mkdir mention (it was a no-op skip).
4. **Gitignore warning (only if §9 found the pattern missing).** Surface the warning verbatim per §9 outcome 2.

Under `--ephemeral`, skip the durable-path message above: print only the resolved handoff text (`safe_markdown`) and no "written file" path or return-file path claim.

Do NOT close the message with a self-congratulatory boilerplate ("Handoff composed successfully!"). The bar is content, not affirmation — the path + the opening prompt + the framing are sufficient.

---

## 12. Anti-patterns (do not do these)

- **Writing the file with an empty section 4.** The section-4 non-empty invariant is the eval's binding cross-scenario green-light criterion. An empty heading, `TBD`, `(none)`, `n/a`, or any single-token placeholder is a FAIL. If you cannot auto-extract candidates AND cannot prompt-and-wait for the user, the only correct action is to stop before writing — never write a placeholder.
- **Writing the file with an empty section 9 (Next intended action(s)).** Same discipline as section 4. Concrete actionable cursor required. (Sections 8 References and 10 Suggested-skills, by contrast, MAY be empty — heading present — when none apply.)
- **Writing or printing before the redaction pass resolves.** The §8.1 pass runs in BOTH modes before anything lands. Never emit a doc while a real secret/PII finding is unresolved; never add a blanket `--no-redact` bypass (per-finding `keep-this-one` is the only escape hatch).
- **Persisting an `--ephemeral` handoff.** Ephemeral is stdout-only: no file write, no `.workspace/handoffs/` touch, no gitignore check. Writing a file in ephemeral mode defeats its whole purpose (a prompt without a durable artifact).
- **Including a timestamp in the filename.** §6b.1 + the cross-scenario filename regex `^[a-z0-9.-]+-[a-z0-9-]+-[0-9a-f]{4}\.md$` explicitly excludes timestamps; the 4-char hex short-id IS the uniqueness mechanism. Filenames like `vs-1.1.1-bugfix-auth-20260525-a1b2.md` are FAIL.
- **Using a short-id with anything other than exactly 4 lowercase hex characters.** Not 3, not 5, not 8; not uppercase; not non-hex characters. Eval's judge regex is strict.
- **Generating a new short-id for a return handoff.** Return handoffs reuse the source forward's short-id per §3.4 + §6b.4 chain model. Eval S3 explicitly verifies the return file's short-id equals the forward's.
- **Running `mkdir -p` on the second invocation when the subdir already exists.** Eval S5 verifies skip-on-present is binding for back-to-back invocations.
- **Editing `.gitignore`** (via Write, Edit, `sed -i`, `git add` of a modified `.gitignore`, or any other mutation path). The skill's contract with `.gitignore` is READ-ONLY per §9. Auto-editing would create a write-conflict with workspace-init's §8.3 lane.
- **Skipping the gitignore exit-check.** The Read of `.gitignore` AFTER the file Write AND BEFORE the final assistant message is binding across all 5 eval scenarios. Skipping it is a FAIL even if the pattern is in fact present.
- **Reading `.gitignore` via `cat` in Bash instead of the Read tool.** The judge keys off Read tool-call entries; a Bash `cat .gitignore` doesn't satisfy the exit-check assertion.
- **Auto-committing the handoff file.** The storage path is gitignored by design (per §6b.1 + workspace-init §8.3). The skill never runs `git add` or `git commit` against the handoff file or any other file. The handoff is durable per-machine, not synced.
- **Deleting peer handoffs.** Cleanup is `closing-vertical-slice` (§15.2) + sprint-close (§6b.6) territory. Eval S5 explicitly verifies the second sub-run does not delete the first sub-run's file. The skill writes one file per invocation and that's it.
- **Renaming, mutating, or amending the source forward handoff when composing a return.** Returns are siblings, not amendments. Eval S3 verifies the original forward file is UNCHANGED on disk after the return is composed.
- **Invoking yourself from inside the `scaffold-dev:implementer-agent` subagent.** Per SPEC §6b.7 subagent boundary rule, the implementer-agent must never compose session handoffs. If you find yourself reading this body from a subagent context, refuse per §2 and surface the §6b.7 reference.
- **Dispatching subagents via the `Task` tool.** The skill is a one-shot composer, not an orchestrator. No subagent dispatch belongs here. If a sub-task surfaces (e.g., user wants the next session pre-briefed via a subagent), surface that as a section-9 (Next intended action) candidate, not via Task dispatch from inside this body.
- **Inventing scope or purpose values silently.** When `--scope` or `--purpose` is missing AND conversation context doesn't resolve them, prompt the user with the concrete questions in §3.5; don't pick defaults like `--scope sprint` or `--purpose handoff` and hope they're right.
- **Letting this body exceed 500 lines.** Hard cap per superpowers:writing-skills Pass D guidance.

---

## 13. Notes on the chain model + lifecycle

- **§6b.4 chain model.** Sessions don't "rejoin" — A writes forward, B reads forward and writes return, C reads both and resumes. The forward + return pair is identified by shared short-id; the chain is a three-node sequence mediated by markdown files, not a parent-child tree. Your job is to author one node of the chain per invocation (the forward in S1/S2/S4/S5; the return in S3); the user-side discipline of opening fresh sessions and reading the right doc is what stitches the chain together.
- **§6b.6 lifecycle.** Handoffs accumulate per sprint. Sprint-close cleanup (owned by `closing-vertical-slice` at the final slice of the sprint, per v0.1 cleanup ownership) wipes all sprint-scope handoffs EXCEPT the carry-forward `sprint-N-to-N+1-handoff-XXXX.md` — that one survives so sprint-(N+1) can bootstrap from it. Your job is to NAME the carry-forward per the §6b.1 pattern (the eval's S1 keys off `sprint-3-to-4-handoff-` literal scope+purpose prefix); the sweep that filters it from the cleanup is downstream.
- **§15.2 harvest sweep.** `closing-vertical-slice` sweeps slice-scoped handoffs (`vs-N.M.K-*.md`) at slice-close and surfaces section-4 promote-candidates for memory-bank promotion, source-tagged `[handoff]` (vs. `[report]` for work-item reports). Your job ends at *authoring* section 4 with substantive content; what slice-close does with it later is downstream and not exercised in this eval.
- **§6b.7 subagent boundary.** The implementer-agent subagent must never invoke this skill. The skill body's §2 "do NOT auto-invoke" block names this rule, and the eval doc references it as out-of-scope for `evals/handing-off-session.md` (the boundary is enforced upstream via the implementer-agent's tool restrictions per §6.1).
- **§6b.8 deferrals.** Four known limitations are deferred to v0.2+: in-flight subagent quiesce, multiple parallel detours from the same source, the 35%-context-threshold passive-hint hook, and the carry-forward naming convention finalization. v0.1 treats handoff invocation as user-judgment-driven; the passive hint is not implemented; concurrency semantics are not designed for parallel detours.

When in doubt, prefer composing-and-surfacing over silent invention. A handoff is a deliberate ceremony — the user-prompts in §6 and §7 are the correct interaction shape, not friction to optimize away. The 12-section invariant + the `Next-session focus` field + the filename pattern + the gitignore read-only contract + the section-4 non-empty discipline + the redaction pass together make the handoff parser-friendly, durable, safe, and aligned with the §6b.4 chain model; cutting any of them corrupts the value the escape valve was designed to deliver.
