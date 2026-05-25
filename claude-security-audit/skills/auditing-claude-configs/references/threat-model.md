# Threat model (v0.1)

Distilled from SPEC §4. Read this when authoring rules or interpreting findings.

## Primary threat — compromised marketplace plugin (common-pattern subset)

User runs `/plugin install some-thing`. Plugin's files land in `~/.claude/plugins/cache/<name>/<version>/` and are activated for subsequent sessions where the user enables them. Attacker now has hooks, agent prompts, slash commands, and MCP configs that run / influence Claude on every session.

**v0.1 catches:** direct `curl ... | bash`, plain-text exfiltration in agent prompts, missing MCP auth, untrusted endpoint URLs, broad permission grants the attacker can leverage, plaintext credentials in plugin files.

**v0.1 does NOT catch (v0.2 with AST):** base64-encoded payloads, eval indirection, dynamic command construction, splice-via-includes, deliberately-malformed regex bait, prompt-injection that uses semantic encoding rather than literal exfiltration strings.

## Secondary threats — the realistic v0.1 primary value

1. **Malicious teammate PR** that isn't trying hard to hide (plain-text hook with `rm -rf`, agent definition with literal "send my data to attacker.com")
2. **Accidental friendly-fire** — API key pasted into CLAUDE.md and committed
3. **Public-repo exposure** — open-sourcing a Claude project with `.claude/` configs that contain secrets or overly-permissive grants
4. **`settings.local.json` silent broadening** — gitignored file grants `Bash(*)` while committed `settings.json` restricts to `Bash(git:*)`; code review missed it because it's not in git

## Out of v0.1 threat model

- Runtime attacks during an active Claude Code session
- Network attacks on Claude Code itself
- Side-channel attacks
- Attacks on the audit plugin's own files

## Meta-risk constraint (G3 lock)

The audit reads files that, per the threat model, may be attacker-controlled. The plugin detecting exfiltration must not itself be one:
- Static analysis only — no LLM evaluation over raw file bytes
- Findings show `file:line:offset` with redacted previews (`sk-ant-***xyz`); never full secret material
- No subagent / codex dispatch on file content

## Enumerate-targets resolution algorithm (T2-J pin)

```
1. PROJECT_TARGETS:
   - Every file under "$PWD/.claude/" matching per-aspect glob patterns
   - $PWD/CLAUDE.md and nested CLAUDE.md files in subdirs
   - $PWD/.claude-plugin/marketplace.json if present

2. ENABLED_PLUGINS_SET:
   a. Parse $PWD/.claude/settings.json for "enabledPlugins" array (or whatever
      Claude Code's current settings key is — pinned by Phase-0 discovery test).
   b. Parse $HOME/.claude/settings.json for same key.
   c. Union the two; project-local takes precedence on conflicting state.
   d. Resolve each plugin name to filesystem path:
      - First: $HOME/.claude/plugins/cache/<plugin>/<active-version>/
      - Fallback (local-dev): $HOME/.claude/plugins/local/<plugin>/
        Scan with "[local-dev]" prefix on findings (supports marketplace
        operator's pre-publish dogfood use case)
      - If neither resolves: emit PROVENANCE-002 High finding

3. SCAN_SET = PROJECT_TARGETS ∪ files-under-each-ENABLED_PLUGIN-path

4. PARANOID_CANDIDATES (counted but not scanned by default):
   - Directories under $HOME/.claude/plugins/cache/ not in ENABLED_PLUGINS_SET
   - If count > 0, emit INFO-PARANOID-001 with the count
```
