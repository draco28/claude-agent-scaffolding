# SPEC — Agent-driven slice-demo evaluation (scaffold-dev #44)

**Date:** 2026-05-31 · **Plugins:** `scaffold-dev` + `scaffold-onboard` · **Ships in:** the combined v0.2 PR on `feat/pr-hierarchical-merge-mode`
**Issue:** [#44](https://github.com/draco28/claude-agent-scaffolding/issues/44) — *slice-demo verification grammar (closing-vertical-slice) is inconsistent with the work-item AC grammar*
**Status:** Design approved (brainstorm 2026-05-31, option **D — agent-driven slice-demo eval**). Next: implement on branch.

> **Decision lens:** the cycle-wide promoted principle — *agent-review over deterministic semantic gates; deterministic only for mechanical facts* ([[feedback_agent_review_over_deterministic_gates]]). The v0.1.7 bugs were brittle deterministic grammar parsers; #44 is the same class of drift between two such grammars. We resolve it by removing the brittle part, not by reconciling two parsers.

---

## 1. Problem

Two demo/verification grammars drifted apart:

- **Work-item AC grammar** (scaffold-dev, hardened in v0.1.7): `exit 0` / `exit N`, `output contains <unquoted substring>`, **no** `count`. A mechanical per-work-item gate (`implementation-checking`).
- **Slice-demo grammar** (R3; authored by **scaffold-onboard** `authoring-vertical-slice-demo`, parsed/evaluated by **scaffold-dev** `closing-vertical-slice`): quoted `output contains "<pat>"`, `output matches /<regex>/`, **`count > 0`/numeric predicates** (incl. `ran ≥N` — assert the run passed and ≥N tests executed, the portable count guard for runners outside scaffold-dev's `exit 0` zero-test allowlist; #79), exit-code form.

Divergences: (a) quoting of `output contains`, (b) `count`/predicate support. Full unification is a trap — aligning *down* drops the `count`/predicate capability slice demos legitimately use; aligning *up* reverses the deliberate v0.1.7 work-item minimalism.

Two latent defects also surfaced during design (both in `closing-vertical-slice`):
- It references `lib/render.sh::sd_demo_parse_block` — **no such function exists** anywhere in scaffold-dev.
- Its eval's out-of-scope list cites `tests/test-demo-parse.sh` — **no such file exists**.

## 2. Goal

The two grammars are different **by design and documented**, not as drifting parser dialects:
- **Work-item ACs stay deterministic/mechanical** (untouched — v0.1.7 stands).
- **Slice demos become agent-judged acceptance checks.** The closing orchestrator runs each `auto:` command (mechanical capture of exit code + stdout) and **judges** whether the output satisfies the expectation — no brittle bash grammar for content predicates.

This mirrors the #40 hybrid: deterministic where it's a mechanical fact (run the command, read the exit code), agent-judged where it's interpretation (does this output demonstrate the slice?).

### Non-goals
- No change to the work-item AC grammar or `implementation-checking`.
- No new manifest flag (the closing skill's orchestrator is already an agent; agent-judged demo eval is the unconditional default — a strict improvement).
- No general-purpose NL-expectation DSL; we simply stop *parsing* content predicates and let the agent judge them.

---

## 3. The model

For each `auto:` demo line `auto: <command> → expected: <expectation>`:

1. **Run (mechanical, deterministic):** execute `<command>` in canonical (post-merge slice state — on the slice branch under `pr_hierarchical`, per the #40 wiring already on this branch), capturing `(exit_code, stdout/stderr)`. The `cd "$canonical"` discipline is unchanged.
2. **Judge:**
   - If the expectation is an **exit-code form** (`exit 0` / `exit N`): deterministic fast-path — pass iff `exit_code == N`. (Mechanical fact; stays deterministic.)
   - Otherwise (any **content expectation** — `output contains …`, `output matches …`, `count > 0`, `ran ≥N`, `> 5 rows`, or free-form prose): the orchestrator **judges** whether the captured output satisfies the stated expectation, and records its verdict **with a one-line reason**. No bash substring/arithmetic parsing.
3. **Record** the outcome in the VS README `## Demo verification` section (one line per step, now including the agent's reason).
4. **Halt-on-first-fail is preserved** — a judged fail halts exactly as today (no remaining `auto:`, no `user:`, no architect-critic, no retrospective, no harvest, no worktree removal).

The orchestrator **parses the demo lines directly** (split on the literal ` → expected: ` after the `auto:`/`user:` prefix and the U+2192 arrow) — removing the phantom `sd_demo_parse_block` dependency. No lib parser is introduced (parsing a two-field line is trivial and the evaluation is agent-driven anyway).

---

## 4. Changes

### 4.1 scaffold-dev — `closing-vertical-slice/SKILL.md`
- **§4 (Demo-criteria parse):** replace the `lib/render.sh::sd_demo_parse_block` reference with direct orchestrator parsing of the README demo block (documented line format). Keep the U+2192 arrow + `auto:`/`user:` prefix contract.
- **§5 (Layer-1 auto-demo):** rewrite the evaluation from deterministic grammar-eval to **run-then-judge**: run the command (capture exit + output), deterministically check `exit N`, agent-judge content expectations with a recorded reason. Preserve `cd "$canonical"`, the `pr_hierarchical` slice-branch checkout (already added by #40), halt-on-first-fail, and the "mutate only the failing Demo-verification line" rule.
- Record format gains a reason, e.g.:
  `- [x] auto: <cmd> → expected: <exp> → observed: pass — <one-line reason>`

### 4.2 scaffold-dev — `evals/closing-vertical-slice.md`
- **S1:** the two `auto:` lines still run in canonical; the **content** expectation (`output contains "ok"`) is now **agent-judged** (assert the judge reads the captured output and records a reasoned pass), not grep-asserted. Keep ceremony-order + M2 assertions intact.
- **S2:** the first `auto:` step is **judged** fail → halt (the exit-1 case stays a clean deterministic fail; assertions about halt + surfaced failing line are unchanged).
- Update the out-of-scope line that references the nonexistent `tests/test-demo-parse.sh` (replace with: demo evaluation is agent-judged, validated by these scenarios).

### 4.3 scaffold-onboard — `authoring-vertical-slice-demo`
- **`references/auto-grammar.md` §2:** keep both expected-clause modes, but reframe: **exit-code mode = deterministic**; **pattern/predicate mode = agent-judged at slice-close** (formalizing the doc's existing "informal predicate, judge-verified" language). Replace the "scaffold-dev grep-checks captured stdout" sentence with "the closing orchestrator judges the captured output against the expectation." Note that quoting/regex/predicate phrasings are all accepted (they read as the expectation the judge evaluates).
- **`SKILL.md`:** add a one-line cross-reference distinguishing the two levels — work-item ACs are mechanical/deterministic (`implementation-checking`); slice demos are agent-judged acceptance (`closing-vertical-slice`).
- This authoring skill keeps validating only that a demo line is **well-formed** (prefix + arrow + non-empty `expected:`); it does **not** constrain the predicate shape.

---

## 5. Testing
- **scaffold-onboard authoring** validation is structural (well-formedness) and unchanged in mechanism — confirm its existing suite/eval (`evals/authoring-vertical-slice-demo.md`) still passes; adjust only assertions that claimed scaffold-dev grep-evaluates predicates.
- **scaffold-dev closing** demo evaluation is agent-judged → validated by the **eval scenarios** (LLM-judge S1/S2), not bash asserts — consistent with the principle.
- **Full suites stay green** for both plugins (run the whole suite for each). No deterministic test asserts the removed grammar-eval behavior.

## 6. Rollout
- scaffold-dev is already at **v0.2.0** on this branch (no further bump for #44).
- **scaffold-onboard:** patch bump (current `0.3.x` → next patch) in **both** `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (dual-publish parity enforced) + the README version-table row. Implementation reads the current version and increments the patch.
- Ships in the single combined PR with #40 (and later #33).

## 7. Open items carried into implementation
- Exact wording of the §5 run-then-judge instructions (must keep halt-on-first-fail unambiguous and the recorded-reason format consistent).
- Whether to also delete the phantom `sd_demo_parse_block` mention from any other doc (grep at implementation time; only `closing-vertical-slice/SKILL.md` is known so far).
