# HANDOFF — scaffold-dev v0.1 build kickoff

> **For the receiving session:** Read this entire doc; then read `docs/PLAN-scaffold-dev.md`; then invoke `superpowers:subagent-driven-development` to start executing the PLAN task-by-task. Do NOT skip phases or parallel-dispatch implementer subagents.

## 1. Header

| Field | Value |
|---|---|
| Handoff type | Forward (no return expected — this is build kickoff, not a detour) |
| Scope | build-bootstrap (fresh scaffold-dev v0.1 build; not slice/sprint) |
| Source session | "master-session" 2026-05-25 — completed Phase 3 cross-check + PLAN authoring |
| Composed | 2026-05-25 |
| Project | `claude-agent-scaffolding` marketplace |
| Branch | `main` |
| Canonical source-of-truth | `docs/PLAN-scaffold-dev.md` (just authored; 1567 lines, 47 tasks across 10 phases) |

## 2. Purpose

The master session was driving SPEC → cross-check → PLAN authoring across the full plugin lineup. After Phase 3 cross-check completed clean and `PLAN-scaffold-dev.md` was authored (1567 lines + comprehensive self-review), continuing the build in the same session would bloat the orchestrator context for ~16-23 days of execution work. This handoff transfers execution to a fresh session that has the locked PLAN as its single source of truth and zero ballast from design conversations.

## 3. State pointers

