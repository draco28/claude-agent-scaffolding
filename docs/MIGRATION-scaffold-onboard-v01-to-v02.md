# Migration: scaffold-onboard v0.1.0 → v0.2.0

> Released 2026-05-24. Companion to `scaffold-onboard/CHANGELOG.md` `[0.2.0]` entry and `docs/SPEC-scaffold-onboard-v02.md`.

This document covers what's new in v0.2.0, what changed for existing v0.1.0 users, how to opt into the new R1/R2/R3 contracts, what breaks (only one breaking change — an IPC contract internal to architect-critic composition), the test-baseline delta, and the cross-plugin coordination items still open.

---

## 1. What's new

v0.2.0 is a **skill-first retrofit** of the v0.1.0 onboarding plugin plus three new authoring contracts consumed by scaffold-dev v0.1+.

### 1.1 Seven SKILL.md surfaces

The plugin now ships **7 auto-invocable skills** under `scaffold-onboard/skills/<name>/SKILL.md`. Each is ≤500 lines and triggers on natural-language phrases per its description matcher:

| Skill | Trigger summary |
|---|---|
| `onboarding-project` | "onboard this project", "run the 10-phase interview", "/onboard" |
| `scaffolding-memory-bank` | "scaffold the memory bank", "derive the 11-file memory bank", "/scaffold-project" |
| `scaffolding-governance-docs` | "scaffold governance docs", "/scaffold-docs", optionally `--full` (5 default / 14 full) |
| `planning-project-roadmap` (NEW) | "plan the roadmap", "Phase → Sprint → Vertical Slice hierarchy", "/plan-roadmap" |
| `authoring-machine-checkable-rules` (NEW) | "add a project rule", "write an mcrule", "forbid X in Y" |
| `authoring-vertical-slice-demo` (NEW) | "author demo criteria", "add an auto: / user: criterion" |
| `validating-master-spec` | "validate MASTER-SPEC", `sf_spec_validate` |

Slash commands (`/onboard`, `/scaffold-project`, `/scaffold-docs`, `/plan-roadmap`) become thin Skill-tool dispatchers via the `$ARGUMENTS` env-var bridge per the slash-command substitution bug feedback.

### 1.2 R1 — Phase → Sprint → Vertical Slice roadmap

`/plan-roadmap` (new command) drives the `planning-project-roadmap` skill to author a `ROADMAP.md` at the project root. The hierarchy is **Phase → Sprint → Vertical Slice (VS)**, each VS owning its own demo criteria block. State lives at `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` with schema versioning + a mutations array (5 re-run modes: continue / extend / split / reduce / replace).

Size-class behaviour: `>50` nodes triggers a `continue / split / reduce` 3-path prompt; `>100` biases toward `split`. Time-budget is advisory at 60 min, warn-only at 90 min — no hard timeout.

`ROADMAP.md` does **NOT** collide with v0.1.0's `PROJECT_PLAN.md` (a Phase-2-derived timeline emitted by `/scaffold-docs`). Both files can coexist. Per SPEC §13.5, the new R1 hierarchy is named `ROADMAP.md` precisely so v0.1.0 users are unaffected.

### 1.3 R2 — machine-checkable rules DSL

`authoring-machine-checkable-rules` skill + `lib/rules.sh` provide an HTML-sentinel rule grammar that lives inside `.claude/memory-bank/03-code-patterns.md` under a `## Machine-checkable rules` section. Four v0.2 rule types ship: `banned_imports`, `coverage_floor`, `style_invariants`, `required_pattern`. Unknown forward-compat types **warn-and-skip** per SPEC §8.5.

Rule format (HTML-sentinel comments, NEVER fenced code blocks):

```markdown
<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3, httpx.Client]
<!-- mcrule:end -->
```

### 1.4 R3 — `auto:` / `user:` demo-criteria grammar

`authoring-vertical-slice-demo` skill + `lib/demo-criteria.sh` provide the `auto:` (machine-runnable) and `user:` (human-confirmable) criterion grammar consumed by scaffold-dev's `closing-vertical-slice` skill. Literal U+2192 arrow (→) is used as the criterion → expected separator — NEVER the ASCII `->`. Dual storage target: state-file during R1.C authoring, markdown post-R1.C close.

### 1.5 Manifest-aware output routing

`lib/routing.sh` exposes `sf_resolve_output_path` to route outputs to ai_workspace vs. canonical per workspace-init's `pairing.json` `routing.*` table. Cross-plugin sourcing of `mi_manifest_resolve` with local fallback; single-repo fallback preserved. Forward-compatible with v0.1 workspace-init manifests that don't yet carry a `routing.roadmap` key (defaults to canonical).

