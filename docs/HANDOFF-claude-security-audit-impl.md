# Handoff: claude-security-audit plugin implementation

**Purpose:** seed a fresh Claude Code session to build the `claude-security-audit` plugin v0.1.0 end-to-end from the locked SPEC + PLAN. The previous session (2026-05-24) consumed `docs/HANDOFF-claude-security-audit-spec.md` and produced:

- `docs/SPEC-claude-security-audit.md` (1125 lines, 18 sections, 27 locked decisions D1–D27, architect-critic dogfooded with 12 Tier-1+2 challenges folded in)
- `docs/PLAN-claude-security-audit.md` (3095 lines, 33 tasks across 8 phases + status overview, TDD-shaped with full code blocks for foundation phases and structured guidance for later phases)
- GitHub issue [#3](https://github.com/draco28/claude-agent-scaffolding/issues/3) tracking 4 architect-critic v0.1.3 bugs encountered during the dogfood pass

The fresh session's job is **implementation only** — no design, no spec drift, no questioning the locked decisions. Execute the PLAN.

**Author:** carried over from the 2026-05-24 design session (grill-me settlement + SPEC authoring + architect-critic dogfood pass).

**Date written:** 2026-05-25.

---

## 1. Goal of the next session

Build `claude-security-audit/` as a new plugin in this marketplace, executing `docs/PLAN-claude-security-audit.md` Phase 0 through Phase 8, ending with the `claude-security-audit-v0.1.0` git tag.

Success criteria:

- All ~170 tests in `claude-security-audit/run-tests.sh` PASS.
- All 5 clean fixtures in `claude-security-audit/fixtures/clean/` produce ZERO findings (the release-gate metric per SPEC D17).
- All 8 issue fixtures produce the expected rule_id + severity per their intentional issues.
- Perf benchmark: full audit of a ~200-file workload completes in ≤10 seconds.
- `marketplace.json` + root `README.md` updated with new plugin entry.
- `claude-security-audit-v0.1.0` tag pushed (or held for user confirmation per project convention).

---

## 2. What's locked (consume these as immutable constraints)

### 2.1 Identity

- Plugin name: `claude-security-audit` (under `claude-security-audit/` at marketplace root)
- Version: `0.1.0` for this release
- License: MIT with ECC AgentShield attribution
- Branch: `implementation-claude-security-audit` (create from `main`)

### 2.2 Locked decisions (do not re-litigate)

All 27 decisions in SPEC §11 (D1–D27) are settled by the prior design session. Highlights the implementer should internalize before writing any code:

- **D1 + D20 — scope honesty.** v0.1 catches *common, unobfuscated patterns* only. Do not over-engineer rules to chase sophisticated adversaries — that's v0.2 AST scope. README and chat-summary footer of every report explicitly state this limitation. (T1-A reframe.)
- **D2 — zero ambient surface by default.** The plugin's `plugin.json` MUST NOT declare any hooks. The SessionStart reminder ships as `hooks/session-start-reminder.sh` but is opt-in via user's own settings.json snippet documented in README. (T1-C lock.)
- **D3 — meta-risk lock.** Static analysis only. No LLM-over-bytes. Findings redacted via `lib/redact.sh`. No subagent / codex dispatch on file content.
- **D6 + T2-H — two-flag auto-fix.** Every rule declares both `RULE_AUTO_FIXABLE` (target path in safe-write allowlist) AND `RULE_MECHANICALLY_FIXABLE` (fix derivable without judgment). Both must be true for `/apply-fix` to act. Defense-in-depth re-validation in `apply-fix.sh` (5 checks per SPEC §9.2).
- **D7 + D8 — output is chat + markdown in `.claude/audits/`.** First audit run bootstraps `.gitignore` per T1-D.
- **D9 + D22 — 5-tier severity** (Critical / High / Medium / Low / Info). **PERM-005 settings-schema-validation** is the single highest-value new rule per T1-E.
- **D10 — per-finding consent for auto-fix.** `/apply-fix <id>` accepts both `display_id` (per-report) and `finding_uid` (durable). No batch / interactive mode in v0.1.
- **D11 + D24 — finding lifecycle + tamper detection.** Both `baseline diff` and `suppression` ship; both share the durable `finding_uid` primitive. State.json self-integrity checks emit TAMPER-001/002/003 per T1-F.
- **D12 — suppressions gitignored per-developer; Critical-cannot-suppress.**
- **D13 + T2-J — enumerate-targets pinned algorithm in SPEC §6.3.** Includes local-dev fallback for marketplace operator dogfood use case.
- **D14 — edge cases per SPEC §13.** Symlinks not followed; gitignored files audited; missing `.claude/` succeeds with Info.
- **D17 — release-gate: zero findings on 5 clean fixtures.**
- **D18 — no runtime network fetch for rule freshness.** Plugin version bump only.
- **D21 — provenance aspect DEFERRED.** Do NOT create `lib/rules/provenance/` in v0.1. (T1-B.)
- **D25 — rule-load failure is High severity.** SCANNER-001 / SCANNER-002 with chat-summary banner per T2-G.
- **D26 — two-layer fingerprint.** `finding_uid` is durable (no line number); `dedup_fingerprint` is per-run only (includes line). Critical for stable IDs across whitespace edits.
- **D27 — state.json GC.** Evict `findings` registry entries not seen in last 10 runs.

### 2.3 Workflow conventions

- **TDD non-negotiable.** Red → green → refactor → commit. Every task in PLAN structures this explicitly. Use `superpowers:test-driven-development` if the rhythm slips.
- **Subagent-driven development.** Use `superpowers:subagent-driven-development`. One fresh subagent per PLAN task. Orchestrator reviews subagent output before dispatching next task.
- **`$ARGUMENTS` in slash commands.** Per `feedback_slash_command_dollar_n_bug` auto-memory — Claude Code substitutes `$1`/`$2`/etc. at template-render time. Use `$ARGUMENTS` env-var-bridge instead of positional bash. All 4 slash command bodies in PLAN Phase 5 already follow this.
- **macOS portability.** Target bash 3.2+. Use `lib/helpers.sh` wrappers for `sha256` (sha256sum vs shasum -a 256), `sed -i` (GNU vs BSD), `realpath` (with pure-bash fallback). No GNU `timeout`; use pure-bash `mkdir`-based lock or background-kill pattern.
- **Commit format.** Per task: `claude-security-audit: <description> (v0.1 Phase X)`. Single-line. No co-author trailer.
- **Phase-close commits update CHANGELOG + the Implementation Status table in PLAN.**

### 2.4 Reference material order

Read in this order:

1. **This document** — full briefing
2. **`docs/SPEC-claude-security-audit.md`** — locked design, 18 sections; refer back constantly for "why" and "what"
3. **`docs/PLAN-claude-security-audit.md`** — task-by-task implementation; the executable artifact
4. **`docs/HANDOFF-claude-security-audit-spec.md`** — historical context for the original design session (optional)
5. **Sibling plugin sources** for pattern references:
   - `architect-critic/lib/` — bash lib utilities layout, test harness convention, severity scoring pattern
   - `architect-critic/.claude-plugin/plugin.json` — manifest shape reference
   - `scaffold-onboard/` — skill-first composition examples
6. **GitHub issue [#3](https://github.com/draco28/claude-agent-scaffolding/issues/3)** — architect-critic v0.1.3 bugs encountered during dogfood. **If you intend to run `/critique` on the SPEC or PLAN again, check first whether issue #3 is resolved.** If not, use the working codex invocation from the previous session (`codex exec --output-schema FILE --output-last-message FILE` per the issue's recommended fix #3).
7. **Auto-memory files** (always loaded; relevant individual files):
   - `feedback_slash_command_dollar_n_bug.md`
   - `feedback_two_axis_skill_eval.md`
   - `project_skill_first_retrofit_queue.md`
   - `project_post_spec_exploration_queue.md`

---

## 3. First-session game plan

### Step 1 — Orient (15–20 min)

- Read this handoff end-to-end.
- Read SPEC §1 (TL;DR), §3 (Goals/non-goals), §4 (threat model), §11 (decisions). Skim the rest.
- Read PLAN's header + Implementation Status table + Phase 0 in full.
- Verify environment: `bash --version`, `jq --version`, `sha256sum || shasum -a 256`, `git --version`. (No Python or Node needed for v0.1.)

### Step 2 — Branch + scaffold (5 min)

```bash
git checkout main
git pull origin main
git checkout -b implementation-claude-security-audit
mkdir -p claude-security-audit
```

### Step 3 — Execute Phase 0 (eval fixtures + test harness)

Subagent-driven: dispatch one subagent per Task 0.1, 0.2, 0.3. Each subagent reads:
- This handoff
- SPEC §6.1 (manifest), §6.2 (directory layout), §14.3 (fixtures)
- PLAN Phase 0 task definition

Each subagent returns: code committed, test count delta, any blockers. Orchestrator validates before next task.

After Phase 0: `claude-security-audit/run-tests.sh` should report 3 files, 13 PASS, 0 FAIL.

### Step 4 — Execute Phases 1–7 (multi-session if needed)

Phases 1, 5, 6 are smaller — single subagent per task suffices.
Phases 2, 3 are foundation-heavy — each task gets a dedicated subagent; foundation libs are read by every later task, so getting them right matters most.
Phase 4 (rules) is repetitive — pattern is established by Task 4.1; Tasks 4.2–4.7 are faster.
Phase 7 (e2e) requires the full stack — dispatch only after Phases 0–6 are green.

After Phase 7: ~170 tests PASS, perf benchmark green.

### Step 5 — Execute Phase 8 (dogfood + release)

- Task 8.1: optionally invoke `/critique` if issue #3 fixed; else use direct codex per the workaround.
- Task 8.2: update marketplace.json + root README.
- Task 8.3: finalize CHANGELOG, commit, tag `claude-security-audit-v0.1.0`. **Hold the push until user confirms** (per project convention; tag-push is a published-state operation).

---

## 4. Workflow gotchas (lessons from prior sessions in this marketplace)

These are not in the SPEC because they're cross-plugin process knowledge:

1. **`/plugin update` is version-keyed** — any content change requires a plugin.json version bump (per `feedback_plugin_version_bump_required`). For v0.1.0 → v0.1.1 patch releases, bump version even for trivial changes.
2. **architect-critic v0.1.3 has known bugs** — see GitHub issue #3. Workaround for direct codex invocation:
   ```bash
   codex exec --skip-git-repo-check --output-schema <schema.json> --output-last-message <out.json> < <prompt.txt>
   ```
3. **Subagent socket failures** — per `feedback_subagent_vs_inline_threshold`, if subagent dispatch reliably fails in this session (socket close, stream timeout, runaway runtime), pivot to inline execution. Don't burn time on retry overhead.
4. **Brainstorm artifacts** — if any unanticipated design question surfaces during implementation, default to prose-only conversational settlement (per `feedback_brainstorm_artifacts_only_when_visual`). Do not generate HTML artifacts unless the question is genuinely visual.
5. **macOS shell idiosyncrasies** — `find -regex` alternation order matters (longest first); `sed -i` requires `''` after the flag on BSD; `date -d` doesn't exist (use `-j -f` BSD form). `lib/helpers.sh` wraps these.

---

## 5. Definition of done (claude-security-audit v0.1.0)

- All 8 build phases complete; Implementation Status table in PLAN reflects 100% complete with commit SHAs recorded
- ~170 tests PASS (zero failures, zero skipped)
- Release-gate met: 5 clean fixtures produce zero findings
- 8 issue fixtures each produce expected rule_id + severity
- Perf budget met: ≤10 seconds for ~200-file workload
- Phase 8 dogfood pass complete (0–2 conceded challenges from architect-critic, folded inline)
- `marketplace.json` + root `README.md` updated with `claude-security-audit` entry alphabetically between `architect-critic` and the next sibling
- `claude-security-audit-v0.1.0` tag created (push pending user confirmation)
- CHANGELOG.md has a v0.1.0 (2026-MM-DD) release entry with the summary line
- README documents ECC attribution + scope-honesty caveats + opt-in hook registration snippet
- No SessionStart hook declared in `plugin.json` (T1-C invariant)
- `lib/rules/provenance/` does NOT exist in v0.1 (T1-B / D21 invariant)

---

## 6. Opening message for the new session

To start the fresh session, paste this:

> Read `docs/HANDOFF-claude-security-audit-impl.md` end-to-end, then `docs/SPEC-claude-security-audit.md` §1/§3/§4/§11, then `docs/PLAN-claude-security-audit.md` header + Implementation Status table + Phase 0. This is the implementation session for `claude-security-audit` v0.1.0 — a new MIT-licensed plugin in our marketplace, inspired by ECC's AgentShield. All design is locked (27 decisions D1–D27); no spec drift, no re-litigation. Branch off `main` as `implementation-claude-security-audit`. Execute the PLAN's 33 tasks across 8 phases via `superpowers:subagent-driven-development` with TDD discipline per task. Phase 0 first (eval fixtures + test harness); phase-close commits update CHANGELOG + Implementation Status. Final release: `claude-security-audit-v0.1.0` tag (hold push until I confirm).