**Repo:** `/Volumes/master_ssd/projects/claude-agent-scaffolding/` (single-repo marketplace; NOT a workspace-init'd dual-repo — this is the canonical marketplace repo)

**Branch:** `main` (clean after this handoff's setup commit)

**Shipped dependencies (all installed via `/plugin update <name>`; verify with `ls ~/.claude/plugins/cache/*/<name>/`):**

| Plugin | Version | Role for scaffold-dev |
|---|---|---|
| workspace-init | 0.1.0 | Manifest contract + `.workspace/handoffs/` gitignore |
| scaffold-onboard | 0.2.0 | R1 ROADMAP + R2 mcrule blocks + R3 auto:/user: demo grammar; lib/*.sh patterns to mirror |
| architect-critic | 0.2.0 | `critiquing-spec` skill (filesystem probe); `lib/codex.sh` portable-timeout pattern to copy |
| ai-mentor | 2.0.0 | `grill-me` skill (offered at 3 gates) |
| claude-security-audit | 0.1.1 | Standalone — not a dep, but in marketplace lineup |

**No `.workspace/` or `.workspace/handoffs/` exists in this repo.** scaffold-dev v0.1 will be developed inside this marketplace repo directly (single-repo). The `.workspace/handoffs/` pattern is what scaffold-dev BUILDS for users of scaffold-dev — not used by scaffold-dev's own development.

## 4. What's NOT in PLAN (ephemeral pre-codification context)

The PLAN is comprehensive. These are the few items worth knowing that wouldn't be obvious from reading the PLAN alone:

- **`scaffold-onboard/lib/*.sh` is the bash style reference.** scaffold-onboard v0.2 just shipped (392 tests across 12 suites). Its `lib/_helpers.sh`, `lib/state.sh`, `lib/compose.sh`, `lib/render.sh` patterns are the model — match the function-naming (`sf_*` → `sd_*`), error-handling, logging, and atomic-write style.
- **`architect-critic/lib/codex.sh:96-141` is the portable-timeout reference.** scaffold-dev's lib needs portable bash bg+kill pattern (no GNU `timeout`); copy this proven pattern.
- **Phase 3.5 subagent registration schema (`agents.json`) is provisional.** Claude Code's actual subagent_type registration format may differ from what the PLAN sketches. Task T3.5.1 explicitly says "verify against Claude Code docs at implementation time." If the format is different, adjust file name + schema; the conceptual content (skill body as system prompt, tool restrictions, no nesting) is what matters.
- **`feedback_subagent_vs_inline_threshold` memory applies to Phase 6.** If subagent dispatches fail reliably during pressure tests, pivot to inline reasoning-pass (matches scaffold-onboard's Phase 6 precedent of consolidated reasoning-pass).
- **Effort estimate is wider than SPEC §19 stated.** SPEC says 8-12 days; PLAN's phase sums to 16-23 days. Treat 8-12 as floor, 16-23 as ceiling. Actual pace depends on subagent reliability in Phase 6.
- **Dogfood opportunity:** scaffold-dev's `handing-off-session` skill (built in Phase 1 Task T1.5) will be the first real-world use of the §6b handoff escape valve we just designed. After it lands, future sessions can use it for slice/sprint transitions. This handoff doc you're reading right now is a hand-rolled prototype of that pattern — same 10-section structure per SPEC §6b.5.

## 5. Workflow deviations

- **Single-repo development**, not dual-repo workspace-init'd. This is the marketplace repo developing one of its own plugins. The `.workspace/handoffs/` pattern doesn't apply to scaffold-dev's *own* development; it applies to scaffold-dev's *users*.
- **Subagent-driven-development execution path locked.** Per the writing-plans skill exit choice, this PLAN executes via `superpowers:subagent-driven-development` (fresh subagent per task; two-stage review per task: spec compliance then code quality). Inline execution path was considered + rejected.
- **No worktrees needed.** scaffold-dev v0.1 is being built in `main` directly with phase-close commits. No feature-branch worktree pattern for this build (that pattern is what scaffold-dev BUILDS, not how scaffold-dev is BUILT).
- **Phase-close commit message format** matches the scaffold-onboard v0.2 convention: `scaffold-dev: <description> (v0.1 Phase X T<task>)` — single line, no HEREDOC, no `Co-Authored-By` trailer (per the trace-filter discipline applied to this marketplace's own commits).

## 6. In-flight state

| Item | State |
|---|---|
| Working tree | Clean after this handoff's setup commit (PLAN + this handoff + 4 backfill SPECs committed together) |
| Active subagents | None |
| Active worktrees | None (single-repo development; no worktree pattern for scaffold-dev's own build) |
| Open PRs / branches | None (`main` is the only branch) |
| Active sprint/slice | None (scaffold-dev's *own* development doesn't run through sprint-slice machinery — that's what scaffold-dev BUILDS for end-users) |
| Pending uncommitted edits | None — handoff session commits everything before exiting |

## 7. Must-read before doing anything

Read in this order:

1. **`docs/PLAN-scaffold-dev.md`** — the canonical execution plan. 1567 lines, 47 tasks across 10 phases (0, 1, 2, 3, 3.5, 4, 5, 6, 7, 8). All decisions locked.
2. **`docs/SPEC-scaffold-dev.md`** — the SPEC the PLAN concretizes. Use as reference when PLAN tasks refer to SPEC sections (e.g., "per SPEC §6.3 multi-call protocol").
3. **`scaffold-onboard/lib/_helpers.sh`** — bash style + helper-API reference. `scaffold-dev/lib/*.sh` should mirror this style.
4. **`scaffold-onboard/lib/compose.sh`** — composition probe pattern (especially `sf_compose_detect_architect_critic` — the filesystem probe that scaffold-dev's `lib/compose.sh` will adapt).
5. **`scaffold-onboard/lib/render.sh`** — `{{var}}` template substitution; scaffold-dev's `lib/render.sh` ports this pattern.
6. **`architect-critic/lib/codex.sh`** — read lines 50 (`_AC_LIB_DIR` pattern, proven resilient per issue #3) + 96-141 (portable bash timeout) — scaffold-dev's libs should follow the same patterns.

Do NOT read:
- Other plugin SPECs / PLANs / handoffs (out of scope — context bloat)
- `.claude/ghost-notes.md` / `manifest-transcript.md` (already folded into ai-mentor v2.0)
- The full chain of brainstorm artifacts (already settled in PLAN)

## 8. Next intended actions

**Single specific opening action:**

1. Invoke `superpowers:subagent-driven-development` skill (per the writing-plans exit choice that locked this path).
2. Use that skill to extract Phase 0 tasks (T0.1 through T0.6) from `docs/PLAN-scaffold-dev.md` into TodoWrite.
3. Dispatch Phase 0 T0.1 (`evals/planning-vertical-slice.md`) as the FIRST implementer subagent task.

**Subsequent actions (locked by PLAN):**

4. Execute Phase 0 completely (6 eval doc tasks).
5. Advance to Phase 1 (8 SKILL.md author tasks).
6. Continue through Phases 2 → 3 → 3.5 → 4 → 5 → 6 → 7 → 8 strictly in PLAN order.
7. Use `superpowers:finishing-a-development-branch` after Phase 8 to wrap up.

**Per-task discipline (per `superpowers:subagent-driven-development`):**

- Fresh implementer subagent per task (no context inheritance)
- Two-stage review per task: spec compliance reviewer → code quality reviewer
- Mark task complete in TodoWrite ONLY after both reviewers approve
- Continuous execution — do NOT pause to check in with user between tasks unless BLOCKED

## 9. Anti-actions (do NOT do)

- ❌ **Do NOT skip phases.** PLAN ordering is enforced; each phase produces a green test suite before advancing.
- ❌ **Do NOT parallel-dispatch implementer subagents.** They conflict on the same working tree. Sequential only.
- ❌ **Do NOT add scope beyond what the PLAN says.** If a SPEC section seems to require something not in PLAN, surface it as a deviation; don't silently add.
- ❌ **Do NOT commit on user's behalf without checking** when uncertain. Phase-close commits with the documented message format are pre-authorized; major decisions or scope changes need user touch.
- ❌ **Do NOT re-author PLAN or SPEC.** Both are locked. If a fundamental issue surfaces, escalate to user (BLOCKED status).
- ❌ **Do NOT pause to check in with user between tasks.** Per the `subagent-driven-development` skill: "Execute all tasks from the plan without stopping. The only reasons to stop are: BLOCKED status you cannot resolve, ambiguity that genuinely prevents progress, or all tasks complete."
- ❌ **Do NOT install other plugins or modify shipped plugins.** All 5 deps are shipped. Do NOT touch `architect-critic/`, `ai-mentor/`, `scaffold-onboard/`, `workspace-init/`, `claude-security-audit/` — only build inside `scaffold-dev/`.
- ❌ **Do NOT force-push, rebase main, or use `--no-verify`.** Standard project git discipline applies.

## 10. Return-handoff template stub

If the build completes successfully, compose a return handoff matching this template:

```markdown
# RETURN HANDOFF — scaffold-dev v0.1 build complete

## Summary
- All 10 phases (0, 1, 2, 3, 3.5, 4, 5, 6, 7, 8) executed
- ~140-160 tests passing (actual: <count>)
- `scaffold-dev-v0.1.0` tag pushed
- Marketplace updated; `/plugin update scaffold-dev` installs cleanly

## Deferrals (if any)
- <items deferred to v0.2; reason>

## Cautions / warnings for next session
- <surprises encountered during build; pattern fixes worth promoting to memory bank>

## Memory bank promotion candidates
- <items that should be promoted via /promote-principle or memory-bank harvest>
```

If the build pauses mid-way (e.g., context bloated even in fresh session, blocker hit, scope question surfaced), compose a partial return handoff:

```markdown
# PARTIAL RETURN HANDOFF — scaffold-dev v0.1 build paused at <Phase N Task TX.Y>

## Phases complete
- <list>

## Phase in flight
- <Phase X Task TY.Z>: <state>

## Why paused
- <reason>

## Next steps for resumption session
- <specific actions>
```

Save the return handoff at `docs/HANDOFF-scaffold-dev-build-RETURN.md` (or `-PAUSE.md` for partial).

---

## Opening prompt for the new session (copy-paste this)

```
Read the handoff at docs/HANDOFF-scaffold-dev-build.md, then read docs/PLAN-scaffold-dev.md. Invoke superpowers:subagent-driven-development to execute the PLAN. Start with Phase 0 Task T0.1.
```
