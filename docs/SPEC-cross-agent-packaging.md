# SPEC — Cross-Agent Marketplace Packaging: native install for Z code, OpenCode, Devin CLI

**Status:** Design (researched 2026-07-03 via council + 5 research agents; **pending grill/critique** → then implementation plan)
**Scope:** repo-level (the marketplace itself), not a single plugin
**Targets:** Z code (**✅ empirically confirmed**), OpenCode, Devin CLI · Warp **deferred**
**Author:** Pras (design via Claude Code — council + parallel research agents)

---

## 1. Context & motivation

The `claude-agent-scaffolding` marketplace ships **6 active plugins** — ai-mentor (2.3.0),
workspace-init (0.4.1), scaffold-onboard (0.12.0), scaffold-dev (0.17.0), architect-critic (0.5.1),
claude-security-audit (0.1.3) — plus a deprecated `scaffold`. Component surface across the 6:
**~36 skills, 29 slash-commands, 3 Task-tool subagents, 5 session-start hooks, 0 active MCP servers.**

Today it installs natively in **Claude Code** (`.claude-plugin/marketplace.json`) and **Codex**
(`.agents/plugins/marketplace.json`) via two dual-published manifests in the same repo. The felt pain:
**the same plugins are not usable in the user's other coding agents** (OpenCode, Devin, Z code, Warp).

The user's requirement is specific and rules out the obvious shortcuts: **one source of truth, installed
into each agent via that agent's own native plugin mechanism** (like `/plugin install`), so that after
install it "just works" and a version bump propagates. Explicitly **NOT** hand-copying `.claude`/`.agents`
folders into each repo, and **NOT** a file-rendering/sync tool that writes into agent config dirs.

This is the *Superpowers model*: one git repo, one shared skills payload, thin per-agent adapter packaging
that each host installs as a real plugin. The user validated the instinct — Superpowers itself is
installed as a plugin per agent, not copied.

### What the research settled (see §3)
- **Do NOT build "AgentPack"** (a full cross-agent package-manager/adapter-protocol product proposed by an
  external agent). Mature MIT tools (`rulesync`, `vercel-labs/skills`) already do that; building it would
  reinvent them. Council C-spike returned a decisive *adopt/reuse, don't build*.
- **Do NOT use file-copy / convention-inheritance / `rulesync`.** They write files into agent config dirs —
  the model the user rejected.
- **DO: native per-agent plugin install**, hand-authored thin adapters in the same repo. "Custom over
  adapted **when orchestration is thin**" — and it is thin (0 files for Z code, 1 JS file for OpenCode,
  1 manifest + a build step for Devin).

---

## 2. Goals / non-goals

**Goals**
- One repo → installable as a native plugin in Z code, OpenCode, and Devin CLI, alongside the existing
  Claude Code + Codex installs.
- After install, skills (and where supported, commands/subagents) are live with **no manual file-copying**.
- A single version bump updates every manifest in lockstep (drift-detectable). **Note (C1):** propagation
  to *installed* copies is per-target — a clean re-pull on some hosts, a documented refresh step on others
  (§5.4). The honest promise is "one edit → one command re-syncs every target," not "silently auto-updates."
- Honest, capability-based degradation: a primitive a target can't express is **visibly** dropped, never
  silently.
- A stated **trust model (C2):** what executes, with what privileges, on install per target (§7.5).

**Non-goals**
- Building a package-manager / adapter-protocol / capability-negotiation engine (AgentPack) — rejected.
- File-rendering/sync tools (`rulesync`, symlink farms into agent dirs) as the primary mechanism.
- Warp support (deferred — §12).
- MCP portability (moot: 0 active MCP servers).
- The **cloud** Devin agent (no plugin-install; org Knowledge/Playbooks only) — we target **Devin CLI**.
- Changing any plugin's Claude/Codex behavior — this is additive packaging only.

---

## 3. Settled decisions

