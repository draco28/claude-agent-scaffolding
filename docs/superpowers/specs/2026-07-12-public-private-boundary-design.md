# Public/Private Boundary — Ossify Companion Design (Part Two)

**Date:** 2026-07-12
**Status:** APPROVED 2026-07-12 (user review passed; self-review v2 applied: 3 P1 / 12 P2 / 7 P3 + 7 fact findings fixed)
**Origin:** Part-two brainstorm 2026-07-11/12 (continuation of the skeleton-first session)
**Amends:** `2026-07-11-poc-first-lifecycle-design.md` (ossify) — fulfills its §11; touchpoints in §8 below
**Companion carve-out:** small ADDITIVE workspace-init extension (§4.1: manifest fields + resolver + an `add-private-core` provisioning helper) — the sanctioned exception to ossify §12's "no changes to workspace-init"

---

## 1. Problem & evidence

Solo-built products need *functionality* privacy, not just docs privacy — important
capabilities (algorithms, prompts, strategies) should live in private packages
while public repos stay runnable. Field evidence (2026-07-12 readers over
PulseDB, PulseHive, pulse-trader, and the tooling):

- All three projects already run public/private sibling pairs under `pulseai-labs`
  (`X` public + `x-internal` private AI workspace); PulseDB and PulseHive carry a
  written `PUBLIC_BOUNDARY.md`. Docs privacy is a solved pattern; functionality
  privacy is not.
- All three are Rust with real ports-and-adapters seams already in place
  (PulseDB: 6 port traits; pulse-trader: strict hexagonal, 6 port traits in
  `domain/port.rs` plus `Clock`; PulseHive: port traits in `pulsehive-core`,
  providers injectable). The boundary can be cut along existing seams.
