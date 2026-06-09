# SS-7 — Remove the deterministic `--fast` fallback (fully agent-driven derivation)

**Date:** 2026-06-09 · **Type:** refactor / removal (behavior change) · **Depends on:** SS-2 (shipped)
**Ledger:** N6 = #56 · **Plugins touched:** `scaffold-onboard` only · **Release:** scaffold-onboard `v0.8.0`
**Design settled with user 2026-06-05** (agent-driven-first-class pivot, memory `project_agent_driven_first_class_pivot`) + this brainstorm 2026-06-09.

---

## 1. Decision

Agent synthesis is the **only** derivation path. Delete the deterministic `--fast` fallback and
every deterministic *content authoring* path it reaches. There is **no deterministic content
fallback** — not on a missing Task tool, not on LLM/token-cost failure, not on structurally-bad
output. Closes #56.

## 2. The uniform agent-unavailable model (replaces `--fast` everywhere)

Every surface that authors content uses one model:

1. **Dispatch** the synthesis sub-agent (default).
2. **No Task tool (headless)** → **main-context-inline synthesis**: the conducting agent authors
   the artifact itself from the same brief. Still agent reasoning — no deterministic render.
3. **Synthesis produces structurally-invalid output** → **re-dispatch once** with a corrective
   instruction; if it still fails → **hard-fail with actionable remediation** (state preserved;
   "re-run the command to retry"). One corrective retry, then stop — no infinite loop.
4. **Host runtime genuinely cannot synthesize/write** → hard-fail with remediation. Never a
   deterministic content substitute.

**Kept (mechanical, non-reasoning — per the pivot's bash-for-non-reasoning carve-out):** file I/O,
manifest routing, the mcrules-preserve zone, live-seed/static-copy, the roadmap JSON→markdown
**formatter**, structural **validation** of agent output (parse-validity), and cksum/provenance
trailers.

## 3. Per-surface scope

The `SF_SYNTH_FAST` env var, the `sf_synth_mode` helper, all `--fast` flag parsing, and every
`if sf_synth_mode == fast` branch are deleted.

| Surface | Deterministic *content* renderer removed | Mechanical bits kept |
|---|---|---|
| **memory-bank** (`lib/memory-bank.sh`, `scaffolding-memory-bank` §13) | the template-fill render of spec-derived files inside `sf_memory_bank_derive` | `sf_memory_bank_seed_live_static`, mcrules-preserve zone, static copy, manifest routing |
| **governance** (`lib/docs.sh`, `scaffolding-governance-docs` §11) | `sf_docs_derive` template-fill render of the 5/14 docs | doc-set selection, manifest routing (product vs process ADRs), file I/O |
| **roadmap** (`planning-project-roadmap` §16) | *(no content renderer exists)* — remove the `--fast` dispatch-vs-inline toggle; always dispatch, inline fallback | the roadmap JSON→markdown formatter (`lib/roadmap.sh`) — mechanical, stays |
| **MASTER-SPEC** (`onboarding-project` §8) | *(already none — SS-3)* — remove any `--fast` vestige | digest assembly, `sf_spec_validate` |
| **EXEC-SUMMARY** (`onboarding-project` §8, `lib/render.sh`) | `sf_render_executive_summary` (extract) + `sf_render_executive_summary_from_state` (bootstrap-author) | `sf_render_executive_summary_from_synthesized` (see §4) |

`sf_memory_bank_derive` and `sf_docs_derive` collapse to **mechanical-only** helpers (seed/route/zone);
if nothing mechanical remains in a function after the render body is removed, delete the function and
call the mechanical helper directly (decide per-function at plan time).

## 4. EXEC-SUMMARY specifics

- Content is **100% agent-authored**. Remove `sf_render_executive_summary` (extract-as-fallback) and
  `sf_render_executive_summary_from_state` (bootstrap-author from raw Phase-1 answers).
- **Keep** `sf_render_executive_summary_from_synthesized` — it is mechanical I/O + a corruption guard
  (validates the agent body, rejecting `##`/`---`/phase-markers that would truncate MASTER-SPEC's
  pinned section; writes it back + cksum). This sits on the *keep* side of §2's line (the SS-2
  adversarial-review safeguard for the SSoT).
- **Rejection path becomes:** on `_from_synthesized` rejection, re-dispatch the EXEC-SUMMARY agent
  once with a corrective instruction ("prose/bullets only — no `##`, `---`, or phase markers"); if it
  still fails → hard-fail with remediation. No deterministic substitute.