| # | Decision | Choice |
|---|----------|--------|
| D1 | Build vs adopt vs reuse | **Reuse/adopt native mechanisms; do NOT build AgentPack** (council C-spike: `rulesync`/`vercel-labs/skills` already exist) |
| D2 | Distribution mechanism | **Native per-agent plugin install** (Superpowers model), not file-copy/inheritance/`rulesync` |
| D3 | Source of truth | **The existing marketplace repo** — one shared skills payload + thin per-agent adapter dotdirs |
| D4 | Scope | **Z code + OpenCode + Devin CLI**; Warp deferred |
| D5 | Z code manifest | **Reuse `.claude-plugin/marketplace.json`** (Claude-format consumer) — zero new files |
| D6 | Universal primitive | **Skills.** Commands collapse into skills; subagents collapse/degrade; hooks per-agent or dropped |
| D7 | Version parity | **`.version-bump.json` + bump script** (`--check` drift, `--audit`), borrowed from Superpowers |

---

## 4. Architecture: one payload, thin per-agent adapters

```
claude-agent-scaffolding/            (single source of truth)
├── <plugin>/skills|commands|agents|hooks   ← the shared payload (unchanged)
├── .claude-plugin/marketplace.json         ← Claude Code  ✅ have  (Z code reuses this)
├── .agents/plugins/marketplace.json        ← Codex        ✅ have
├── .opencode/plugins/marketplace.js        ← OpenCode     ← NEW (one JS glue)
├── package.json                            ← OpenCode pkg  ← NEW (name + main)
├── .devin-plugin/plugin.json + skills/     ← Devin CLI    ← NEW (manifest + aggregated skills)
├── .version-bump.json + scripts/bump-version.sh  ← version parity  ← NEW
└── (Z code: nothing — reuses .claude-plugin/marketplace.json)
```

**Skills are the universal primitive.** Every non-Claude target converges on it: OpenCode registers skill
dirs, Devin plugins are skills-only, Z code auto-discovers `skills/`. Commands (mostly thin `$ARGUMENTS`
wrappers) collapse into skills on Devin and inject as command entries on OpenCode; subagents collapse into
skills-with-frontmatter (Devin) or inject as agent entries (OpenCode); hooks are the consistent
odd-one-out.

---

## 5. Per-target design

### 5.1 Z code — REUSE existing manifest (✅ CONFIRMED, zero new files)
Z code (launched ~2026-07-01, GLM-5.2 desktop GUI) is a **Claude-format consumer**, not a fork. Verified
live on the user's machine:
- Registered in `~/.zcode/cli/plugins/known_marketplaces.json` from git source
  `github.com/draco28/claude-agent-scaffolding.git` (`pluginCount: 7`).
- All **6 active plugins installed** under `~/.zcode/cli/plugins/cache/claude-agent-scaffolding/`; skills
  live in-session; scaffold-onboard's SessionStart hook fired ("Tier 0 context preloaded").
- **It read `.claude-plugin/marketplace.json` (Claude schema) and ignored the Codex files entirely.**
- **To add a plugin later:** update the Claude `marketplace.json` `plugins[]`; Z code never looks at the
  Codex manifest.
- Minor cleanup: the deprecated `scaffold` (7th entry) is listed but not installed — consider removing it
  from the manifest to avoid the `pluginCount 7 vs 6 installed` confusion.

**Action in this spec:** none beyond documenting the workflow + the optional `scaffold` cleanup.

### 5.2 OpenCode — one plugin JS glue file
**Install:** add `"plugin": ["<pkg>@git+https://github.com/<owner>/<repo>.git"]` to `opencode.json`,
restart. Version-pin via `#<tag>`. **Update:** re-pull on restart, but Bun lockfile/cache can pin — may
need a `~/.cache/opencode` clear or reinstall (not a clean guaranteed `git pull HEAD`).

A single installed plugin serves all primitives **only** by mutating the `Config` singleton inside the
plugin's `config` hook (there is no `skills`/`command`/`agent` registration hook):
- **Skills** → push each plugin's `skills/` dir into `config.skills.paths` (proven in Superpowers'
  `superpowers.js`). ⚠️ **untyped/undocumented field** — the least contractually-safe part.
