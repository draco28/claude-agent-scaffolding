# SPEC: claude-security-audit plugin

**Status:** v0.1 design, settled 2026-05-24 via grill-me session against `docs/HANDOFF-claude-security-audit-spec.md` (Q1–Q7) + plan-mode gap critique (G1–G15) at `/Users/draco/.claude/plans/read-docs-handoff-claude-security-audit-velvet-dongarra.md`.

**Author:** Praveen Kumar Singh.

**Inspired by:** AgentShield in [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) (Mustafa, 2026; MIT). Independent MIT-licensed implementation tailored to a composable plugin marketplace; not a fork.

**License:** MIT (with ECC attribution in README + each skill body).

---

## 1. TL;DR

`claude-security-audit` is a **standalone, manual-trigger, static-analysis** plugin that audits a Claude Code project's `.claude/` configuration surface and the files of any plugins enabled in that project, for security risks: hook injection, agent / slash-command prompt-injection, MCP misconfiguration, permission misgrants, accidentally-committed secrets, settings *schema* validity (typo'd field names that silently disable enforcement), and `settings.local.json` silent permission broadening.

**Scope honesty up front.** v0.1 uses bash + jq + regex (no AST yet). It reliably catches **common, unobfuscated patterns** — accidentally-committed secrets, plain-text dangerous hooks, broad permission grants, missing `deny` clauses, settings-schema typos. A determined adversary who obfuscates (base64, eval indirection, dynamic command construction) will evade most v0.1 rules; **AST-based detection for hooks/agents/commands is v0.2**. Realistic primary value of v0.1 is therefore the *secondary-threat* surface: accidental friendly-fire (committed keys), malicious-teammate PRs that aren't trying hard to hide, and pre-publish hygiene checks when open-sourcing a Claude project. The *compromised marketplace plugin* case is supported (and the day-one **NEW since last run** badge is its most valuable signal) but framed as "catches common patterns; not a defense against sophisticated supply-chain attackers."

It is **purely static** (the plugin that detects exfiltration risk must not itself be one — no LLM evaluation over raw file bytes, no remote dispatch on file content) and **per-finding-consented for auto-fix** (advisory by default; the user opts in to apply a safe-category fix via durable `finding_uid`).

**Zero ambient surface by default.** No hooks declared in the plugin manifest — the SessionStart "last audit N days ago" reminder ships as an **opt-in** hook file users can wire into their own settings if they want it. Default install puts shell on disk but does not register it to fire on any event.

Day-one proof-of-value: a user installs a new plugin, runs `/security-audit`, and gets a concrete chat summary plus a markdown report at `.claude/audits/<date>-<NN>.md` with **NEW since last run** badges (keyed on durable `finding_uid`) showing exactly what the new plugin introduced — at the v0.1 detection fidelity caveated above.

---

## 2. Motivation

The Claude Code plugin marketplace is a growing supply-chain attack surface. A user runs `/plugin install some-thing` and that plugin's files land at `~/.claude/plugins/cache/<name>/<version>/` with full execution authority in subsequent Claude Code sessions — hooks fire on `SessionStart`, slash commands inject arbitrary instructions into the conversation, agent definitions can carry exfiltration patterns in their system prompts, MCP server configs can point to untrusted endpoints.

Nothing in the current marketplace audits this surface. ECC's AgentShield demonstrates the gap is real (1,282 tests + 102 static rules in their bundled mega-plugin), but their packaging is monolithic; the composable-plugins thesis of this marketplace warrants an independent, focused, MIT-licensed alternative that ships as a single-concern plugin sibling to `architect-critic` (which addresses a different audit concern: anti-sycophancy on specs and plans).

Secondary motivation: the marketplace operators (us) can eat our own dog food, running `/security-audit` on each of our own plugins before publishing — a natural pre-release gate.

---

## 3. Goals & non-goals

### Goals

- Detect **common, unobfuscated patterns** across the project's `.claude/` and the enabled-plugin set: secrets in plaintext, dangerous hook shell, overly-broad permission allow patterns, missing deny clauses, settings-schema typos that silently disable enforcement, MCP misconfiguration, prompt-injection in agent/command bodies, `settings.local.json` divergence.
- Provide **first-line defense** against (in approximate v0.1 fidelity order):
  - *Secondary threats* — accidental friendly-fire (API key committed in `CLAUDE.md`), malicious-teammate PR that isn't trying hard to hide, pre-publish hygiene checks before open-sourcing a Claude project. **These are the realistic primary value of v0.1.**
  - *Compromised marketplace plugin* with **common** attack patterns — direct `curl … | bash`, plain-text exfiltration in agent prompts, etc. **NOT** a defense against a sophisticated supply-chain attacker who obfuscates payloads; that requires the AST-based detection scheduled for v0.2.
- Ship **durable `finding_uid` + per-report `display_id`** so users can reference findings across runs for auto-fix or suppression even when whitespace edits change line numbers.
- Provide **NEW / PERSISTED / SUPPRESSED** lifecycle states across runs, so users can quickly see "what changed since my last audit" — the single highest-value question for a manual-trigger tool.
- Offer **safe-category auto-fix** with strict per-finding consent: user types `/apply-fix SA-...-XXX` (or the equivalent chat phrasing) → plugin applies *one* fix from a bounded safe-category list, never to attacker-controlled files. Two-flag system: `RULE_AUTO_FIXABLE` (target path is in the safe-write set) AND `MECHANICALLY_FIXABLE` (the fix recipe is derivable without human judgment) must both be true.
- Stay **static**: bash + jq + regex (no AST in v0.1; AST is v0.2). No LLM evaluation over raw file bytes. No subagent or codex dispatch.
- **Zero ambient surface by default**: no hooks declared in the plugin manifest; the SessionStart "last audit N days" reminder is an opt-in shell file users wire in manually.
- Compose **orthogonally** with sibling plugins (`architect-critic`, `workspace-init`, `scaffold-onboard`, `scaffold-dev`): no required dependency on any of them; works in any project.

### Non-goals

- **Detection of determined adversaries who obfuscate** (base64 payloads, eval indirection, dynamic command construction, splice via includes). Explicitly out-of-scope for v0.1; deferred to v0.2 with AST-based detection.
- **Plugin provenance / hash-drift verification.** v0.1 has no trust root for plugin manifests, no signed marketplace metadata, no expected-hash source — and the spec forbids runtime fetches that could provide one. Deferred to v0.2 with a designed trust-root mechanism. (The `lib/rules/provenance/` directory does NOT ship in v0.1.)
- **General codebase secret scanning** (use `truffleHog`, `git-secrets`, GitHub secret scanning). This plugin audits the `.claude/` configuration surface, not arbitrary source files.
- **Repository-level vulnerability scanning** (use GitHub Dependabot, Snyk, GHAS).
- **Runtime monitoring** of Claude Code sessions. This is purely static analysis of files at rest.
- **CI / pre-commit integration** in v0.1 — deferred to v0.2 with the exit-code semantics design that requires.
- **Auto-fix outside the safe-category list** — never modify hooks, agents, commands, MCP configs, or installed-plugin files. The response for those is "uninstall and report to maintainer."
- **Replacing `architect-critic`** — `architect-critic` audits *specs and plans* adversarially for sycophancy; `claude-security-audit` audits *configuration files* for security risks. Different concerns; both can run.
- **Replacing AgentShield** — ECC ships their version bundled in a mega-plugin; this is the standalone alternative for users who want a single-concern composable plugin.

---

## 4. Threat model

Explicit threat model, in priority order. Rule severity and feature scope follow from this.

### 4.1 Primary threat: compromised marketplace plugin (common-pattern subset only in v0.1)

The user runs `/plugin install some-thing` from a marketplace they do not fully trust (or from a trusted marketplace that has been compromised at the source). The plugin's files land in `~/.claude/plugins/cache/<name>/<version>/` and are activated for subsequent sessions in any project where the user enables them. The attacker now has hooks that fire on `SessionStart`, slash commands the user may invoke (and which contain arbitrary instructions to Claude), agent definitions whose system prompts may instruct exfiltration, and MCP server configs that may point to attacker endpoints.

**v0.1 scope honesty:** Rules in v0.1 are regex-based, not AST-based. They catch **common, unobfuscated patterns** in compromised-plugin assets — direct `curl ... | bash`, plain-text exfiltration in agent prompts, missing MCP auth, untrusted endpoint URLs, etc. They will **not reliably catch** a determined adversary who obfuscates: base64-encoded payloads, eval indirection, dynamic command construction, splice-via-includes, deliberately-malformed regex bait, etc. That class of attacker is explicitly **out of v0.1 scope** and is the primary motivation for v0.2's AST-based detection.

**Practical positioning of v0.1 vs the primary threat:** the day-one **NEW since last run** badge after a `/plugin install` is real value (you learn *something* about what the plugin added even if rules miss obfuscated payloads). But users should not treat a clean `/security-audit` as "this plugin is safe to trust" — only as "this plugin doesn't trip our v0.1 common-pattern rules." This caveat ships in the README and in the chat-summary footer of every report.

### 4.2 Secondary threats

- **Malicious teammate PR**: a teammate adds a hook or agent definition to the project's own `.claude/` that exfiltrates on next session start. Detected by the same rule set, with the convenience that the project repo's git history surfaces *who* introduced the file.
- **Accidental friendly-fire**: a developer pastes an API key into `CLAUDE.md`, commits it. Detected by the secrets module.
- **Public-repo exposure**: a user open-sources a Claude project that has secrets in `.claude/` or overly-permissive settings. Detected pre-publish if the user runs an audit before pushing.

### 4.3 Out-of-threat-model

- Runtime attacks during an active Claude Code session (no monitoring in v0.1).
- Network-based attacks on Claude Code itself.
- Side-channel attacks (cache timing, etc.).
- Attacks on the audit plugin's own files (covered by the integrity of the plugin install path, not by self-audit).

### 4.4 Meta-risk constraint (G3 lock)

The audit reads files that, per §4.1, may be attacker-controlled. The plugin detecting exfiltration must not *itself* be an exfiltration risk. Three locked constraints:

- **Static analysis only.** No LLM evaluation reads raw file bytes. The skill body reasons about the *audit report* (counts, severity rollups, summary prose) — never the raw bytes.
- **Findings are redacted.** Matches are reported as `file:line:offset` with previews redacted (e.g., `sk-ant-***...***xyz` showing only first-4 + last-4 chars). Never full secret material in chat output or the report file.
- **No remote dispatch.** No `Task` subagent calls, no codex subprocess, no network fetch *on file content*. Stricter than `architect-critic` by design; the threat model demands it.

---

## 5. Audit aspects

Seven aspects in v0.1 scope. The six from the handoff §2.4, plus one added during plan-mode gap critique (prompt injection per G2). The "skill/agent provenance" aspect originally listed in the handoff is deferred to v0.2 (no trust root in v0.1; see §3 non-goals).

| # | Aspect | Files scanned | Example detections |
|---|---|---|---|
| 5.1 | Secrets | `CLAUDE.md`, `.claude/**/*.{md,json,sh,py,js,ts}`, enabled-plugin files | API keys, OAuth tokens, JWTs, env-var leaks, base64-credential patterns (common forms; not full base64-payload-intent analysis) |
| 5.2 | Permissions (values + **schema**) | `.claude/settings.json`, `.claude/settings.local.json`, `~/.claude/settings.json` (read-only) | Overly broad allow patterns, missing deny clauses, dangerous tool combinations, **settings-schema typos** (e.g., `"allowed"` instead of `"allow"`, unknown top-level keys, structural divergence from the Claude Code permission schema) |
| 5.3 | Hook injection (common patterns) | `.claude/hooks.json`, `.claude/hooks-handlers/**`, enabled-plugin `hooks/**` | `curl ... \| bash`, `rm -rf`, unbounded `eval`, plain-text network exfiltration patterns. (Obfuscated shell is v0.2 with AST.) |
| 5.4 | MCP server risk | `.mcp.json`, `.claude/mcp/*.json`, enabled-plugin MCP configs | Untrusted endpoints (non-allowlist domains, http://), missing auth, suspicious command lines, env-var leaks in args |
| 5.5 | CLAUDE.md content | Project `CLAUDE.md`, nested `CLAUDE.md` in subdirs | Plaintext secrets, internal-confidential markers, PII patterns |
| 5.6 | Agent / command prompt injection (G2; common patterns) | `.claude/agents/*.md`, `.claude/commands/*.md`, enabled-plugin equivalents | System prompts containing recognizable exfiltration instructions, slash commands chaining destructive operations, known prompt-injection payload signatures. (Semantic-intent analysis is v0.2.) |
| 5.7 | Marketplace integrity (G2) | `.claude-plugin/marketplace.json`, `~/.claude/plugin-marketplace.json` | Pinned marketplaces with non-HTTPS or non-allowlist URLs, malformed marketplace JSON, plugins referenced but not pinned to a versioned source |

`settings.local.json` is *always* in scope (it can silently broaden `settings.json` and is typically gitignored — exactly the kind of asymmetric trust the threat model targets).

Schema-validation rules in 5.2 are particularly high-value: a misspelled field name (e.g., `"allowed"` instead of `"allow"`) is silently ignored by Claude Code, leaving the user with NO enforcement of what they wrote. v0.1 maintains an internal allowlist of valid Claude Code settings keys (pinned in `lib/rules/permissions/_known-keys.txt`; updated per Claude Code release).

---

## 6. Architecture overview

```
                       ┌────────────────────────────────────┐
   user invocation     │  Slash command thin wrappers       │
   ───────────────────►│  /security-audit                   │
                       │  /secrets-scan                     │
                       │  /permissions-review               │
                       │  /apply-fix <id>                   │
                       └─────────────┬──────────────────────┘
                                     │  $ARGUMENTS
                                     ▼
                       ┌────────────────────────────────────┐
                       │  skill: auditing-claude-configs    │
                       │  (orchestration + presentation)    │
                       │                                    │
                       │  - parses focus mode               │
                       │  - enumerates scan targets         │
                       │  - dispatches lib/ rule runners    │
                       │  - merges findings                 │
                       │  - applies baseline + suppression  │
                       │  - renders chat summary + report   │
                       │  - handles apply-fix flow          │
                       └─────────────┬──────────────────────┘
                                     │  shell calls
                                     ▼
                       ┌────────────────────────────────────┐
                       │  lib/                              │
                       │  ├── enumerate-targets.sh          │
                       │  ├── rules/<aspect>/*.sh           │
                       │  ├── rule-engine.sh                │
                       │  ├── fingerprint.sh                │
                       │  ├── severity.sh                   │
                       │  ├── redact.sh                     │
                       │  ├── state.sh                      │
                       │  ├── suppress.sh                   │
                       │  ├── baseline.sh                   │
                       │  ├── report-render.sh              │
                       │  └── apply-fix.sh                  │
                       └─────────────┬──────────────────────┘
                                     │  reads + writes
                                     ▼
                       ┌────────────────────────────────────┐
                       │  .claude/audits/                   │
                       │  ├── state.json                    │
                       │  ├── suppressions.json             │
                       │  └── <date>-<NN>.md                │
                       └────────────────────────────────────┘

   OPT-IN (not in default install) SessionStart reminder:
   ┌────────────────────────────────────┐
   │  hooks/session-start-reminder.sh   │  reads state.json + diffs enabled-plugin
   │  (one jq read, no audit)           │  set; emits one-line nudge if stale
   │  SHIPPED AS FILE — NOT DECLARED    │  User must add to ~/.claude/settings.json
   │  IN plugin.json manifest           │  manually if they want the reminder.
   └────────────────────────────────────┘
```

**Why opt-in:** v0.1's threat model (§4) flags plugin-installed SessionStart hooks as a Critical attack surface. The plugin therefore does not register one on the user's behalf — that would put the plugin's own shell into the very surface its rules treat as high-severity, creating a self-referential inconsistency and adding ambient cost to every Claude Code session in every project. Users who want the reminder add a 3-line snippet (documented in the README) to their own `settings.json`. The file is shipped so the user doesn't have to author it; the registration is theirs.

### 6.1 Plugin manifest

```jsonc
// claude-security-audit/.claude-plugin/plugin.json
{
  "name": "claude-security-audit",
  "version": "0.1.0",
  "description": "Static-analysis security audit for Claude Code project configurations and enabled plugins.",
  "author": "Praveen Kumar Singh",
  "license": "MIT",
  "homepage": "<repo url>",
  "skills": [
    { "name": "auditing-claude-configs", "path": "skills/auditing-claude-configs/SKILL.md" }
  ],
  "commands": [
    { "name": "security-audit", "path": "commands/security-audit.md" },
    { "name": "secrets-scan", "path": "commands/secrets-scan.md" },
    { "name": "permissions-review", "path": "commands/permissions-review.md" },
    { "name": "apply-fix", "path": "commands/apply-fix.md" }
  ]
  // NOTE: no "hooks" array. hooks/session-start-reminder.sh ships in the plugin
  // directory but is NOT registered by the manifest. Users who want the
  // "last audit N days ago" reminder add it to their own ~/.claude/settings.json
  // manually per the README. See §6 above on why opt-in.
}
```

### 6.2 Directory layout

```
claude-security-audit/
├── .claude-plugin/
│   └── plugin.json
├── README.md                         # includes ECC attribution
├── CHANGELOG.md
├── LICENSE                           # MIT
├── skills/
│   └── auditing-claude-configs/
│       ├── SKILL.md                  # orchestration + presentation logic
│       └── references/
│           ├── threat-model.md       # §4 of this spec, distilled
│           ├── severity-rubric.md    # §8 distilled with examples
│           └── auto-fix-policy.md    # §9 boundary + grant pattern
├── commands/
│   ├── security-audit.md             # /security-audit  $ARGUMENTS → skill
│   ├── secrets-scan.md               # focus=secrets
│   ├── permissions-review.md         # focus=permissions
│   └── apply-fix.md                  # /apply-fix <id>
├── hooks/
│   └── session-start-reminder.sh     # passive reminder, NOT an audit
├── lib/
│   ├── enumerate-targets.sh
│   ├── rule-engine.sh
│   ├── fingerprint.sh
│   ├── severity.sh
│   ├── redact.sh
│   ├── state.sh
│   ├── suppress.sh
│   ├── baseline.sh
│   ├── report-render.sh
│   ├── apply-fix.sh
│   ├── helpers.sh                    # cross-platform sha256, sed -i, etc.
│   └── rules/
│       ├── secrets/                  # 5.1
│       │   ├── api-keys.sh
│       │   ├── jwt.sh
│       │   ├── env-var-leak.sh
│       │   └── base64-credentials.sh
│       ├── permissions/              # 5.2
│       │   ├── _known-keys.txt        # allowlist of valid Claude Code settings keys
│       │   ├── broad-allow.sh
│       │   ├── missing-deny.sh
│       │   ├── settings-local-divergence.sh
│       │   ├── settings-schema-validation.sh  # PERM-005: typo'd field detection
│       │   └── dangerous-combo.sh
│       ├── hooks/                    # 5.3 (common patterns only; AST is v0.2)
│       │   ├── curl-pipe-bash.sh
│       │   ├── rm-rf.sh
│       │   ├── unbounded-eval.sh
│       │   └── network-exfiltration.sh
│       ├── mcp/                      # 5.4
│       │   ├── untrusted-endpoint.sh
│       │   ├── missing-auth.sh
│       │   └── env-var-leak.sh
│       ├── claude-md/                # 5.5
│       │   ├── plaintext-secrets.sh
│       │   └── internal-markers.sh
│       ├── prompt-injection/         # 5.6 (common patterns only; semantic-intent is v0.2)
│       │   ├── agent-exfiltration.sh
│       │   └── command-chain-destructive.sh
│       └── marketplace/              # 5.7
│           ├── untrusted-source.sh
│           └── malformed-marketplace.sh
├── fixtures/
│   ├── clean/                        # 5 fixture projects, must produce ZERO findings
│   │   ├── empty-project/
│   │   ├── minimal-project/
│   │   ├── standard-project/
│   │   ├── plugin-using-project/
│   │   └── teamworkflow-project/
│   └── issues/                       # 8 fixture projects (one per v0.1 aspect + dedicated schema-typo)
│       ├── secrets-issue/
│       ├── permissions-issue/
│       ├── permissions-schema-typo/  # for PERM-005 specifically (T1-E)
│       ├── hook-injection/
│       ├── mcp-misconfigured/
│       ├── claude-md-secret/
│       ├── prompt-injection-agent/
│       └── marketplace-untrusted/
└── tests/
    ├── test-enumerate-targets.sh
    ├── test-rule-engine.sh
    ├── test-fingerprint.sh
    ├── test-severity.sh
    ├── test-redact.sh
    ├── test-state.sh
    ├── test-suppress.sh
    ├── test-baseline.sh
    ├── test-report-render.sh
    ├── test-apply-fix.sh
    ├── test-rules-secrets.sh
    ├── test-rules-permissions.sh
    ├── test-rules-permissions-schema.sh   # PERM-005 dedicated coverage
    ├── test-rules-hooks.sh
    ├── test-rules-mcp.sh
    ├── test-rules-claude-md.sh
    ├── test-rules-prompt-injection.sh
    ├── test-rules-marketplace.sh
    ├── test-fixtures-clean.sh        # asserts zero findings on each clean fixture
    ├── test-fixtures-issues.sh       # asserts expected findings on each issue fixture
    ├── test-e2e-audit.sh
    ├── test-e2e-apply-fix.sh
    ├── test-e2e-suppress.sh
    ├── test-e2e-baseline.sh
    ├── test-e2e-tamper-detection.sh  # T1-F: state/suppressions tampering warnings
    ├── test-malicious-rule.sh        # T2-H: rule that lies about RULE_AUTO_FIXABLE
    ├── test-finding-uid-stability.sh # T2-I: finding_uid survives whitespace/line edits
    ├── test-rule-load-failure.sh     # T2-G: rule-load failure surfaces as High
    └── _helpers.sh
```

### 6.3 Enumerate-targets resolution algorithm (T2-J pin)

`lib/enumerate-targets.sh` resolves the audit's scan target list deterministically. Pinned algorithm:

```
1. PROJECT_TARGETS:
   - Include every file under "$PWD/.claude/" matching the per-aspect glob patterns
     (e.g., **/*.{md,json,sh,py,js,ts}; aspect rules narrow further).
   - Include $PWD/CLAUDE.md and nested CLAUDE.md files in subdirs.
   - Include $PWD/.claude-plugin/marketplace.json if present.
   - Skip files matched by per-target ignore globs (see §13 edge cases).

2. ENABLED_PLUGINS_SET:
   a. Parse $PWD/.claude/settings.json for the "enabledPlugins" array (or whatever
      the current Claude Code settings key is — version-sensitive; pinned via a
      Phase-0 discovery test in claude-security-audit's own test suite).
   b. Parse $HOME/.claude/settings.json for the same key (user-global enabled set).
   c. Union the two arrays. Project-local takes precedence on per-plugin overrides
      if both sources declare conflicting state (matches Claude Code's own precedence).
   d. For each plugin name, resolve its filesystem path:
        - First try: $HOME/.claude/plugins/cache/<plugin>/<active-version>/
          where <active-version> is read from $HOME/.claude/plugins/cache/<plugin>/.active
          (or the lone version directory if .active is missing).
        - Fallback (locally-developed plugin not in cache):
          check $HOME/.claude/plugins/local/<plugin>/ for a symlink or directory.
          If found, scan that path with a banner: "[local-dev]" prefix on findings.
          (Supports the "us auditing our own marketplace pre-publish" use case
          for the marketplace operator developing plugins outside cache.)
        - If neither resolves: emit High-severity finding PROVENANCE-002 —
          "Plugin <name> is enabled but not installed at expected path."

3. SCAN_SET = PROJECT_TARGETS ∪ (files under each ENABLED_PLUGIN path that match
   per-aspect globs).

4. PARANOID_CANDIDATES (NOT scanned by default; counted for the Info finding):
   - List every directory under $HOME/.claude/plugins/cache/* that is NOT in
     ENABLED_PLUGINS_SET. These are plugins installed in cache but not enabled
     in this project. Count them; emit Info finding INFO-PARANOID-001 if count > 0:
     "N other plugins exist in cache not enabled here — run /security-audit --paranoid to scan them."
     (Surfaces the gap codex T2-L flagged: users often enable plugins later or
     forget; the Info finding reminds them.)
```

**Phase-0 discovery responsibility:** the exact JSON path for the "enabled plugins" array in Claude Code settings is version-sensitive. v0.1's Phase 0 includes a test that parses a known-good fixture settings.json and asserts the discovered path matches the expectation; if Claude Code changes the schema, the test fails loudly and we update the parser in one place.

**Cross-platform note:** path resolution uses `realpath` (GNU) on Linux, `realpath` (BSD, available in macOS 13+) on macOS; `lib/helpers.sh` wraps with fallback to a pure-bash implementation for older macOS.

---

## 7. Commands

All slash command bodies use `$ARGUMENTS` per `feedback_slash_command_dollar_n_bug` (Claude Code substitutes `$1`/`$2`/etc. at template-render time, silently breaking positional bash).

### 7.1 `/security-audit [--focus <aspect>] [--verbose] [--show-suppressed]`

Primary entry point. Full audit by default; `--focus` narrows to one aspect group (`secrets`, `permissions`, `hooks`, `mcp`, `provenance`, `claude-md`, `prompt-injection`, `marketplace`).

**Body** (illustrative):

```bash
# commands/security-audit.md (the body, not the frontmatter)
The user wants to run a security audit.

Read $ARGUMENTS for optional flags.

Invoke the auditing-claude-configs skill in audit-mode with these arguments.
```

**Flow:**
1. Skill body parses `$ARGUMENTS` to determine focus mode + verbosity.
2. **First-run gitignore bootstrap (T1-D).** If `.claude/audits/state.json` does not exist (first audit ever in this project):
   a. Check whether `.gitignore` exists in project root.
   b. If `.gitignore` exists and does NOT contain a pattern matching `.claude/audits/`, append:
      ```
      # claude-security-audit
      .claude/audits/
      ```
      Print: `"Added .claude/audits/ to your .gitignore (first audit; this directory will contain reports with sensitive metadata)."`
   c. If `.gitignore` does NOT exist, create it with the above content and print: `"Created .gitignore with .claude/audits/ entry."`
   d. If `.gitignore` already covers `.claude/audits/` (via direct entry, wildcard, or parent-dir gitignore), do nothing silently.
   e. If `.gitignore` exists but is not writable (permissions issue, read-only mount, no project root detected, etc.), print High-severity warning: `"Cannot write to .gitignore at <path>. Audit reports may be committed to git. Add '.claude/audits/' to your .gitignore manually."` and continue with the audit.
   f. Handles nested git repos: walk up from $PWD looking for the nearest `.git` directory; place `.gitignore` in that repo's root. If no git repo found (project isn't versioned), print Info: `"No git repository found; .claude/audits/ will not be gitignored (no .gitignore created). Reports are local-only."`