### 1.6 Tier 0 marker protocol

`hooks-handlers/session-start.sh` extended with a marker file at `${TMPDIR}/claude-code-tier0-${CLAUDE_SESSION_ID}` (first-write-wins) so scaffold-dev's session-start hook can detect whether scaffold-onboard already ran in this session and skip its own initialisation. Measured ~2.5ms typical against a 50ms budget.

### 1.7 Karpathy behavioral discipline opt-in

CLAUDE.md template now offers an optional **Behavioral Discipline** section (4 principles) gated by the Phase 10.4 answer `state.answers["phase_10.4.include_karpathy"]`. Attribution is verbatim: `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)`.

### 1.8 New supporting libs + tests

- New libs: `lib/roadmap.sh`, `lib/rules.sh`, `lib/demo-criteria.sh`, `lib/routing.sh`
- New test suites: `test-roadmap.sh` (34), `test-rules.sh` (30), `test-demo-criteria.sh` (27), `test-manifest-routing.sh` (14), `test-hook-marker.sh` (12)

---

## 2. What changed for v0.1.0 users

**Essentially nothing — unless you opt into the new commands.**

- `/onboard` still drives the same 10-phase guided conversation. Behaviour is preserved byte-identical for users who don't invoke the new skills.
- `/scaffold-project` still derives the 11-file memory bank + CLAUDE.md from a closed MASTER-SPEC.md. The only structural change is the new `## Machine-checkable rules` section heading seeded **empty** into the `03-code-patterns.md` template. This is purely additive.
- `/scaffold-docs` still emits the 5 default / 14 `--full` governance docs unchanged. `PROJECT_PLAN.md` (Phase-2-derived timeline) is preserved and does NOT collide with the new `ROADMAP.md`.
- `state.json` schema is forward-compatible: v0.1.0 state files load cleanly in v0.2.0 without migration.

If you upgrade scaffold-onboard from v0.1.0 → v0.2.0 and do nothing else, your existing project will see no behaviour change beyond the empty `## Machine-checkable rules` section heading being added the next time you re-run `/scaffold-project --force`.

---

## 3. How to opt into R1 / R2 / R3

These are the three new authoring contracts. All three are optional — they extend v0.1.0, they don't replace it.

### 3.1 Opt into R1 (Phase → Sprint → Vertical Slice roadmap)

1. Close MASTER-SPEC.md via `/onboard` (Phase 10) if you haven't already.
2. Run `/plan-roadmap` (or trigger the `planning-project-roadmap` skill conversationally — "let's plan the project roadmap").
3. Walk through R1.A (Phase authoring), R1.B (Sprint authoring per phase), R1.C (Vertical Slice authoring per sprint with demo criteria).
4. On R1.C close, `ROADMAP.md` lands at the project root (or ai_workspace per manifest routing).
5. Re-run with mode flags (`--continue`, `--extend`, `--split`, `--reduce`, `--replace`) to evolve the roadmap incrementally.

See `scaffold-onboard/examples/sample-project/ROADMAP.md` for a fully-worked 4-phase × 2-sprint × 2-3-slice example.

### 3.2 Opt into R2 (machine-checkable rules)

1. Confirm `.claude/memory-bank/03-code-patterns.md` exists (run `/scaffold-project` first if not).
2. Either:
   - Run the `authoring-machine-checkable-rules` skill conversationally ("add a project rule that forbids `requests` in async paths"), which validates each block via `sf_rules_validate_block` before append; OR
   - Hand-author the HTML-sentinel block directly under `## Machine-checkable rules`. Reference: `scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md` §5 for grammar.
3. scaffold-dev v0.1+ `implementation-checking` skill picks up the rules on the next slice close.

See `scaffold-onboard/examples/sample-project/.claude/memory-bank/03-code-patterns.md` for example blocks demonstrating all four rule types.

### 3.3 Opt into R3 (`auto:` / `user:` demo criteria)

Demo criteria are authored as part of R1.C (per-slice during `/plan-roadmap`). If you've already run R1, your slices already carry R3 criteria.

To add criteria to slices authored before R1, run `authoring-vertical-slice-demo` conversationally ("add demo criteria to slice VS-1.2.1"). The skill appends to the slice block in `ROADMAP.md` idempotently.

Grammar — note the **literal U+2192 arrow**, NOT the ASCII `->`:

```markdown
- [ ] auto: `pulsepipe db init && pulsepipe db status` → expected: exit code 0, prints `schema: 4 tables`
- [ ] user: open a fresh shell and run `pulsepipe db init` → expected: directory created, no errors
```

---

## 4. Breaking changes