- **Commands** → parse each bundled `*/commands/*.md`, assign
  `config.command[name] = { template:<body>, description:<fm.description> }`. `$ARGUMENTS` is native.
- **Subagents** → parse `*/agents/*.md`, assign `config.agent[name] = { mode:"subagent", prompt:<body>,
  description, tools:{…} }`; translate Claude `tools:` comma-list → `{name:true}` map; omit `model`;
  rewrite `${CLAUDE_PLUGIN_ROOT}` → resolved package path.
- **Hooks** → re-implement the 5 session-start reminders as in-JS injection via
  `experimental.chat.messages.transform` (dedup-guarded). OpenCode has no `hooks.json` mechanism.

⚠️ **The one make-or-break unknown:** plugin-*injected* commands/subagents (vs static `opencode.json`) are
type-legal but **undocumented** — must be verified on a live instance (§8 Phase 0).

### 5.3 Devin CLI — manifest + aggregated skills
**Install:** `devin plugins install <owner/repo | git-url | local-path>` — **user-level, across all
projects**; `devin plugins update` propagates. Devin plugins are **skills-only**
(`.devin-plugin/plugin.json`, only `name` required, + a **flat top-level `skills/`**). Devin reads
`.claude/skills` SKILL.md **natively (no rewrite)**. ⚠️ **Beta / opt-in for enterprises (v2026.7.16)** —
confirm availability.
- **Skills** → aggregate the 6 plugins' `skills/` under one flat top-level `skills/` (build step or
  symlinks — Devin expects flat).
- **Commands** → re-express as skills with `triggers: user` (thin wrappers make this mechanical).
- **Subagents** → re-express as skills-with-subagent-frontmatter (no confirmed `.claude/agents` reader).
- **Hooks** → cannot ride in the plugin; ship as one-time user-level `~/.config/devin/config.json` block
  (or repo-committed `.devin/hooks.v1.json`).

> **C8 — TARGET TO PIN (blocks the Devin phase):** "Devin CLI" (this §) vs "Devin Desktop / Windsurf" —
> the user earlier said *Devin desktop*, and "Desktop shares the CLI plugin model" is **unverified**.
> Resolve which product is the real target before building the Devin adapter.

### 5.4 Update-propagation reality (per target) — C1

| Target | Update mechanic | Clean auto-update? |
|--------|-----------------|--------------------|
| Claude Code / Codex / Z code | marketplace refresh / re-pull | Yes (host-managed) |
| OpenCode | `git+https` re-pull on restart; **Bun cache may pin** → may need `~/.cache/opencode` clear or reinstall | **No — documented refresh step** |
| Devin CLI | `devin plugins update` (Beta) | Mostly (Beta caveat) |

The design does **not** promise silent auto-update everywhere; it promises **one edit → one re-sync command
per target**, with the OpenCode refresh caveat stated up front (not buried).

---

## 6. New components

- **`package.json`** (repo root, NEW) — `{ "name":"<pkg>", "version":"<bundle-ver>", "type":"module", "main":".opencode/plugins/marketplace.js" }`.
  **C3 — the `version` here is the *bundle* identity** (distinct from the 6 per-plugin versions) that
  OpenCode pins via `#<tag>`; a matching git tag `bundle-v<x>` is the pin point. `.version-bump.json` owns
  it alongside the per-plugin fields.
- **`.opencode/plugins/marketplace.js`** (NEW) — one plugin exporting a `Hooks` object whose `config` hook
  **dynamically iterates the 6 plugin dirs** (so new plugins/skills/commands are auto-included without
  editing the glue): registers skills dirs, injects commands + subagents by value, plus a
  `messages.transform` for the concatenated session-start reminders. `.gitignore` `.opencode/{node_modules,*.lock}`.
