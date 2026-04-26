# Changelog

All notable changes to the ai-mentor plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-04-26

### Changed
- **State path migrated to `${CLAUDE_PLUGIN_DATA}/state.json`** (canonical plugin-data location per Claude Code docs). Falls back to `~/.claude/ai-mentor/state.json` when the env var isn't set (e.g., shell-level testing). Survives plugin updates cleanly.
- **SessionStart hook now respects the `source` field**: state resets only on `startup` and `clear`; preserved through `resume` and `compact`. Closes a silent failure mode where context compaction would erase your active zone, leaving the spotter dead until you noticed.
- **Skill frontmatter split into `description` + `when_to_use`** for better trigger reliability against the documented ~1,536-char budget. Trigger phrase list expanded.

### Added
- Subagent scope documentation in SKILL.md and README.md. Zone enforcement applies to the main session's tool calls, not to subagent-mediated edits — this is by design (subagent isolation). The main agent's protocol discourages spawning implementation subagents in `zone=2`.
- `CHANGELOG.md` (this file).

### Fixed
- *(none — no behavioral bugs reported)*

### Notes
- Existing users on v1.0.0 with state at `~/.claude/ai-mentor/state.json` will silently migrate: on next session start, the state file at the new path is created with `ambient` defaults; the old file becomes orphaned and can be deleted manually if desired.

## [1.0.0] — 2026-04-26

### Added
- Initial release. Pillars 3 (Gym/spotter) + 4 (Fool/beginner's mind) of the 4-pillar cognitive-partner framework. Pillars 1 (DRAG) and 2 (Hill) deferred to v1.2+.
- `SessionStart` hook injecting always-on protocol context (~620 tokens).
- `PreToolUse` hook on `Edit|Write|NotebookEdit` — hard-blocks with override grammar; fail-open on any error.
- Two Curve-2 sub-modes: **`decide`** (block until `/locked`; AI is spotter on architectural thinking) and **`build`** (block unless inline override phrase; AI gives progressive L1–L4 hints).
- Slash commands: `/z1`, `/z2-decide`, `/z2-build`, `/locked` (alias `/implement`), `/quiz`, `/eli10`, `/fool`.
- Detailed `SKILL.md` with zone classification examples, hint level table, quiz protocol, beginner's-mind rules.
- State at `~/.claude/ai-mentor/state.json` (later moved in v1.1).
