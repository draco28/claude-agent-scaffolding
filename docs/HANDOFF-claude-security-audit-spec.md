# Handoff: claude-security-audit plugin SPEC authoring

**Purpose:** seed a fresh Claude Code session to author `docs/SPEC-claude-security-audit.md` — a NEW plugin in our marketplace that audits Claude Code project configurations for security risks. Inspired by Everything Claude Code's AgentShield pattern, MIT-licensed, attribution-friendly. Sibling to architect-critic (different audit concern: security vs anti-sycophancy review).

**Author:** carried over from scaffold-dev v0.1 SPEC brainstorm (2026-05-20 → 2026-05-22) and post-spec exploration synthesis where Everything Claude Code (ECC) was researched. AgentShield emerged as the most valuable pattern from ECC worth cherry-picking into our marketplace.

**Context:** Our marketplace currently has 4 plugins (ai-mentor, scaffold-onboard, scaffold v1.0.0 (deprecating), architect-critic). 2 new plugins in spec stage (workspace-init, scaffold-dev). Architect-critic does anti-sycophancy spec/plan review. **None of our plugins audit Claude Code project configurations themselves for security risks** — settings.json with overly-permissive permission grants, secrets accidentally committed to CLAUDE.md, hook injection via malicious hooks.json, MCP server configs pointing to untrusted endpoints, etc.

ECC's AgentShield demonstrates this is a real gap; their `/security-scan` claims 1,282 tests + 102 static analysis rules. We can ship an MIT-licensed, focused, composable version that fits our composable-plugins thesis without ECC's mega-plugin sprawl.

---

## 1. Goal of the next session

Author `docs/SPEC-claude-security-audit.md` and `docs/PLAN-claude-security-audit.md`. Then implement.

The build follows the established workflow: brainstorm → SPEC → PLAN → implement.

---

## 2. What's already settled (consume these as constraints)

### 2.1 Plugin identity

**Name candidates:** `claude-security-audit` (recommended), `claude-config-audit`, `agentshield-mit`, `security-scan`.

**Recommend: `claude-security-audit`** — explicit scope, dash-separated, alphabetical sort early in marketplace.

**Position in marketplace:** sibling to architect-critic. Both are "audit" plugins; different scopes. claude-security-audit focuses on SECURITY (configs, secrets, permissions, hooks, MCP); architect-critic focuses on ANTI-SYCOPHANCY (spec/plan adversarial review).

**Standalone:** not coupled to workspace-init manifest; not coupled to dual-repo workflow; not coupled to scaffold-dev/scaffold-onboard. Works on any Claude Code project.

### 2.2 Skill-first per Pass D

Skill-first surface from day 1. ~2-3 skills + thin slash command wrappers.

Reference: [project_skill_first_retrofit_queue memory] for the skill-first principle.

### 2.3 Attribution to ECC

The audit pattern is inspired by Affaan Mustafa's AgentShield in Everything Claude Code (https://github.com/affaan-m/everything-claude-code, MIT). Our implementation is independent (designed for our composable-plugins thesis, not bundled into a mega-plugin) but the conceptual debt is acknowledged.

**Attribution language in plugin README + each skill body:**
> "Inspired by AgentShield in Everything Claude Code (Mustafa, 2026; MIT). This implementation is an independent, focused MIT-licensed audit tool tailored to composable plugin marketplaces."

### 2.4 Audit scope

The plugin audits these aspects of a Claude Code project's `.claude/` directory + related configs:

1. **Secrets detection** — scan CLAUDE.md, settings.json, hooks/, agents/, skills/, MCP configs for accidentally committed secrets (API keys, tokens, passwords, env-var leaks)
2. **Permission audit** — settings.json permission grants (review which tools have explicit allow/deny; flag overly-permissive patterns; flag dangerous combinations)
3. **Hook injection check** — hooks.json + hooks-handlers/ scripts for malicious patterns (arbitrary code execution, network exfiltration, file destructive operations)
4. **MCP server risk analysis** — MCP server configs for untrusted endpoints, suspicious command lines, environment variable leaks
5. **Skill / agent provenance** — verify skills/agents come from known sources (plugin install records, hash check against known-good versions?)
6. **CLAUDE.md content audit** — verify no production secrets / PII / internal-confidential content accidentally landed in CLAUDE.md