- **`.opencode/INSTALL.md`** (NEW) — install/pin/update instructions for this repo.
- **`.devin-plugin/plugin.json`** (NEW) — `{ "name":"claude-agent-scaffolding" }`.
- **Devin skills aggregation** (NEW, generated) — a flat top-level `skills/` assembled from the 6 plugins
  + the command→skill and subagent→skill conversions.
- **`scripts/build-devin.sh`** (NEW) — deterministic converter: commands (`triggers:user`) + subagents
  (subagent-frontmatter) → skills; aggregates into the flat `skills/`. **C4 — regeneration trigger:** runs
  in **CI on every push** (fails the build if the committed Devin `skills/` is stale) + as a pre-release
  step; the generated flat `skills/` is a **committed build artifact**, so `devin plugins install` from the
  repo needs no build step on the user's side.
- **`.version-bump.json` + `scripts/bump-version.sh`** (NEW) — declares every `{path, field}` holding a
  version; one command rewrites all in lockstep; `--check` (drift) + `--audit` (grep stray versions).

Reference implementation to mirror: `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.1.1/`
(`.opencode/plugins/superpowers.js`, `.opencode/INSTALL.md`, `.version-bump.json`,
`docs/porting-to-a-new-harness.md`).

---

## 7. One-plugin-per-repo vs per-plugin install (design tension to resolve in grill)

Claude/Codex/Z code treat the repo as a **marketplace of 6 separately-installable plugins**. OpenCode and
Devin CLI install **one git repo = one plugin**. Default choice: **bundle the whole marketplace as one
installable plugin** on OpenCode/Devin ("install the marketplace") — one `opencode.json` entry / one
`devin plugins install`, all 6 plugins' skills surfaced under one package. Trade-off: loses per-plugin
selectivity on those targets. Alternative (rejected for now): publish 6 separate installable units. **Grill
target G1.**

---

## 7.5 Security & trust model — C2

Cross-agent install ships **executable** surfaces, so state the trust boundary (this repo ships
`claude-security-audit` — silence here is indefensible):
- **OpenCode** — `.opencode/plugins/marketplace.js` is arbitrary JS executed **in-process at OpenCode
  startup**; it reads/parses the bundled plugin dirs and injects context. Trust = trusting this repo's
  code, same as any OpenCode plugin. Pin to a **tag** (not a moving branch) so an install is a reviewed
  snapshot.
- **Session-start reminders** (OpenCode `messages.transform`, Devin hook) inject text only — no side effects.
- **Hooks** (Devin `hooks.v1.json`) can run shell → the highest-privilege surface; ship them **opt-in** and
  documented, never silently.