There is **one** breaking change and it only affects users who scripted directly against scaffold-onboard's IPC contract with architect-critic v0.1.x.

### 4.1 Removed: file-IPC critic handshake

The following are removed in v0.2.0:

- `sf_compose_build_critic_request` function from `lib/compose.sh` (was lines 257-339 in v0.1.0)
- `sf_compose_read_critic_response` function from `lib/compose.sh` (was lines 344-363 in v0.1.0)
- `inbox/outbox` file-IPC paths under `${CLAUDE_PLUGIN_DATA}/architect-critic/` — no longer created or used
- 15 IPC-specific tests from `test-compose.sh` (v0.1.0: 31 → v0.2.0: 24, with +8 new tests for filesystem-probe detection + skill-marker assertions)

**Why:** v0.2 architect-critic settled on **in-conversation skill invocation** rather than file IPC (per architect-critic v0.2 settlement #1 and SPEC §12.2). scaffold-onboard now invokes `Skill(architect-critic:critiquing-spec)` directly at critic moments (Phase 5, Phase 7, MASTER-SPEC close, `/plan-roadmap` close).

**Who's affected:** Only users who built tooling on top of the v0.1.0 inbox/outbox files or called `sf_compose_build_critic_request` from external scripts. End users running `/onboard` see no change in behaviour beyond critic review flowing through skill invocation instead of file IPC.

**Migration:** Install **architect-critic v0.2+** alongside scaffold-onboard v0.2+. The two are paired-release per SPEC §12.4. If architect-critic is absent or pinned at v0.1.x, scaffold-onboard logs an `absent` warning at critic moments and continues — critic review is skipped, but nothing else breaks. Composition detection is now BINARY (v0.2-present-or-absent); there is **no v0.1.3 fallback path**.

### 4.2 composition.json shape change (internal)

`lib/compose.sh` no longer caches a `plugins.architect-critic` entry in `composition.json`. ai-mentor + superpowers probe entries are unchanged. This is internal — no public surface depends on the removed entry.

---

## 5. Test baseline

| Version | Test count | Suites |
|---|---|---|
| v0.1.0 | 163 | 7 (state 23, parser 13, render 10, memory-bank 22, docs 23, compose 31, e2e 41) |
| v0.2.0 | 392 | 12 |

**Delta:**
- 148 of 163 v0.1.0 tests preserved **byte-identical** (no behaviour drift in carried-over surfaces)
- 15 IPC-specific tests dropped from `test-compose.sh` (now 24 tests, with +8 new filesystem-probe + skill-marker assertions)
- 244 net new tests across the 12 suites covering the 7 skills + R1/R2/R3 + manifest routing + Tier 0 marker

Run locally:

```bash
cd scaffold-onboard
./tests/run-all.sh
```

---

## 6. Cross-plugin coordination — open items

These items must land in companion plugins before the full v0.2 contract is realised end-to-end. None of them block scaffold-onboard v0.2.0 shipping — they are cross-repo handoffs that v0.2 surfaces a need for.

### 6.1 scaffold-dev SPEC §16.2 reference update

scaffold-dev v0.1's SPEC §16.2 must reference `ROADMAP.md` (not `PROJECT_PLAN.md`) as the input to its slice-orchestrator. Handoff filed: `docs/SPEC-scaffold-dev.md` §16.2 update. Owner: scaffold-dev SPEC author. Tracking: cross-plugin handoff per SPEC §13.5.

### 6.2 workspace-init v0.1.1 manifest schema extension

workspace-init v0.1's `pairing.json` schema does not yet carry a `routing.roadmap` key. scaffold-onboard's `lib/routing.sh` defaults to canonical when the key is absent — forward-compatible — but workspace-init v0.1.1 should extend the schema so users can route `ROADMAP.md` to ai_workspace if desired. Owner: workspace-init author.

### 6.3 architect-critic v0.2+ install

Users running scaffold-onboard v0.2 with architect-critic v0.1.x will see `absent` warnings at critic moments. Recommend `/plugin install architect-critic@claude-agent-scaffolding` to pull v0.2.0+.

---

## 7. Where to read more

- `scaffold-onboard/CHANGELOG.md` `[0.2.0]` entry — concise change log
- `docs/SPEC-scaffold-onboard-v02.md` — full spec (24 sections, ~1300 lines)
- `docs/PLAN-scaffold-onboard-v02.md` — phase-by-phase implementation plan
- `scaffold-onboard/examples/sample-project/` — end-to-end demonstration of R1+R2+R3
- `scaffold-onboard/skills/<name>/SKILL.md` + `references/*.md` — per-skill documentation

For questions or bugs: file an issue on the marketplace repo.