3. `lib/enumerate-targets.sh` builds the scan target list per the algorithm pinned in §6.3 (project `.claude/` + enabled-plugin dirs from settings).
4. `lib/rule-engine.sh` iterates target files × applicable rules, collecting raw findings.
5. `lib/fingerprint.sh` computes both `finding_uid` (durable) and `dedup_fingerprint` (per-run) per §9.1.
6. `lib/baseline.sh` tags each finding NEW / PERSISTED based on state.json `findings` registry (T2-I).
7. `lib/suppress.sh` filters out suppressed findings (unless `--show-suppressed`).
8. `lib/report-render.sh` writes `.claude/audits/<date>-<NN>.md` and returns the chat summary.
9. `lib/state.sh` updates `state.json` (last-audit-date, `findings` registry with GC per T2-K, `self_integrity.state_mtime_at_last_audit` per T1-F, audit-history append).
10. If any rules failed to load (T2-G), include a prominent banner in chat summary: `"⚠ N rule(s) failed to load; results incomplete. See report for SCANNER-001 findings."`
11. Skill body emits the chat summary inline.

### 7.2 `/secrets-scan [--verbose]`

Equivalent to `/security-audit --focus secrets`. Thin wrapper for natural-language matching ("scan for leaked credentials").

### 7.3 `/permissions-review [--verbose]`

Equivalent to `/security-audit --focus permissions`. Thin wrapper for natural-language matching ("review my permissions").

### 7.4 `/apply-fix <finding-id>`

Apply one safe-category fix. Per-finding consent (Q9 lock).

**Two ID types accepted:**
- **`display_id`** (e.g., `SA-2026-05-24-013`) — per-report ordinal; convenient when the user is reading the latest report in the same session.
- **`finding_uid`** (e.g., `FUID-a3f9b21c`) — durable across runs; survives whitespace edits, line-number drift, redaction-context changes. Recommended for any reference that crosses sessions.

The skill body's argument parser accepts either form (regex matches both prefixes).

**Flow:**
1. Skill body parses `$ARGUMENTS` to extract the finding ID (either form).
2. `lib/apply-fix.sh` resolves the ID:
   - If it's a `display_id`, look it up in the latest report file → resolve to `finding_uid`.
   - If it's already a `finding_uid`, use it directly.
3. Loads the finding's full record from `state.json` (durable; survives report-file deletion).
4. Validates: (a) finding exists, (b) finding has a `fix_recipe`, (c) the rule has BOTH `RULE_AUTO_FIXABLE=true` (target path is in safe-write set per §9.2) AND `MECHANICALLY_FIXABLE=true` (fix recipe is derivable without human judgment), (d) the fix recipe's resolved target file path is *still* in the safe-write allowlist (defense-in-depth re-validation, in case a rule lies in its declarations).
5. Executes the fix recipe (declarative shell snippet attached to the rule).
6. Updates `state.json` with `{ finding_uid, display_id_at_apply, fix_applied_at, fix_applied_by, fix_summary }` audit trail.
7. Prints `"Applied SA-2026-05-24-013 (FUID-a3f9b21c): <one-line summary of what changed>"`.

If the finding's rule fails any of the validation checks in step 4, refuse with one of:
- `"Auto-fix not supported for this finding (rule has RULE_AUTO_FIXABLE=false). Recommended action: <verbal instruction from rule>."`
- `"Auto-fix not supported for this finding (rule has MECHANICALLY_FIXABLE=false — fix requires human judgment). Recommended action: <verbal instruction from rule>."`
- `"Internal safety check failed — fix target <path> not in safe-write allowlist. Report this as a bug."` (should never trigger if the rule is correctly authored; if it does, the rule is misconfigured or malicious)