- **Consumer produce-once-if-missing** (settled during execution 2026-06-09): `/scaffold-project`
  (memory-bank §13) and `/scaffold-docs` (governance §11) currently call the now-removed
  `sf_render_executive_summary` to extract MASTER-SPEC's pinned section into `EXECUTIVE-SUMMARY.md`
  for legacy projects. SS-7 replaces that with an **agent dispatch**: when `EXECUTIVE-SUMMARY.md` is
  missing, dispatch the `EXECUTIVE-SUMMARY.brief.md` synthesis agent from MASTER-SPEC →
  `_from_synthesized` write-back (same as the onboarding-close producer, minus inline fallback if
  headless). The staleness path (`sf_exec_summary_staleness`, mechanical cksum) is unchanged.

## 5. Test strategy (the bulk of the work)

Bash tests cannot run a live agent, so today most memory-bank/governance content coverage rides on
the deterministic renderers (`test-memory-bank.sh`, `test-docs.sh`, several `test-e2e.sh` cases call
`sf_memory_bank_derive` / `sf_docs_derive` directly and assert rendered content). Removing the
renderers requires shifting that coverage:

- **Convert** affected bash tests to assert only the **mechanical layer** — seed live/static,
  manifest routing, mcrules-preserve zone, cksum/provenance — using **canned "synthesized" output
  fixtures** (the fake-agent pattern `test-synthesis-dispatch.sh` already uses).
- **Delete** the deterministic content-render assertions. **Content-correctness moves to the
  `evals/` LLM-judge** — audit `evals/` for coverage gaps and add scenarios where the bash suite was
  the only check.
- **Rework `test-synthesis-dispatch.sh`** (~30 `SF_SYNTH_FAST` refs): the "skill exports
  `SF_SYNTH_FAST` for `--fast`" guard tests invert to "no `--fast` path exists / `sf_synth_mode`
  gone".
- **Inline-fallback (no-Task-tool) path** can't be exercised in bash → cover with a doc-grep test
  that each dispatch skill documents the inline fallback (same style as the skill-presence tests).

## 6. Cleanup inventory

- **Lib:** `synthesis.sh` (`sf_synth_mode`), `memory-bank.sh` (`SF_SYNTH_FAST` exports + `--fast` parse + render body), `docs.sh` (same), `render.sh` (two EXEC-SUMMARY renderers).
- **Skills:** `scaffolding-memory-bank` §13, `scaffolding-governance-docs` §11, `planning-project-roadmap` §16, `onboarding-project` §8 + §9 flag docs; `authoring-vertical-slice-demo`, `authoring-machine-checkable-rules` (scrub `--fast` if functional vs descriptive).
- **Commands:** `scaffold-project.md`, `scaffold-docs.md` (drop `--fast` from flag docs + arg-parse).
- **Templates:** `CLAUDE.brief.md`, `index.brief.md`, `DEFINITION_OF_DONE.md.tmpl` (scrub `--fast`).
- **Tests:** per §5.
- **Docs/ledger:** SPEC §5 SS-7 → ✅ SHIPPED; ledger N6/#56 → closed; `CHANGELOG.md` `[0.8.0]`.
- **Version:** `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` → `0.8.0`.

## 7. Risks

- **R1 (biggest):** the test conversion is large and error-prone — do it per-surface, full-suite-gate
  each commit.
- **R2:** with the deterministic content source gone, `evals/` is the only derived-content
  correctness check — audit for gaps and add eval scenarios before merge.
- **R3:** the inline-fallback path is unrunnable in bash — doc-grep coverage only (R3 test above).
- **R4:** `sf_memory_bank_derive`/`sf_docs_derive` entangle mechanical work with render — separate
  carefully; keep seed/route/zone, remove render; re-point callers (incl. the synthesis-finalize
  path, which already uses `sf_memory_bank_seed_live_static`).
- **R5:** residual `--fast` in prose/templates read as a still-supported flag — final residue sweep
  for `SF_SYNTH_FAST` / `sf_synth_mode` / `--fast` must return only intentional historical mentions
  (CHANGELOG).

## 8. Acceptance

- No `SF_SYNTH_FAST` / `sf_synth_mode` / user-facing `--fast` anywhere except CHANGELOG history.
- Full scaffold-onboard suite green (18 files, post-conversion) + repo-root dual-publish 148 (parity
  at 0.8.0).
- `evals/` covers derived-content correctness for memory-bank + governance + roadmap.
- Every content surface documents the dispatch → inline → re-dispatch-once → hard-fail model.
- Ships via PR → Codex/CodeRabbit → merge on Codex-clean + green → tag `scaffold-onboard-v0.8.0`;
  #56 closed, SPEC ledger N6 closed.