### 2.5 NOT in scope

- General codebase secrets scanning (use truffleHog, git-secrets, etc.)
- Repository-level security (use GitHub's own scanning, Snyk, etc.)
- Runtime monitoring (this is static analysis only)
- Replacing architect-critic (different concern)

### 2.6 Loose coupling

Standalone plugin. Works in any project. No dependencies on workspace-init manifest. Can OPTIONALLY read the manifest if present (e.g., check git_policy field for trace_filter status as a sanity check), but never required.

Composition with architect-critic: orthogonal. They can both be invoked independently. A user might run security-audit before kicking off architect-critic's adversarial spec review, or after, or never — no integration required in v0.1.

---

## 3. What's open — questions to brainstorm

### Q1 — Skill catalog precise definition

Candidate skills (2-3 target):

| Skill | Trigger | Scope |
|---|---|---|
| `auditing-claude-configs` | "audit my claude config", "security scan my .claude", "check for security issues" | Full audit across all 6 audit aspects (§2.4) |
| `scanning-for-secrets` | "scan for secrets in .claude", "check for leaked credentials" | Focused secrets-only audit |
| `reviewing-permissions` | "review my permissions", "audit settings.json grants" | Focused permission audit |

Brainstorm: is 3 skills right? Or 1 skill (auditing-claude-configs) with optional `--focus secrets|permissions|all` mode? Or 4-5 skills (one per audit aspect)?

### Q2 — Rule encoding mechanism

How are audit rules encoded? Options:

- **A. Hard-coded in skill body** — rules are described in markdown, Claude evaluates against config files
- **B. Externalized rule files** — `lib/rules/` directory with structured rule definitions (YAML, JSON, or bash scripts); skill body invokes rule runners
- **C. Hybrid** — high-level rules in skill body (Claude evaluates judgment-heavy rules); mechanical rules in lib/ scripts (regex-based pattern matching for known patterns)

ECC has 102 static analysis rules in AgentShield. Brainstorm: how many of our rules need to be externalized vs inline?

### Q3 — Output format

What does an audit report look like? Options:

- **Markdown audit report** — written to `<repo>/docs/security-audit-<date>.md` (or `.claude/audits/`); structured with findings per severity
- **In-conversation summary** — surfaces findings in chat; no file output by default
- **Both** — chat summary + optional file output via `--save` flag

How are findings categorized? (Critical / High / Medium / Low — same as adversarial review pattern?)

### Q4 — Severity rubric

Define severity per audit aspect:

| Aspect | Critical examples | Low examples |
|---|---|---|
| Secrets | API key in CLAUDE.md committed to git | Hardcoded localhost dev URL |
| Permissions | `"deny": []` (deny-nothing) + dangerous tools allowed | Slightly broader permission than needed |
| Hooks | Hook executes `rm -rf` or curl-pipe-bash | Hook references external script not in repo |
| MCP | Untrusted endpoint without auth | MCP server config has stale comment |

Brainstorm: what's the canonical rubric? Borrow from architect-critic's T=4 concession scoring style?

### Q5 — Composition with architect-critic

Orthogonal in v0.1 (both standalone). But could be tighter integration in v0.2:
- architect-critic invoked at slice-close could ALSO invoke security-audit on any new `.claude/` changes
- security-audit findings could be surfaced as challenges in critic's rebuttal cycle

For v0.1: keep orthogonal. Document the composition possibility for v0.2.

### Q6 — Composition with workspace-init

workspace-init's trace filter (commit-msg hook) blocks AI traces in COMMIT MESSAGES. claude-security-audit checks CONFIG FILES for SECRETS. Overlapping concern? Not really — trace filter is about authorship attribution; secret detection is about credential leaks. Different patterns, different files.

For v0.1: independent. Could share regex patterns library if both grow significantly.

### Q7 — Build sequence + test target

Pass D 8-phase pattern. Target test count: ~80-100 (smaller than architect-critic since narrower scope).

Brainstorm specifics:
- Phase 0: Evals (fixture projects with intentional security issues; verify skill detects each)
- Phase 1: SKILL.md bodies
- Phase 2: Reference sub-docs (rule catalog, severity rubric)
- Phase 3: Utility scripts (rule runners, secrets-pattern library, jq-based config parsers)
- Phase 4: Hooks (SessionStart could emit "last audit was N days ago" if state.json has audit history)
- Phase 5: Slash command wrappers (`/security-audit`, optionally `/secrets-scan` `/permissions-review`)
- Phase 6: Subagent pressure tests
- Phase 7: Integration tests (against real-world fixture projects)
- Phase 8: Publish v0.1.0

---

## 4. Reference material the new session should read

Order matters.

1. **This document** — full briefing
2. **ECC AgentShield** — https://github.com/affaan-m/everything-claude-code (specifically `commands/security-scan`, `the-security-guide.md`, `skills/agent-architecture-audit`)
3. **`docs/SPEC-architect-critic.md`** — for sibling-plugin patterns (audit framework, severity scoring, output format)
4. **`docs/SPEC-workspace-init.md`** — for hook installation patterns + manifest-aware design (useful for the optional manifest-aware mode)
5. **`docs/SPEC-scaffold-onboard.md`** — for skill-first composition examples
6. **Auto-memory** (always loaded; relevant individual files):
    - `project_post_spec_exploration_queue.md` — ECC research context + cherry-pick rationale
    - `project_skill_first_retrofit_queue.md` — Pass D skill-first principle
    - `feedback_brainstorm_artifacts_only_when_visual.md` — brainstorm style
    - `feedback_slash_command_dollar_n_bug.md` — slash wrapper bodies use `$ARGUMENTS`

---

## 5. Workflow conventions

- **Subagent-driven dev** per `superpowers:subagent-driven-development`
- **TDD non-negotiable**
- **Commit format**: `claude-security-audit: <description> (v0.1 Phase X)`. Single-line. No co-author trailer.
- **macOS portability adaptations** per scaffold-onboard playbook
- **Slash command bodies use `$ARGUMENTS`**
- **Phase-close commits update CHANGELOG + PLAN's Implementation Status**
- **License: MIT with ECC attribution**

---

## 6. First-session game plan

### Step 1 — Orient (15-20 min)

Read this document end-to-end. Browse ECC AgentShield source (specifically the security-scan command and any rule files). Read SPEC-architect-critic.md for sibling-audit-plugin patterns.

### Step 2 — Brainstorm (1-2 hours)

Invoke `superpowers:brainstorming`. Drive Q1-Q7. Prose-only.

### Step 3 — Author SPEC (1-2 hours)

Create `docs/SPEC-claude-security-audit.md`. Capture skill catalog + rule encoding + output format + severity rubric + composition.

### Step 4 — Author PLAN (1-2 hours)

Create `docs/PLAN-claude-security-audit.md` with full TDD breakdown.

### Step 5 — Begin implementation (multi-session)

`git checkout -b implementation-claude-security-audit`. Subagent-driven workflow.

---

## 7. Definition of done (claude-security-audit v0.1.0)

- All build phases complete
- 2-3 skills shipped (or whatever Q1 settles)
- Rule encoding mechanism functional
- Audit can detect: secrets, permission misconfigurations, hook injection, MCP risk
- Severity rubric documented + applied
- Output format clean (markdown + chat)
- ~80-100 tests passing
- `claude-security-audit-v0.1.0` tag pushed
- Marketplace entry added (sibling to architect-critic alphabetically)
- Root README plugin table updated
- License: MIT
- README attribution to ECC AgentShield (Mustafa, 2026; MIT)
- Standalone operation verified (no manifest dependency)

---

## 8. Opening message for the new session

To start the fresh session, paste this:

> Read `docs/HANDOFF-claude-security-audit-spec.md` end-to-end. This is a NEW plugin for our marketplace — `claude-security-audit` — inspired by AgentShield in Everything Claude Code (MIT, attribution-friendly). Sibling to architect-critic (different audit concern: security vs anti-sycophancy review). Scope: audit `.claude/` configs, secrets, permissions, hook injection, MCP risk. Skill-first per Pass D. Standalone — no dependency on workspace-init manifest. Use `superpowers:brainstorming` to drive Q1-Q7 in §3 to settled state, then author `docs/SPEC-claude-security-audit.md` and `docs/PLAN-claude-security-audit.md`, then begin implementation on a fresh `implementation-claude-security-audit` branch.