---

## 8. Schemas

### 8.1 Rule definition (declarative shell)

Each rule is a single `.sh` file in `lib/rules/<aspect>/<rule-name>.sh`. The file declares metadata via well-known variables, then defines a `detect` function (and optionally a `fix` function).

**Metadata fields:**

| Field | Type | Required | Purpose |
|---|---|---|---|
| `RULE_ID` | string | yes | Unique identifier, format `<ASPECT>-<NNN>` |
| `RULE_NAME` | string | yes | Short kebab-case slug for filename matching |
| `RULE_ASPECT` | string | yes | One of: `secrets`, `permissions`, `hooks`, `mcp`, `claude-md`, `prompt-injection`, `marketplace` |
| `RULE_SEVERITY` | enum | yes | `critical` \| `high` \| `medium` \| `low` \| `info` |
| `RULE_DESCRIPTION` | string | yes | One-sentence what-and-why |
| `RULE_AUTO_FIXABLE` | bool | yes | `true` iff the rule's fix target path is in the §9.2 safe-write allowlist. `false` for attacker-controlled / execution-sensitive categories. |
| `RULE_MECHANICALLY_FIXABLE` | bool | yes | `true` iff the fix recipe is derivable without human judgment (e.g., append a fixed line to .gitignore). `false` if narrowing requires context-dependent choice (e.g., narrowing `Bash(*)` — what to narrow TO depends on user intent). **Both flags must be true for `/apply-fix` to act.** |
| `RULE_REMEDIATION` | string | yes | Verbal instructions for the user; shown in the report regardless of auto-fix availability. |
| `RULE_REFERENCES` | string | optional | URL(s) to OWASP / CWE / etc. for context |

**Example (regex-detection rule, no auto-fix):**

```bash
#!/usr/bin/env bash
# lib/rules/hooks/curl-pipe-bash.sh

RULE_ID="HOOK-001"
RULE_NAME="curl-piped-to-bash"
RULE_ASPECT="hooks"
RULE_SEVERITY="critical"
RULE_DESCRIPTION="Hook script pipes network fetch directly to shell execution."
RULE_AUTO_FIXABLE="false"            # attacker-controlled file class
RULE_MECHANICALLY_FIXABLE="false"    # judgment required even if path were safe
RULE_REMEDIATION="Remove the curl|bash pattern. If the hook came from an installed plugin, uninstall via /plugin uninstall <name> and report to the maintainer."
RULE_REFERENCES="https://owasp.org/www-community/attacks/Command_Injection"

detect() {
  local target_file="$1"
  # Returns 0 with findings on stdout (one JSON object per line), or 0 with no output if clean.
  grep -nE 'curl[[:space:]].*\|[[:space:]]*(bash|sh|zsh)' "$target_file" 2>/dev/null \
    | while IFS=: read -r line_no match; do
        local offset
        offset=$(echo "$match" | awk '{print index($0, "curl") - 1}')
        local preview
        preview=$(echo "$match" | "$LIB_DIR/redact.sh" --pattern-aware --max-len 80)
        jq -nc \
          --arg rule_id "$RULE_ID" \
          --arg file "$target_file" \
          --argjson line "$line_no" \
          --argjson offset "$offset" \
          --arg preview "$preview" \
          --arg severity "$RULE_SEVERITY" \
          '{rule_id: $rule_id, file: $file, line: $line, offset: $offset, preview: $preview, severity: $severity}'
      done
}
```

Rules with `RULE_AUTO_FIXABLE="true"` AND `RULE_MECHANICALLY_FIXABLE="true"` also define a `fix` function:

```bash
fix() {
  local target_file="$1"
  local context_json="$2"   # full finding JSON for context
  # Performs the fix. Returns 0 on success, non-zero on failure.
  # MUST only write to files in the safe-category set (re-validated by apply-fix.sh before calling).
}
```

A rule with `RULE_AUTO_FIXABLE="true"` but `RULE_MECHANICALLY_FIXABLE="false"` does NOT define a `fix` function; `/apply-fix` refuses with the dedicated "requires human judgment" message and the user follows `RULE_REMEDIATION`.

**Example (schema-validation rule, target is user-owned but fix needs judgment — PERM-005):**

```bash
#!/usr/bin/env bash
# lib/rules/permissions/settings-schema-validation.sh

RULE_ID="PERM-005"
RULE_NAME="settings-schema-validation"
RULE_ASPECT="permissions"
RULE_SEVERITY="high"
RULE_DESCRIPTION="settings.json contains keys not in the known Claude Code permission schema (typos silently disable enforcement)."
RULE_AUTO_FIXABLE="true"             # settings.json is in safe-write set
RULE_MECHANICALLY_FIXABLE="false"    # rename? delete? keep? user must choose
RULE_REMEDIATION="Review the unknown key. If it's a typo of a valid key (e.g., 'allowed' → 'allow'), rename it. If intentional metadata, move it under a known wrapper key."
RULE_REFERENCES=""

detect() {
  local target_file="$1"
  [[ "$(basename "$target_file")" =~ ^settings(\.local)?\.json$ ]] || return 0
  local known_keys
  known_keys="$(cat "$LIB_DIR/rules/permissions/_known-keys.txt")"
  jq -r --arg known "$known_keys" '
    paths(scalars) | select(length == 1) | .[0]
    | select(. as $k | $known | split("\n") | index($k) | not)
  ' "$target_file" 2>/dev/null \
    | while read -r unknown_key; do
        [[ -z "$unknown_key" ]] && continue
        jq -nc \
          --arg rule_id "$RULE_ID" \
          --arg file "$target_file" \
          --arg severity "$RULE_SEVERITY" \
          --arg unknown_key "$unknown_key" \
          '{rule_id: $rule_id, file: $file, line: 1, offset: 0, preview: ("\""+$unknown_key+"\": ..."), severity: $severity, context: {unknown_key: $unknown_key}}'
      done
}
# No fix() — MECHANICALLY_FIXABLE=false.
```

**Example (target is user-owned AND fix is always-correct — GITIGNORE-001):**

```bash
#!/usr/bin/env bash
# lib/rules/secrets/missing-gitignore-audits.sh   (aspect TBD in PLAN; illustrative)

RULE_ID="GITIGNORE-001"
RULE_NAME="missing-gitignore-audits-dir"
RULE_ASPECT="secrets"
RULE_SEVERITY="high"
RULE_DESCRIPTION=".claude/audits/ contains audit reports with sensitive metadata, but is not gitignored — reports will be committed."
RULE_AUTO_FIXABLE="true"             # .gitignore is in safe-write set
RULE_MECHANICALLY_FIXABLE="true"     # always-correct fix: append the line
RULE_REMEDIATION="Add '.claude/audits/' to your .gitignore."
RULE_REFERENCES=""

detect() {
  local project_root="$1"
  [[ -d "$project_root/.claude/audits" ]] || return 0
  local gitignore="$project_root/.gitignore"
  if [[ ! -f "$gitignore" ]] || ! grep -qE '^\.claude/audits/?' "$gitignore" 2>/dev/null; then
    jq -nc \
      --arg rule_id "$RULE_ID" \
      --arg file "$gitignore" \
      --arg severity "$RULE_SEVERITY" \
      '{rule_id: $rule_id, file: $file, line: 0, offset: 0, preview: "(no entry for .claude/audits/)", severity: $severity}'
  fi
}

fix() {
  local target_file="$1"
  local context_json="$2"
  # apply-fix.sh has already validated target_file is in safe-write allowlist.
  if [[ ! -f "$target_file" ]]; then
    printf '# claude-security-audit\n.claude/audits/\n' > "$target_file"
  elif ! grep -qE '^\.claude/audits/?' "$target_file" 2>/dev/null; then
    printf '\n# claude-security-audit\n.claude/audits/\n' >> "$target_file"
  fi
}
```

### 8.2 `state.json`

Located at `.claude/audits/state.json`. Tracks audit history, the durable finding-uid registry (used by baseline diff), and self-tamper-detection metadata.

```jsonc
{
  "schema_version": 2,
  "last_audit": {
    "date": "2026-05-24T18:42:13Z",
    "report_path": ".claude/audits/2026-05-24-01.md",
    "report_path_display_id_prefix": "SA-2026-05-24-01",
    "finding_counts": { "critical": 0, "high": 1, "medium": 3, "low": 7, "info": 2 },
    "enabled_plugins_snapshot": [
      { "name": "ai-mentor", "version": "1.3.0" },
      { "name": "architect-critic", "version": "0.1.0" }
    ]
  },
  // Tamper-detection self-record (T1-F): on every legitimate audit run, the
  // audit updates `state_mtime_at_last_audit` immediately AFTER its own write.
  // On the next run, if the file's actual mtime != recorded value, something
  // (a malicious teammate PR, a corrupted process, a stale concurrent run)
  // edited state.json between audits. The next audit warns prominently.
  "self_integrity": {
    "state_mtime_at_last_audit": 1748118133,
    "suppressions_mtime_at_last_audit": 1747512000,
    "git_tracked_check": {
      "state_json_tracked": false,
      "suppressions_json_tracked": false,
      "checked_at": "2026-05-24T18:42:13Z"
    }
  },
  // Finding registry — durable across runs, keyed on finding_uid (coarse
  // fingerprint over rule_id + normalized_path + canonical_match_excerpt,
  // NO line number). The per-run "fingerprint" used for dedup within a single
  // audit is finer (includes line) but is not persisted here.
  "findings": {
    "FUID-a3f9b21c": {
      "rule_id": "PERM-003",
      "severity": "medium",
      "file": ".claude/settings.json",
      "first_seen": "2026-05-20T12:00:00Z",
      "last_seen": "2026-05-24T18:42:13Z",
      "seen_in_runs": 3,           // for GC: T2-K evicts when this stops incrementing
      "last_display_id": "SA-2026-05-24-013"
    },
    "FUID-7e1d40af": {
      "rule_id": "HOOK-001",
      "severity": "critical",
      "file": "@plugin:some-bad-plugin:hooks/start.sh",
      "first_seen": "2026-05-24T18:42:13Z",
      "last_seen": "2026-05-24T18:42:13Z",
      "seen_in_runs": 1,
      "last_display_id": "SA-2026-05-24-001"
    }
    // GC policy: evict any entry where (current_audit_run_index - last_seen_run_index) > 10.
    // Evicted entries silently re-appear as NEW on future runs if rediscovered — acceptable
    // for a feature that's about "what changed recently."
  },
  "audit_history": [
    { "run_index": 1, "date": "2026-05-20T12:00:00Z", "report_path": ".claude/audits/2026-05-20-01.md", "finding_counts": { /* ... */ } },
    { "run_index": 2, "date": "2026-05-22T09:15:00Z", "report_path": ".claude/audits/2026-05-22-01.md", "finding_counts": { /* ... */ } },
    { "run_index": 3, "date": "2026-05-24T18:42:13Z", "report_path": ".claude/audits/2026-05-24-01.md", "finding_counts": { /* ... */ } }
  ],
  "applied_fixes": [
    {
      "finding_uid": "FUID-aa0011bb",
      "display_id_at_apply": "SA-2026-05-20-005",
      "rule_id": "GITIGNORE-001",
      "applied_at": "2026-05-21T09:15:00Z",
      "applied_by": "praveensingh2897@gmail.com",   // see §11 D-id note on identity source
      "summary": "Added .claude/audits/ to .gitignore"
    }
  ]
}
```