- **Integrity** — installs are `git+https` / repo-slug from a single owner; a tag (optionally signed) is the
  integrity anchor. No third-party runtime deps in the adapter (Superpowers' zero-dep stance).
- **Self-audit** — run `claude-security-audit` (`/auditing-claude-configs`) against the adapter files as a
  release gate — dogfood our own tool on the new attack surface.

---

## 8. Implementation phases

**Phase 0 — de-risk spike (half-day), before committing to the full build:**
1. **Z code** — already ✅ confirmed (§5.1). Done.
2. **OpenCode make-or-break** — minimal `.opencode/plugins/marketplace.js` registering **ai-mentor** skills
   + injecting **one** command + **one** subagent; install on a live OpenCode; verify the injected command
   shows in the TUI palette and the subagent dispatches. **If injection fails → fall back to skills-only
   for OpenCode** (commands collapse into skills, as on Devin).
   - **2b. Command→skill fidelity (C5)** — pick one *shell-invoking* command (e.g. `/impl-check` → `bin/sd`,
     or an `arc`-invoking one) and confirm it still works after conversion to a skill on Devin (and
     skills-only OpenCode). If shell-dependent commands break, mark them **degraded** for those targets
     (visible, never silent).
3. **Devin** — confirm `devin plugins` Beta is available; install a 1-skill throwaway plugin to validate
   the flow.

**Phase 1 — OpenCode full adapter** (gated on Phase-0 #2): root `package.json` + full dynamic
`marketplace.js` + `.opencode/INSTALL.md` + `.gitignore`.

**Phase 2 — Devin CLI adapter:** `.devin-plugin/plugin.json` + `scripts/build-devin.sh` + generated flat
`skills/`; document the separate one-time hook install.

**Shared:** `.version-bump.json` + `scripts/bump-version.sh`; a one-prompt acceptance smoke test per agent.

---

## 9. Testing

- **Deterministic scripts** (`build-devin.sh` conversion, `bump-version.sh --check/--audit`) → bash unit
  tests under `tests/`.
- **OpenCode adapter** → a Node/Bun test that loads `marketplace.js`, runs its `config` hook against a mock
  `Config`, and asserts `config.skills.paths` gets all 6 skill dirs and `config.command`/`config.agent`
  get the expected entries; plus the live-instance acceptance test (§8).
- **Devin** → `devin plugins install <local-path>` → `devin plugins list` shows it → a converted
  command-skill and subagent-skill run under `/<plugin>:<skill>`.
- **Parity** → `bump-version.sh --check` reports no drift after a bump across all manifests.
- **Regression** → keep repo-root dual-publish/version-parity test green (per
  `reference_codex_dual_publish_test_location`); all existing suites stay green.

---

## 10. Migration & compatibility

- Purely **additive** — no change to plugin bodies or the Claude/Codex manifests' behavior.
- Existing `.claude-plugin/` + `.agents/plugins/` manifests unchanged (Z code rides the former).
- New root `package.json` must not disturb existing tooling (repo currently has none).
- Devin's generated flat `skills/` is a **build artifact** — decide tracked-vs-gitignored (grill target G2).

---

## 11. Open items (grill targets → resolve before implementation plan)

**Critique pass (2026-07-03, host-only; Codex fresh-frame timed out) — accepted:** C1 (update-propagation
reframe §2/§5.4), C2 (security/trust §7.5), C3 (bundle version §6), C4 (Devin regen trigger §6), C5
(command→skill fidelity §8 Phase-0 2b), C8 (Devin target pin §5.3). **Deferred (recorded, not dropped):**

- **C6 — MCP path:** 0 active servers today, so no adapter work now; adding an MCP server later **reopens
  all three adapters** — the recorded cost, tracked rather than solved.
- **C7 — rulesync as *author-time* codegen:** rejected as an *install* mechanism (writes into user dirs);
  not chosen as a build-time generator either, to keep zero external build deps + full control of the thin
  adapters — stays a fallback if a future target's transforms get heavy.

- **G1 — one-mega-plugin vs 6 units** on OpenCode/Devin (§7). Does "install the marketplace" as one bundle
  match intent, or is per-plugin selectivity needed on those targets?
- **G2 — Devin skills aggregation** — build step vs symlinks vs committed artifact; tracked or generated?
- **G3 — OpenCode injection risk** — if Phase-0 shows plugin-injected commands/agents don't surface, is
  **skills-only OpenCode** acceptable (commands still reachable as skills), or is that a dealbreaker?
- **G4 — untyped `config.skills.paths`** — accept the undocumented-field risk (Superpowers relies on it),
  or add a fallback?
- **G5 — update propagation honesty** — OpenCode's Bun-cache pinning and Devin's Beta status mean "one bump
  → everywhere" is not perfectly clean. Is the drift-check + documented reinstall step enough?
- **G6 — maintenance surface** — 5 packaging targets to keep coherent. Is the dynamic-iteration glue +
  version-bump script sufficient, or does content-parity (a new command reflected everywhere) need its own
  guard?
- **G7 — command→skill semantic fidelity** — do the 29 commands (some invoke `bin/sd`, `arc`, etc. shell
  libs) survive the Devin skill conversion, or do shell-dependent commands degrade there?
- **G8 — scope/sequence** — is Z code (done) + OpenCode next + Devin last the right order, or should Devin's
  Beta risk push it behind a stable release?