- **Rust reality check:** runtime plugin loading (dlopen) is unnatural (no stable
  ABI; fights pulse-trader's determinism fingerprint). The idiomatic channels are
  (a) private *data* loaded at runtime and (b) private *crates* at compile time
  injected through public ports. Hard constraint shaping everything:
  **crates.io forbids non-crates.io dependencies for published crates → the
  public crate can never depend on the private one; the private crate is the
  composition (the real app).** (Binds crates actually published to crates.io;
  path/git dev-dependencies are stripped at publish and remain possible.)
- pulse-trader anticipated the design: `src/agent/config.rs` documents a
  `$PULSE_PROMPT_DIR` override as "the private-workspace override —
  forward-compat to the owner's runtime-private moat"; standing discipline
  "moat in DATA, not code".
- Concrete tracked leaks today: pulse-trader's `src/agent/prompts/composer.md`
  (system prompt, `include_str!`); PulseHive's orchestration prompts in public
  source + its own PRD/Backlog publicly tracked; PulseDB's decay/re-rank
  implementations public while their spec (`DECAY_SPEC.md`) is private.
  Leak-adjacent: PulseDB's 76KB `SPEC.md` untracked-but-present in the public
  working tree, protected only by `.gitignore`.
- Tooling: the pairing manifest is additively extensible (exact precedent:
  optional `tooling_repo`, PR #81, no schema bump per SPEC-workspace-init §6.5).
  **Trap found:** the manifest resolvers hardcode two roots and silently pass
  unknown `${x.root}` tokens through as literal broken paths — and there are
  THREE resolvers to extend: `wi_manifest_resolve`, scaffold-onboard's local
  minimal resolver, and scaffold-dev's local fallback (`_sd_manifest_resolve_local`)
  whose ossify port inherits the trap. The trace-filter hook installs per-repo
  (blocks AI-trace commit messages; no per-repo pattern override). No
  `visibility` field exists anywhere in the manifest. `during_dev.worktrees_dir`
  is anchored to the canonical root; worktree creation is canonical-only today.

## 2. Decisions (from the part-two brainstorm)

| # | Decision |
|---|---|
| 1 | Privacy posture is **per-project**, decided during planning. Recorded target postures (design fixtures; migration itself out of scope): pulse-trader → `fully-private` (both repos; note: its *current* observable facts read `source-available` — the fixture must include the user's intent signal); PulseDB → `open-core` (intelligence private); PulseHive → `fully-open` code with tightened doc routing (only user-facing docs public) |
| 2 | Capability lives **inside ossify** (onboarding block + bones registry + release-close audit), NOT a separate plugin — a separate plugin would recreate the cross-plugin contract seam ossify eliminated |
| 3 | **Default-private rule:** "undecided" posture always resolves to private; private→public is **one ceremony** later (§5.1 pre-flip audit), public→private is impossible |
| 4 | Multi-repo execution = **option (a)**: one project, multi-repo manifest, spines declare target repo, demo/release close run against the composition root |
| 5 | **Hygiene independent of visibility:** trace filter + canonical cleanliness enforced even in fully-private repos, so posture flips stay one-ceremony |
| 6 | Boundary audit is **mechanical-first** (deterministic path/pattern checks + gitleaks presence), agent judgment only for the semantic leak question; findings escalate through disposition triage as high-stakes (never auto-dispositioned to pass) |
| 7 | workspace-init gains a small **additive** extension: manifest fields, resolver tokens, and an `add-private-core` provisioning helper (§4.1) — sanctioned carve-out to ossify §12 |

## 3. The posture decision (ossify spec-core onboarding, new block)

Asked alongside bones-registry authoring (its output IS bones):

1. **Posture:** `fully-private` | `source-available` (PolyForm-style) |
   `open-core` (e.g. AGPL + commercial dual-license) | `fully-open`; plus
   revenue intent (`none` | `license` | `saas`) — consumed as the seed of the
   posture bone's **revisit trigger** (e.g. `saas` → "revisit when the SaaS
   decision lands"). Undecided → `fully-private` (decision #3).
2. **Moat inventory:** each item worth protecting is named and mapped to a
   **channel**:
   - `data-overlay` — runtime files/DB the public code loads (prompts,
     strategies, price tables, personal configs); requires a named override
     seam in the public code. The overlay location + demo-env wiring (e.g.
     `$PULSE_PROMPT_DIR`) is recorded in project-state.json next to the
     composition root; the Release 0 clean-checkout test treats a *declared*
     overlay env var as configuration, not manual repair.
   - `private-package` — compile-time private crate/package implementing
     public ports, linked at the composition root.
   - `repo-private` — the whole repo is private (subsumes the others).
3. **Stack packaging pattern** — reference-loaded per language (lives in
   `references/` under ossify's `start` entry skill, §8):
   - Rust: private git-dep crate depending on the public core crate;
     composition root (bin) in the private repo; crates.io arrow constraint;
     determinism-fingerprint participation for math-path crates.
   - Python: private package (git dep / private index), entry-points or
     explicit injection at the app composition module.
   - TypeScript: private npm scope or git dep; injection at the app entry.

**Placement rule:** the AI workspace never holds product code. Private code
requires `private_core` — an implementer may not shortcut private crates into
the `-internal` docs repo.

Outputs: the **two boundary artifacts** (§3.1), bones-registry entries (§5),
and manifest fields (§4.1).

### 3.1 Boundary artifacts — split by audience (public-safe vs private)

The v1 draft's single contract was self-defeating (a public file enumerating
every private asset). Split into two:

**(a) `PUBLIC_BOUNDARY.md` — tracked in each public repo. Public-safe only.**
Generalizes the existing PulseDB/PulseHive artifacts. Contains:
- A **machine-checkable rules block** (grammar settled at implementation
  planning, §9.1): path globs/patterns that must never be tracked here
  (secrets patterns, fixture rules, doc-class exclusions). This block is what
  the §6 mechanical audit executes — deterministically, from a clean checkout
  or CI, with no private context needed.
- **Working-tree hygiene allowlist** (pattern-level): which *classes* of
  untracked sensitive files are known to exist in local clones (e.g.
  `SPEC.md`, `.env*`) — named by pattern, never by content description.
- Prose never-here rules (no secrets, no downstream strategy, no non-synthetic
  fixtures, no AI-workspace material). No moat item is *named* here.

**(b) Boundary inventory — routed to the AI workspace (private).**
The moat channel table: item → channel → where it lives → override/injection
seam (file/trait) → leak-risk note; plus the composition root and overlay
wiring. Consumed by the §6 semantic pass and the phase-2 `migrate` flow.
Indexed from project-state.json.

A fully-private project authors at minimum artifact (a) with the standard
secrets rules (decision #5: it must be able to flip posture in one ceremony).

## 4. Multi-repo mechanics (option a)

### 4.1 workspace-init extension (additive, no schema bump)
- Every repo object (`ai_workspace`, `canonical`, `tooling_repo`, and new
  `private_core`) gains optional `"visibility": "public" | "private"` (absent =
  unknown; creation-time decisions treat unknown as private per decision #3 —
  but the §6 audit gates on *observed* visibility, not this field).
- New optional top-level object, mirroring the `tooling_repo` precedent:
  `"private_core": { "root", "name", "git_remote", "default_branch" }` —
  absent by default (key omitted, not null). Exactly one for now; an array is
  a future additive change (YAGNI).
- **All three resolvers** extended to resolve `${private_core.root}`:
  `wi_manifest_resolve`, scaffold-onboard's local minimal resolver, and
  scaffold-dev's local fallback — plus the ossify port of the dispatcher libs.
  (Closes the silent-literal-path trap everywhere it exists.)
- `topology` gains the additive value `"multi-repo"`, written when
  `private_core` is present. No runtime consumer branches on the literal today
  (verified; only test fixtures assert it — update them at build time).
- **Provisioning owner:** a new small workspace-init helper flow,
  **`add-private-core`** — creates/registers the private repo, sets the
  remote, writes the manifest fields (object + visibility + topology), and
  installs the trace-filter hook there (decision #5). Ossify's `start` (or
  `plan-release`, when a posture decision mid-project introduces a split)
  invokes it; ossify never edits the manifest directly.
- `doctor` checks: manifest visibility vs observed `gh` visibility for every
  repo with a remote (mismatch = error); `ai_workspace.visibility: public` =
  error (nonsensical and dangerous).

### 4.2 Spine/work-item repo dimension (ossify)
- A spine may span repos; **each work item targets exactly one repo**
  (`target_repo` in project-state.json, default `canonical`) — its worktree
  spins up in that repo; the implementer contract is unchanged. The
  worktree-spawn machinery gains a repo parameter; worktrees for
  `private_core` live under `<private_core.root>/.worktrees` (same convention,
  repo-relative; no new manifest field).
- The DAG orders cross-repo dependencies (e.g. round 1: public port change;
  round 2: private adapter).
- **Cross-repo build mechanics (the part that must be explicit to compile):**
  the private composition depends on the public core via git-dep/registry, but
  mid-spine the public changes exist only on local spine branches. So:
  private_core worktree spin-up injects a **worktree-scoped local dependency
  override** pointing at the canonical repo's current spine state (Cargo
  `[patch]`/path override; pip editable/path; npm `file:`/overrides). The
  override is never committed — impl-check and spine close verify its absence
  from staged/tracked content. The spine-close cumulative demo builds the
  composition **with** the local override (both repos' post-merge state).
- **Per-repo branch/merge semantics:** each touched repo carries its own spine
  branch; rounds merge per repo in DAG order; a merge conflict in *either*
  repo halts the whole spine at the last cross-repo-consistent round
  (halt-and-surface, as today — no automated cross-repo rollback). The release
  PR gate (ossify §6.2 step 7) emits **one PR per touched repo**.
- **Release-close pin/publish step (new, before the final walkthrough):** for
  open-core postures — publish or tag the public core (crates.io release or
  pinned git rev), re-pin the private composition to the released rev, remove
  any lingering overrides, rebuild. The release walkthrough then runs against
  real pinned dependencies, not local patches.

### 4.3 Composition root is the demo target — and the public edition must not rot
- The cumulative product demo and the release-close walkthrough always run
  against the **real product build** — for open-core projects, the private
  composition. A release cannot close green on the community edition alone.
- **Community-edition runnability line:** for `open-core` and `fully-open`
  postures, the cumulative ledger MUST carry a standing `auto:` line that
  builds and smoke-runs the public repo standalone from a clean checkout
  (generic composition, no private inputs). "Public repos stay runnable" is
  thereby enforced at every spine close, not assumed.

## 5. Boundary as bone (ossify §7 integration)

- Each public/private boundary is a **bones-registry ADR**: decision = the
  posture + channel design; touch surface = the private-side modules/crates
  plus the seam files (ports, override loaders, composition root); revisit
  trigger seeded from revenue intent (§3.1).
- Free consequences, no new machinery: a flesh spine touching the boundary
  auto-reclassifies to bone; the critic vetoes misclassification; **posture
  changes are bone-supersede ceremonies** with mandatory citation
  re-verification (ossify §7).

### 5.1 The private→public flip: one ceremony, never one click
The flip is the moment of maximum irreversible risk — publishing exposes the
repo's entire accumulated **history**, which routine audits never scanned.
The posture-supersede ceremony therefore mandates, before the visibility
change: a **full-history secrets scan** (gitleaks full-history mode), a
full §6 boundary audit of the tip, and a semantic moat scan over history-reachable
docs. Only after a clean (or explicitly accepted) result does the repo go
public. Decision #3's "one click" is formally "one ceremony".

## 6. Boundary audit (new release-close step, ossify §6.2)

Runs at every release close. **Gating: observed visibility, not the manifest
field** — for every repo whose `gh repo view` reports public, or whose remote
visibility cannot be determined while a remote exists. A manifest/observed
mismatch, or an unset visibility field on a repo with a remote, is itself a
blocking finding (fail-closed; the v1 draft failed open on exactly this).

Steps (mechanical-first per decision #6):
1. **Tracked-file audit** — execute the machine-checkable rules block of the
   repo's `PUBLIC_BOUNDARY.md` against tracked files (deterministic); gitleaks
   config presence check; GitHub push-protection check (best-effort via gh).
   **A `visibility: public` repo with no `PUBLIC_BOUNDARY.md` is a blocking
   finding** with an authoring-remediation pointer (never a silent skip).
2. **Leak-adjacent scan** — pattern-scan **all untracked files** in the public
   working tree against the sensitive-pattern set; files matching the hygiene
   allowlist are standing warnings, unlisted hits are new findings. (Scan-first
   semantics — iterating only the allowlist would never catch a new
   `SPEC.md`-class file.)
3. **Semantic pass (agent)** — using the *private* boundary inventory: "does
   anything tracked in the public repo *describe* a moat item?" (strategy
   docs, algorithm rationale, roadmap leakage).

Findings escalate through disposition triage as **high-stakes** (never
auto-dispositioned to pass). A finding is *confirmed* when the user affirms it
at triage; confirmed findings block the release close. The only unblock paths:
fix before close, or an explicit **accepted-disclosure override** recorded in
project-state.json with a reason. (This is the finding-producing release-close
step whose confirmed findings block; the ceremony's step 1 "all spines closed"
refusal gate is unaffected.)

## 7. Scope fence

- **In:** onboarding block (§3), boundary artifacts (§3.1), workspace-init
  extension incl. `add-private-core` (§4.1), spine repo-targeting + cross-repo
  build/merge mechanics (§4.2), composition-root + community-runnability rules
  (§4.3), boundary-as-bone + pre-flip audit (§5), boundary audit (§6), stack
  packaging references.
- **Out:** actual migration of pulse-trader/PulseDB/PulseHive (separate task;
  ossify phase-2 `migrate` will consume boundary inventories); private
  registry setup; mirror/subtree machinery (option c, rejected); per-repo
  trace-filter pattern overrides (not needed under decision #5); N>1
  `private_core` repos.

## 8. Amendment touchpoints into the ossify spec

| Ossify section | Change |
|---|---|
| §3 Vocabulary | + posture, moat channel, boundary artifacts (contract + inventory), private_core, composition root |
| §4 station 1 (Pair) | no longer "unchanged": pairing may write visibility fields, `private_core`, `topology: multi-repo` (via workspace-init `add-private-core`) |
| §4 station 2 | + openness & boundary block (this §3) |
| §5.3 Spine planning | work items gain `target_repo`; cross-repo DAG note |
| §6 Execution engine | worktree machinery gains a repo parameter (+ `<private_core.root>/.worktrees` convention); per-repo branch/merge semantics; local dependency override at private_core worktree spin-up; override-absence check in impl-check |
| §6.1 Spine close | cumulative-demo core row reworded: "composition-root post-merge state" (canonical post-merge for single-repo projects); + community-edition runnability line for open-core/fully-open |
| §6.2 Release close | + pin/publish step (open-core) before the walkthrough; + boundary audit step (§6, blocking on confirmed findings); PR gate emits one PR per touched repo |
| §7 Architecture evolution | boundary-as-bone; posture-supersede path + mandatory pre-flip full-history audit (§5.1) |
| §8 Docs & memory | routing: `PUBLIC_BOUNDARY.md` → each public repo root (tracked); boundary inventory → AI workspace |
| §9.1 Skill tree | stack packaging references under `start`; boundary-audit checklist under `close`; `doctor` gains visibility cross-checks |
| §9.2 State | + `target_repo` per work item, posture + boundary/inventory index, composition root, overlay wiring, accepted-disclosure overrides |
| §12 Non-goals | carve-out: additive workspace-init extension (§4.1 incl. `add-private-core`); reword "dual-repo remains the assumption" → "dual-repo baseline, additively extended to multi-repo; single-repo still out of scope" |
| §13 Open questions | + this spec's §9 items |

## 9. Open questions (non-blocking)

1. `PUBLIC_BOUNDARY.md` machine-checkable rules grammar + template fields —
   settle at implementation planning (seed from the PulseDB/PulseHive
   artifacts; reuse the mcrule DSL experience where it fits).
2. gitleaks integration depth: require the tool vs best-effort-if-installed
   (lean: best-effort + doctor check; the pre-flip history scan SHOULD require
   it).
3. Whether `start` should offer posture presets by project archetype
   (library / app / SaaS-candidate) — nice-to-have.
4. Eval fixtures: the three recorded **target** postures (decision #1) are the
   test suite — each fixture bundles the project's observable facts PLUS the
   user's intent signal, and a planner must derive the decided
   posture/channel/structure (pulse-trader's facts alone read
   `source-available`; the intent signal is what flips it to `fully-private`).