**Note on `schema_version`:** bumped to 2 (vs 1 in original draft) to reflect the `findings` registry redesign (was `known_fingerprints` keyed on hash with line; now keyed on `finding_uid` without line per T2-I). The audit refuses to operate on a state.json with `schema_version > <current>` and emits a one-shot migration on `schema_version < <current>`. v0.1 migration paths: v0 (no file) → v2, v1 (early-prerelease) → v2.

### 8.3 `suppressions.json`

Located at `.claude/audits/suppressions.json`. Gitignored per Q11 lock.

```jsonc
{
  "schema_version": 1,
  "suppressions": [
    {
      "fingerprint": "b7c1d9...",
      "rule_id": "PERM-002",
      "suppressed_by": "praveensingh2897@gmail.com",
      "suppressed_at": "2026-05-22T10:00:00Z",
      "note": "Bash(*) is intentional for personal-laptop usage; my own scripts only."
    }
  ]
}
```

Critical-severity rules can never be suppressed (Q11 sub-lock). `/security-audit --suppress` validates rule severity before writing.

### 8.4 Report file (`<date>-<NN>.md`)

Located at `.claude/audits/<date>-<NN>.md`. `<NN>` is a per-day monotonic counter starting at `01`.

```markdown
# Security audit — 2026-05-24 (run #01)

**Project:** claude-agent-scaffolding
**Audit scope:** project .claude/ + 2 enabled plugins (ai-mentor 1.3.0, architect-critic 0.1.0)
**Duration:** 4.2s
**Settings parsed from:** .claude/settings.json, ~/.claude/settings.json

## Summary

| Severity | NEW | Persisted | Suppressed | Total visible |
|---|---|---|---|---|
| Critical | 0 | 0 | 0 | 0 |
| High     | 1 | 0 | 0 | 1 |
| Medium   | 2 | 1 | 1 | 3 |
| Low      | 4 | 3 | 2 | 7 |
| Info     | (suppressed; pass --verbose) | | | |

## Findings

### [NEW] SA-2026-05-24-001 (High) — settings.local.json broadens settings.json

**Rule:** PERM-004 (settings-local-divergence)
**File:** .claude/settings.local.json:7:offset-12
**Preview:** `"allow": ["Bash(*)"]`

**Why it matters:** `.claude/settings.local.json` is gitignored by default but takes precedence over `.claude/settings.json`. This file grants `Bash(*)` while the committed `settings.json` restricts to `Bash(git:*)`. Code review missed the broader grant because it's not in git.

**Recommended action (advisory):** Either (a) narrow `settings.local.json` to match `settings.json`, or (b) explicitly document the per-developer broadening intent in a project README.

**Auto-fix:** not supported for this rule (settings.local.json is user-owned; the right scope is a judgment call, not a mechanical narrowing).

---

### [NEW] SA-2026-05-24-002 (Medium) — Broad shell allow pattern

**Rule:** PERM-001 (broad-allow)
**File:** .claude/settings.json:14:offset-21
**Preview:** `"allow": ["Bash(*)"]`

**Why it matters:** `Bash(*)` permits any shell command, including destructive ones. Narrower scoping (e.g., `Bash(git:*)`, `Bash(npm:*)`) reduces blast radius if a malicious agent or hook is later introduced.

**Recommended action:** Narrow to the minimal pattern set the project actually needs.

**Auto-fix:** Supported. `/apply-fix SA-2026-05-24-002` will narrow to `["Bash(git:*)", "Bash(npm:*)", "Bash(jq:*)"]` (a sane default derived from your existing usage; review the diff before accepting if you have other tools).

---

[... more findings ...]

---

## Acknowledgements

This report was generated by claude-security-audit v0.1.0, an independent MIT-licensed audit tool inspired by AgentShield in Everything Claude Code (Mustafa, 2026).
```

---

## 9. Derivations

### 9.1 Fingerprint algorithm (two-layer per T2-I)

The audit uses **two** fingerprints with different durability properties:

**1. `finding_uid` (durable; persisted in `state.json`; used for baseline diff + auto-fix + suppression):**

```
finding_uid = "FUID-" + first8(sha256(rule_id || "|" || normalized_file_path || "|" || canonical_match_excerpt))
```

- `normalized_file_path`: project-relative for project files (`.claude/settings.json`); plugin-relative with plugin name prefix for plugin files (`@plugin:ai-mentor:hooks/session-start.sh`); version stripped from plugin path (so a plugin upgrade does not re-fingerprint unchanged content).
- `canonical_match_excerpt`: the match text *without* line number, with whitespace normalized and any redactable tokens replaced by `<REDACTED>`. **Crucially: NO line number.** Stable across runs even when whitespace edits move the match to a different line.

**Why no line number in `finding_uid`:** the original draft included line number, which meant a one-line edit higher in the file would mint a new fingerprint = new ID = NEW badge = false alert. The same finding (same rule, same file, same match content) should keep its identity across trivial edits. Line number drifts; rule+file+content do not.

**2. `dedup_fingerprint` (within-run only; not persisted):**

```
dedup_fingerprint = sha256(rule_id || "|" || normalized_file_path || "|" || line_number || "|" || canonical_match_excerpt)
```

Used inside a single audit run to deduplicate when, e.g., the same rule fires multiple times on the same line via different regex paths. Discarded at end-of-run; only `finding_uid` survives.

**Adversarial note:** an attacker who controls a file CAN craft content designed to collide with a `finding_uid` already in the user's `state.json` (e.g., one previously suppressed). This is acknowledged in §16 risks. v0.1 mitigation: the §9.5 race-window rule refuses a suppression created within 60s of the fingerprint's first detection, blocking the simplest pre-suppression attack. A signed-fingerprint mechanism is deferred to v0.2.

**Implementation note:** cross-platform `sha256` resolution lives in `lib/helpers.sh` — `sha256sum` on Linux, `shasum -a 256` on macOS.

### 9.2 Auto-fix safe / never boundary

| Category | Allowed to write? | Examples |
|---|---|---|
| `.gitignore` | **Yes** | Add `.claude/audits/` |
| `CLAUDE.md` (project's own) | **Yes** | Redact a leaked key (replace with placeholder + warn user to rotate) |
| `.claude/settings.json` | **Yes** | Narrow `allow` pattern; add `deny` clause |
| `.claude/settings.local.json` | **Yes** | Narrow `allow` to match settings.json |
| `~/.claude/settings.json` | **No** (out of project scope) | n/a |
| `.claude/hooks.json`, hook scripts | **No** | (attacker-controlled if hook came from a plugin) |
| `.claude/agents/*.md` | **No** | (attacker-controlled; prompt-injection risk) |
| `.claude/commands/*.md` | **No** | (attacker-controlled) |
| `.claude/mcp/*.json`, `.mcp.json` | **No** | (attacker-controlled endpoint) |
| `.claude-plugin/marketplace.json` | **No** | (changing trust roots is too consequential to auto-apply) |
| Anything under `~/.claude/plugins/cache/` | **No** | (plugin files are owned by the plugin; auto-fix would corrupt install state) |

**Two orthogonal flags determine eligibility (T2-H):**

| Flag | Meaning | Maintained by |
|---|---|---|
| `RULE_AUTO_FIXABLE` | "The target file path is in the §9.2 safe-write allowlist (write-permission gate)." | Rule author; checked at apply-fix |
| `RULE_MECHANICALLY_FIXABLE` | "The fix recipe is derivable without human judgment (e.g., append a fixed line to .gitignore). FALSE if the fix requires context-dependent choice (e.g., narrowing `Bash(*)` — what to narrow to is user intent)." | Rule author; checked at apply-fix |

A rule may have one or both:
- **Both true** → rule defines a `fix` function; `/apply-fix` runs it.
- **`AUTO_FIXABLE=true`, `MECHANICALLY=false`** → file is writable but the fix needs judgment. `/apply-fix` refuses with the "requires human judgment" message; verbal `RULE_REMEDIATION` is the only response.
- **`AUTO_FIXABLE=false`, `MECHANICALLY=true`** → fix recipe exists but the target file is attacker-controlled. `/apply-fix` refuses with the "not in safe-write set" message; verbal `RULE_REMEDIATION` is the only response. (Often: "uninstall + report.")
- **Both false** → verbal `RULE_REMEDIATION` only; no fix function defined.

**Defense in depth in `apply-fix.sh`:**
1. Re-check the rule's `RULE_AUTO_FIXABLE` AND `RULE_MECHANICALLY_FIXABLE` flags (a malicious rule could lie in its declarations OR be overwritten between detection and apply).
2. Re-resolve the fix recipe's target path and verify it is *still* in the §9.2 safe-write allowlist (a malicious rule could try a symlink, path traversal, or post-detection path swap).
3. Refuse to write to symlinks at the target path (T1-F-adjacent: an attacker could symlink `.gitignore` → `~/.ssh/authorized_keys` and weaponize an "append a line" fix).
4. Refuse to write to a path that resolves OUTSIDE the project root (catches `..` traversal).
5. Log the apply-fix call to `state.json.applied_fixes` BEFORE the write; if the write fails after the log entry, the entry is updated to `failed` rather than removed (audit trail of attempts).

### 9.3 Severity assignment

Severities are declared statically per rule (no context-modified math in v0.1). Tier definitions and example findings per tier:

- **Critical** — actively dangerous; immediate action.
  Examples: hook executes `curl ... | bash`; `deny: []` paired with broad allow; plaintext production API key in `CLAUDE.md`; agent prompt instructs reading and exfiltrating `~/.ssh/`.

- **High** — significantly risky; should fix this session.
  Examples: MCP endpoint with no auth; settings.local.json silently broadens settings.json; plugin's hook script contains base64-encoded payload that decodes to network call.

- **Medium** — notable; fix within a few sessions.
  Examples: hook references external script not in repo; `Bash(*)` instead of `Bash(git:*)`; CLAUDE.md mentions internal-only paths; agent system prompt has unusual instructions that look like prompt injection but lack clear exfiltration.

- **Low** — hygiene; fix when convenient.
  Examples: stale comment in hook config; localhost dev URL in MCP config; permission slightly broader than needed; CLAUDE.md mentions a generic placeholder secret format that's not actually a secret.

- **Info** — observation, not a finding.
  Examples: "Plugin X v1.2.3 enabled; no issues detected"; "No audit baseline yet — this is your first audit"; "Hooks directory is empty"; "Plugin Y was updated since last audit (re-scanned)."

Info findings are suppressed from chat summary by default; included in the report file unless `--no-info`.

### 9.4 Finding state machine

```
                  ┌────────────────────────────────────────────────┐
                  ▼                                                │
    [scan result] ── new finding_uid? ──► [NEW]                    │
                  │                                                │
                  └── known finding_uid? ─► [PERSISTED]            │
                                                │                  │
                                                ▼                  │
                                    in suppressions? ──► [SUPPRESSED]
                                                │
                                                ▼ (hidden unless --show-suppressed)
                                          [not rendered]

    [user runs /security-audit --suppress <display_id-or-finding_uid>]
                  │
                  ▼
        resolve to finding_uid (via latest report if display_id given)
                  │
                  ▼
        rule.severity == critical?         ──► REFUSE
        finding_uid newly-discovered <60s? ──► REFUSE (T1-F race window)
                  │
                  ▼ both checks pass
        append to suppressions.json
        finding state becomes SUPPRESSED on next run
```

### 9.5 Self-tamper detection (T1-F)

The audit detects (and warns on) tampering with its own state files between runs. Three checks at audit start:

**Check 1 — state.json modification mtime.** After every legitimate audit run, the audit records the file's mtime in `self_integrity.state_mtime_at_last_audit` (§8.2). On the next run, if the actual mtime ≠ the recorded value, something edited state.json since the last audit. Emit High-severity finding `TAMPER-001: state.json modified outside an audit run since <date>`. Show the diff in `git diff` style if state.json is git-tracked, else show before/after counts of `findings` registry.

**Check 2 — suppressions.json modification mtime.** Same pattern with `suppressions_mtime_at_last_audit`. If modified outside an audit run, emit High-severity `TAMPER-002: suppressions.json modified outside an audit run since <date>; review the suppression list for entries you did not add.`

**Check 3 — git-tracked status drift.** On every run, `git check-ignore -q .claude/audits/state.json` (and same for suppressions.json) checks whether the file is gitignored. If `self_integrity.git_tracked_check.state_json_tracked` was `false` last run and is now `true` (or any inverse change), emit High-severity `TAMPER-003: state file gitignore status changed; an audit-state file may now be tracked in git (and committed to history).`

**Race-window suppression refusal.** When the user runs `/security-audit --suppress <id>`, check `findings[finding_uid].first_seen`. If it's within 60 seconds of the current time, refuse: `"Cannot suppress a finding discovered less than 60s ago. Re-run /security-audit; if the finding still appears, then suppress."` This blocks an attacker who tries to introduce a malicious file AND immediately pre-suppress its corresponding finding in the same session.

**Bootstrap.** On the very first audit run (state.json doesn't exist), all three checks are silently skipped (nothing to compare against). The first run establishes the baseline; tamper detection starts from run #2 onward.

**Limitations explicitly acknowledged in §16 risks:** an attacker who can write to .claude/audits/ CAN ALSO update the mtime to match what state.json claims (defeating Check 1). A signed-state mechanism is deferred to v0.2. v0.1 tamper detection catches *opportunistic* tampering (a teammate PR that edits state.json without thinking to forge mtime), not *deliberate* tampering with knowledge of the v0.1 detection mechanism.

---

## 10. Integration

### 10.1 With `architect-critic` (orthogonal)

Both plugins are standalone. `architect-critic` audits specs/plans adversarially for sycophancy (e.g., this very SPEC will be critiqued by it before v0.1.0 tag). `claude-security-audit` audits configuration files statically for security. No integration in v0.1. v0.2 may add a composition where `architect-critic` invokes `claude-security-audit` on `.claude/` changes during slice-close review.

### 10.2 With `workspace-init` (independent)

No dependency on `workspace-init`'s manifest. The audit may *optionally* read `.workspace/pairing.json` if present to label the report with the canonical project name from manifest, but the audit functions identically without it.

### 10.3 With `scaffold-onboard` and `scaffold-dev` (independent)

No coupling. The audit can run on a project that uses these plugins, or a project that uses none of them.

### 10.4 With `superpowers`

The plugin uses `superpowers:test-driven-development` and `superpowers:subagent-driven-development` for its OWN implementation (see §15 Build sequence), but does not depend on superpowers at runtime.

### 10.5 With AgentShield (ECC)

This is the conceptual progenitor. Attribution in plugin README + each skill body per handoff §2.3:

> Inspired by AgentShield in Everything Claude Code (Mustafa, 2026; MIT). This implementation is an independent, focused MIT-licensed audit tool tailored to composable plugin marketplaces.

No code is shared with ECC; this is a clean-room re-implementation following the same conceptual pattern.

---

## 11. Decisions

All settled 2026-05-24 via grill-me session. See plan file `/Users/draco/.claude/plans/read-docs-handoff-claude-security-audit-velvet-dongarra.md` for full discussion. Summary:

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | Primary threat | Compromised marketplace plugin | Highest-value detection; supply-chain risk; most users will install plugins they don't fully audit |
| D2 | Trigger timing | Manual `/security-audit`; **opt-in** SessionStart reminder (shipped as file, not declared in manifest — T1-C revision) | Generic tool; zero ambient surface by default; resolves self-referential irony of plugin firing the very hook pattern its rules flag |
| D3 | Meta-risk lock | Static only; redacted previews; no remote dispatch | The plugin that detects exfiltration must not be one |
| D4 | Skill catalog | 1 skill + multiple slash wrappers via `$ARGUMENTS` | Detection externalized to lib/; skill body is orchestration glue |
| D5 | Remediation | Advisory + verbal fix instructions; opt-in auto-fix with per-finding consent | Safe by default; user maintains control |
| D6 | Auto-fix boundary | Two-flag system (T2-H): RULE_AUTO_FIXABLE (path in safe-write set) AND RULE_MECHANICALLY_FIXABLE (fix recipe derivable without judgment) must both be true; defense-in-depth re-validation in apply-fix.sh including symlink and path-traversal refusal | Prevents auto-fixing attacker code AND prevents auto-fixing user-owned files that need human judgment |
| D7 | Output format | Chat summary + markdown report file (option c) | Stable IDs required for auto-fix; chat for quick scan |
| D8 | Storage location | Project-local `.claude/audits/`, gitignored by install step | Discoverable; reports never leave project; no leak via git push |
| D9 | Severity rubric | 5 tiers (Critical / High / Medium / Low / Info), static per rule | Industry-standard; simpler than context-math for v0.1 |
| D10 | Auto-fix grant pattern | Per-finding explicit (`/apply-fix <id>` or chat) | Safest; composes with chat UX; defer batch and interactive walk to v0.2 |
| D11 | Finding lifecycle | Both baseline diff + suppression, fingerprint-shared | Removes alert fatigue (#1 reason security tools get disabled) |
| D12 | Suppression location | Gitignored per-developer; Critical-cannot-suppress | Individual-developer audience; prevents worst suppression-misuse case |
| D13 | Plugin recursion | Project `.claude/` + enabled plugins via settings parse (algorithm pinned in §6.3 per T2-J); local-dev fallback for marketplace-operator dogfood; cached-not-enabled plugins counted and surfaced as Info finding INFO-PARANOID-001 (T2-L) | Matches threat model precisely; avoids noise from unused cached plugins; pins resolution so PLAN can build against a stable target |
| D14 | Edge cases | Symlinks NOT followed; gitignored files audited; missing `.claude/` succeeds Info; partial silent | Safe defaults; least-surprise behavior |
| D15 | Composition | Orthogonal with all sibling plugins in v0.1 | Single concern; no dependencies; v0.2 may compose |
| D16 | Perf budget | ≤ 10s typical, 30s hard warning | User-waiting acceptable; bash + jq fast enough |
| D17 | False-positive testing | Two-directional (clean fixtures must produce zero) | Release-gate metric |
| D18 | Rule freshness | Plugin version bump only; no runtime fetch | No network = no new attack surface |
| D19 | CI/pre-commit | Defer to v0.2 | Exit-code semantics + suppression-in-CI need their own design pass |
| D20 | v0.1 scope honesty (T1-A) | Reframed §1/§3/§4.1: realistic primary value is secondary threats + common-pattern compromised-plugin cases; sophisticated adversaries with obfuscation are explicit v0.2 (AST) scope | Aligns marketing with capability; avoids users trusting clean audit as "plugin is safe" |
| D21 | Provenance aspect (T1-B) | Removed from v0.1 scope; deferred to v0.2 with designed trust-root mechanism | No trust root exists in v0.1 (spec forbids runtime fetches); local-to-local hash comparison is theater without it |
| D22 | Settings schema validation (T1-E) | New rule PERM-005; allowlist of valid Claude Code keys in lib/rules/permissions/_known-keys.txt | Highest-value detection class (typo'd field silently disables enforcement); was missing |
| D23 | gitignore install mechanism (T1-D) | First-audit bootstrap: idempotent .gitignore check-and-add with documented edge-case handling (nested git repos, missing .gitignore, unwritable files, no git at all) | Asserted ≥3× in spec but mechanism was unspecified; closes the gap |
| D24 | Self-tamper detection (T1-F) | §9.5 — mtime check on state.json + suppressions.json; git-tracked status drift detection; 60s race-window suppression refusal | Threat model already includes malicious teammate PR; v0.1 catches opportunistic tampering; deliberate tampering needs signing (v0.2) |
| D25 | Rule-load failure visibility (T2-G) | Upgrade from Info to High severity finding (SCANNER-001); chat-summary banner regardless of verbosity | A broken high-value rule produces false-clean — worst outcome; must be unmissable |
| D26 | Durable finding IDs (T2-I) | Two-layer fingerprint: `finding_uid` (durable, no line number) + `dedup_fingerprint` (per-run only). Both `display_id` (per-report) and `finding_uid` accepted by /apply-fix and /security-audit --suppress | Resolves trivial-edit-mints-new-ID problem; preserves report-readability via display_id |
| D27 | state.json GC (T2-K) | Evict `findings` registry entries not seen in last 10 audit runs | Prevents unbounded growth; evicted entries silently re-appear as NEW if rediscovered (acceptable for a "what changed" feature) |

---

## 12. Error handling

| Condition | Behavior |
|---|---|
| `.claude/` does not exist | Exit 0 with Info `"No .claude/ directory found. Nothing to audit."` |
| `settings.json` malformed JSON | Treat as Critical finding (`SETTINGS-PARSE-001`); refuse to recurse into enabled-plugin list; advise user to fix and re-run |
| `state.json` corrupt | Log warning; treat as no baseline; reinitialize on this run |
| `suppressions.json` corrupt | Log warning; treat as empty suppressions; do NOT reinitialize (could mask the user's prior dismissals — require manual fix) |
| Symlink encountered | Log as Info; skip |
| Rule definition file fails to source | **High-severity finding SCANNER-001** ("Rule <id> failed to load — coverage incomplete"); banner in chat summary regardless of verbosity per D25 (T2-G); audit continues with remaining rules |
| Rule's `detect` function exits non-zero | **High-severity finding SCANNER-002** ("Rule <id> detection function failed on file <path>"); treat as producing no findings for that file; continue. Distinguished from SCANNER-001 because the rule loaded but had a runtime error — could be a benign file-specific issue (e.g., binary file) OR a malicious file crafted to trip the rule. Banner if 3+ SCANNER-002 trigger in one run. |
| `/apply-fix` for unknown finding ID | Refuse: `"Finding SA-... not found in most recent report at <path>. Run /security-audit first."` |
| `/apply-fix` for non-auto-fixable rule | Refuse: `"Auto-fix not supported for rule <id>. Recommended action: <verbal instruction>."` |
| `/apply-fix` writes to a path outside the safe-category set | Refuse: `"Internal safety check failed — fix target <path> not in allowlist. Report this as a bug."` (defense in depth; should never trigger if rule is correctly authored) |
| `/security-audit --suppress` for Critical | Refuse: `"Critical findings must be remediated, not suppressed."` |

All error messages are emitted to stderr; the chat summary always returns successfully (even if degraded) so the user gets *some* result.

---

## 13. Edge cases

Per Q13 lock:

1. **Symlinks**: not followed. Log `"symlink at X not followed"` as Info.
2. **Gitignored files**: audited normally. `settings.local.json` is the canonical example — gitignored AND a highest-value scan target.
3. **No `.claude/` directory**: exit 0 with Info; not a failure.
4. **Partial audit targets** (e.g., `hooks/` exists but `agents/` does not): audit what exists; silent on absent. No `"agents/ not found"` Info noise.
5. **No enabled plugins**: audit just the project `.claude/`. No warning.
6. **Plugin enabled but cache directory missing**: log High finding `(PROVENANCE-002)` — plugin should not be enabled without being installed.
7. **Plugin version mismatch between settings and cache**: log Medium Info — possible drift; user should reinstall.
8. **Duplicate findings across project and enabled-plugin recursion**: deduplicate by fingerprint; project-local instance wins for path display.
9. **File too large to scan** (>10 MB, configurable via `SECURITY_AUDIT_MAX_FILE_BYTES`): log as Info; skip; recommend manual inspection. **Defense-in-depth note:** an attacker-controlled file deliberately enlarged past the limit could be used to skip a real malicious pattern; the Info finding therefore lists the path explicitly so the user can investigate. Per-rule output also capped at 1000 findings per rule per run (Info if hit) to prevent attacker-controlled files generating Megabytes of report text.
10. **Binary file in `.claude/`**: log as Info; skip; recommend manual inspection (binaries in `.claude/` are unusual and warrant attention).
11. **Audit run while a previous audit is in progress** (shouldn't happen with manual trigger, but guard): refuse with `"Previous audit in progress — wait or remove .claude/audits/.lock if stale (created at <iso-timestamp>; PID <pid> on host <hostname>)."` Lock file uses `mkdir`-style atomic create (mkdir succeeds atomically or fails); content includes PID + hostname + ISO timestamp. Stale-lock policy: auto-claim if `(timestamp > 1h ago) AND (hostname == current_host AND PID does not exist)`; otherwise require manual removal. (Pure-PID detection across hosts or after PID reuse is unreliable per codex's minor gap; timestamp+host disambiguates.)

12. **Cached-not-enabled plugin Info finding (T2-L).** When `ENABLED_PLUGINS_SET` is a strict subset of cached plugins, emit `INFO-PARANOID-001: N other plugin(s) exist in cache but are not enabled for this project. Run /security-audit --paranoid to scan them too.` Lists plugin names + versions. This addresses the "user enabled a malicious plugin elsewhere, forgot, and only ran audit in this project" case codex T2-L flagged.

13. **First-run with no `.gitignore` AND no `.git` directory.** Project isn't git-versioned. Skip gitignore bootstrap silently; print Info: `"No git repository found; .claude/audits/ will not be gitignored. Audit reports are local-only at <path>."` Don't fail; user's project lifecycle is theirs.

---

## 14. Testing strategy

### 14.1 Unit tests (lib/ utilities)

Each `lib/*.sh` utility has a corresponding `tests/test-*.sh` file. Bash-based test harness (mirrors architect-critic convention); each test is a function `test_<scenario>` that asserts via `assert_eq`, `assert_contains`, `assert_exits_with`.

Target coverage:
- `enumerate-targets.sh`: 8 cases (no `.claude/`, project-only, project + 1 plugin, project + N plugins, malformed settings, missing cache, symlink in target dir, gitignored target)
- `rule-engine.sh`: 6 cases (zero rules, all clean, one finding, multiple findings same rule, multiple findings multiple rules, rule fails to source)
- `fingerprint.sh`: 11 cases (basic, whitespace-normalized stability, plugin-version-stripped stability, redaction-applied, adjacent-lines distinct for dedup_fingerprint, same-rule-different-file distinct, hash determinism, cross-platform sha256, **finding_uid stable across line-number changes** (T2-I), **finding_uid distinct from dedup_fingerprint** (T2-I), **adversarial-context-collision-attempt does NOT collide with pre-existing finding_uid** (T2-I + adversarial))
- `severity.sh`: 5 cases (each tier roundtrip)
- `redact.sh`: 7 cases (API key, JWT, OAuth token, env-var, base64-credential, non-secret-looking, length cap)
- `state.sh`: 11 cases (init, append history, update findings registry, record applied-fix, malformed read, schema-v1→v2 migration, **GC eviction after 10-run absence** (T2-K), **state.json mtime drift detection** (T1-F), **suppressions.json mtime drift detection** (T1-F), **git-tracked status drift detection** (T1-F), **first-run bootstrap skips all 3 tamper checks silently** (T1-F))
- `suppress.sh`: 7 cases (add suppression, refuse Critical, list suppressions, finding_uid match, dedup, **race-window refusal** for finding_uid newer than 60s (T1-F), **display_id resolves to finding_uid for suppression** (T2-I))
- `baseline.sh`: 4 cases (no prior state, all NEW, all PERSISTED, mixed)
- `report-render.sh`: 5 cases (zero findings, mixed severities, suppressed hidden, suppressed shown with flag, plugin attribution footer)
- `apply-fix.sh`: 11 cases (success, finding-not-found, rule-AUTO_FIXABLE-false, rule-MECHANICALLY_FIXABLE-false, target-outside-safe-set, fix-function-fails, double-apply-refused, **malicious-rule-lies-about-AUTO_FIXABLE** (T2-H), **malicious-rule-targets-symlinked-path** (T2-H), **malicious-rule-uses-path-traversal-in-fix** (T2-H), display-id-resolves-to-finding-uid)

### 14.2 Rule tests

Each `lib/rules/<aspect>/<rule>.sh` has a corresponding test file `tests/test-rules-<aspect>.sh` with at least one positive (rule detects intended pattern) and one negative (rule does not flag a benign similar-looking pattern) case per rule. PERM-005 gets dedicated `test-rules-permissions-schema.sh` with ≥6 cases (each known-key-typo variant). Target: 7 aspects × ~4 rules average × 2 cases + 6 schema-validation = ~62 rule-test cases.

### 14.3 Fixture-based integration tests

Two fixture sets in `fixtures/`:

**Clean set** (5 fixtures, `tests/test-fixtures-clean.sh`): each fixture is a complete-but-minimal Claude Code project structure that contains NO security issues. Audit must produce zero findings (Info findings allowed). This is the **release-gate metric** for false-positives.

**Issues set** (8 fixtures, `tests/test-fixtures-issues.sh`): each fixture contains exactly the issues that one aspect's rules target. Audit must detect each intentional issue, with the correct rule_id and severity.

### 14.4 End-to-end tests

`tests/test-e2e-audit.sh`: full `/security-audit` invocation against a fixture project; assert chat summary + report file written + state.json updated.

`tests/test-e2e-apply-fix.sh`: run audit, parse a finding ID from report, invoke `/apply-fix <id>`, assert the fix is applied + state.json records it + a re-audit no longer flags the finding.

`tests/test-e2e-suppress.sh`: run audit, suppress a Medium finding, re-audit, assert it does not appear; attempt to suppress a Critical, assert refusal.

`tests/test-e2e-baseline.sh`: run audit twice (with no changes between); assert second run shows all findings as PERSISTED. Modify a file to introduce a new finding; re-audit; assert it shows as NEW. Add a whitespace-only edit to a finding's line; re-audit; assert the finding stays PERSISTED (T2-I — finding_uid is line-independent).

`tests/test-e2e-tamper-detection.sh` (T1-F): (a) run audit normally; (b) manually touch state.json mtime (simulate teammate edit); (c) re-audit; assert TAMPER-001 emitted at High severity. Same flow for suppressions.json (TAMPER-002). Same for gitignore-status drift (TAMPER-003).

`tests/test-malicious-rule.sh` (T2-H red-team): construct a rule that declares `RULE_AUTO_FIXABLE=true` and `RULE_MECHANICALLY_FIXABLE=true` but whose `fix` function tries to write to `.claude/hooks.json` (NOT in safe-write set). Assert apply-fix.sh refuses with the defense-in-depth re-validation message and the audit-trail entry records the refusal. Repeat for symlink target and path-traversal target.

`tests/test-finding-uid-stability.sh` (T2-I): generate a finding; record its `finding_uid`; whitespace-edit the surrounding lines; re-detect; assert same `finding_uid`. Then change the actual match content; re-detect; assert different `finding_uid`.

`tests/test-rule-load-failure.sh` (T2-G): plant a deliberately-broken rule file in the rules directory; run audit; assert SCANNER-001 emitted at High severity and chat-summary banner is present.

### 14.5 Perf benchmark

`tests/test-perf.sh`: audit a fixture with ~200 files (project + 3 plugins); assert duration < 10s on a reference machine. Emits a warning (not a failure) at 10–30s; fails at >30s.

### 14.6 Architect-critic dogfood pass

Phase 8: invoke `/critique docs/SPEC-claude-security-audit.md` (this file) and `/critique docs/PLAN-claude-security-audit.md`. Apply T=4 challenges; revise SPEC/PLAN inline. Re-run until concession-scored challenges are addressed.

---

## 15. Build sequence

Per Pass D 8-phase pattern, TDD throughout, subagent-driven via `superpowers:subagent-driven-development`. Each phase ends with a single-line commit `claude-security-audit: <description> (v0.1 Phase X)` and a CHANGELOG + PLAN status update.

| Phase | Work | Tests added (cumulative) |
|---|---|---|
| 0 | Eval fixtures (5 clean + 8 issues including permissions-schema-typo); `tests/_helpers.sh` skeleton; **Phase-0 settings-schema discovery test** (T2-J pinning) | ~13 fixture tests |
| 1 | `skills/auditing-claude-configs/SKILL.md` body + references/* sub-docs | ~13 |
| 2 | `lib/helpers.sh`, `lib/redact.sh`, `lib/fingerprint.sh` (two-layer per T2-I), `lib/severity.sh` (foundation utilities) | +33 unit ≈ 46 |
| 3 | `lib/enumerate-targets.sh` (pinned algorithm per §6.3), `lib/rule-engine.sh`, `lib/state.sh` (with tamper-detection per T1-F + GC per T2-K), `lib/baseline.sh`, `lib/suppress.sh` (with race-window refusal), `lib/report-render.sh`, `lib/apply-fix.sh` (with two-flag system + defense-in-depth per T2-H) | +44 unit ≈ 90 |
| 4 | All rule files in `lib/rules/<aspect>/*.sh` (7 aspects, ~28 rules including PERM-005 schema validation); `_known-keys.txt` allowlist | +62 rule tests ≈ 152 |
| 5 | Slash command wrappers (`security-audit`, `secrets-scan`, `permissions-review`, `apply-fix`) | (covered by e2e) |
| 6 | SessionStart hook file (shipped, NOT declared in manifest per T1-C); README section documenting opt-in registration; first-audit gitignore bootstrap (T1-D) | +6 ≈ 158 |
| 7 | E2E integration tests (audit, apply-fix, suppress, baseline, tamper-detection, malicious-rule, finding-uid-stability, rule-load-failure) against all 13 fixtures; perf benchmark | +8 ≈ 166 |
| 8 | Architect-critic dogfood pass on SPEC + PLAN; address conceded challenges; v0.1.0 tag; root marketplace.json + README updates | (review-driven revisions) |

Target test count: **~160–170** (revised from ~140–150 after architect-critic pass added significant adversarial test coverage for T1-F, T2-G, T2-H, T2-I).

---

## 16. Risks

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| False-positive rate too high → tool gets disabled | High | High | Clean-fixture release gate (§14.3); suppression mechanism (§9.4); start with conservative rules, add specificity in v0.2 |
| Rules miss obfuscated payloads in compromised plugins | High | n/a (in-scope limitation, NOT a risk) | This is now explicitly framed as **expected v0.1 behavior** per D20 / §1 / §4.1 scope honesty — not a risk to mitigate. README and chat-summary footer of every report state this clearly. v0.2 adds AST. The "risk" framing was misleading; we either catch a class of attack or we don't — and v0.1 doesn't pretend to catch this class. |
| state.json or suppressions.json tampering by attacker with knowledge of v0.1 mtime check | Medium | High | §9.5 catches opportunistic tampering; deliberate tampering by attacker who reads our SPEC can forge mtime; signed-state mechanism deferred to v0.2 with explicit acknowledgment in README ("v0.1 detects accidental and naive-deliberate tampering; sophisticated attackers can defeat self-integrity checks until v0.2"). |
| Adversarial finding_uid collision (attacker crafts content to collide with existing suppressed finding) | Low | High | §9.1 race-window suppression refusal blocks the simplest attack (pre-suppress + introduce malicious finding within 60s). v0.2 will add signed-fingerprint mechanism. v0.1 risk acknowledged in README. |
| First-audit gitignore bootstrap silently fails (read-only filesystem, no project root, etc.) | Low | Medium | §7.1 flow step 2 handles all known edge cases explicitly; High-severity warning if .gitignore unwritable; Info if no git repo. Test fixture for each edge case in Phase 0. |
| Settings.json parsing path changes in Claude Code | Medium | Medium | Wrap settings access in `lib/enumerate-targets.sh`; single point of update; test against current Claude Code version in Phase 0 |
| Auto-fix corrupts a user-controlled file | Low | High | Per-finding consent + safe-category allowlist + defense-in-depth re-validation in `apply-fix.sh` (§9.2) |
| Suppression file leaks into git despite gitignore | Low | Medium | Install step adds gitignore entry; `state.json` records last-known-gitignored status and warns if `git check-ignore` reports differently |
| Cross-platform bash incompatibilities (macOS vs Linux) | Medium | Low | `lib/helpers.sh` wraps `sha256sum`/`shasum`, `sed -i`/`sed -i ''`, etc.; CI tests both platforms |
| Performance degrades on large `.claude/` directories | Low | Low | Perf budget + warning at 30s (§13.5); `--focus` flag narrows scope; v0.2 may add caching |
| Plugin's own `state.json` becomes an attack target (attacker plugin tampers with it to hide findings) | Low | Medium | Document that `.claude/audits/` should be writable only by user; v0.2 may add a state.json signature mechanism |

---

## 17. Open questions / deferred to v0.2

Tracked from grill-me exit summary and SPEC authoring:

- Batch auto-fix (`--auto-fix` flag) and interactive walk (`--apply-interactive`)
- Team-shared suppressions with signed `suppressions.json` and required notes
- Tighter composition with `architect-critic` (critic invokes audit on `.claude/` changes during slice-close)
- CI / pre-commit integration with exit-code semantics
- Network-based rule refresh
- "Paranoid mode" scanning ALL cached plugins (`--paranoid` flag implementation; the Info finding INFO-PARANOID-001 ships in v0.1, the actual flag does not)
- Project-marketplace-pinned scanning (option (d) from Q12)
- **AST-based detection** of obfuscated shell in hook scripts, semantic-intent analysis in agent/command prompts, base64-payload-intent analysis (T1-A; the biggest v0.2 feature — closes the obfuscated-adversary gap)
- **Plugin provenance / hash-drift** with designed trust-root mechanism (T1-B; the `lib/rules/provenance/` directory and rules ship in v0.2)
- **Signed `state.json` and `suppressions.json`** to defeat deliberate tampering by adversaries who know the v0.1 self-integrity check (T1-F follow-up)
- **Signed fingerprints** to defeat adversarial `finding_uid` collision attacks (§9.1 adversarial note)
- **Rule schema versioning** (`RULE_SCHEMA_VERSION` per minor gap)
- **`--unsuppress <id>` slash command** (per minor gap; v0.1 requires manual JSON edit)
- **First-run UX nudge** at SessionStart even before any audit history exists (per minor gap)
- **Auto-onboarding skill** for users who have never run an audit ("first-time setup")
- **3-tier severity rubric reconsideration** after Phase 0 measures actual rule distribution (per minor gap; locked at 5-tier in grill, may revisit)
- **Mutation testing** as a rule-quality acceptance criterion (per minor gap)

---

## 18. Iteration log

| Date | Author | Note |
|---|---|---|
| 2026-05-24 | Praveen Kumar Singh | Initial draft authored after grill-me settlement; mirrors `SPEC-architect-critic.md` structure; pending architect-critic dogfood pass before v0.1.0 tag |
| 2026-05-24 | Praveen Kumar Singh + architect-critic (codex+claude consolidated) | Adversarial review pass — 10 substantive challenges + 10 minor gaps surfaced; 6 Tier-1 + 6 Tier-2 conceded and folded inline (T1-A reframe, T1-B provenance deferred, T1-C opt-in hook, T1-D gitignore mechanism, T1-E PERM-005 schema validation, T1-F self-tamper detection, T2-G rule-load High, T2-H two-flag auto-fix, T2-I finding_uid + display_id, T2-J enumerate algorithm pinned, T2-K state.json GC, T2-L cached-not-enabled Info finding). Test target ↑ from ~140-150 to ~160-170. Decisions D20–D27 added. architect-critic v0.1.3 itself flagged 4 bugs filed at https://github.com/draco28/claude-agent-scaffolding/issues/3. |
