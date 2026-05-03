# Changelog

All notable changes to the ai-mentor plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] — 2026-05-03

### Added
- New `/improve` slash command: rewrites an unstructured natural-language draft into a clean coding-agent prompt (specific files, expected behavior, constraints, definition of done). Always shows the rewrite for explicit user confirmation before Claude acts on it.
- **Pass-through marker** (`<!-- already well-formed; no changes -->`) when the draft is already well-structured (named files + expected behavior + constraints + definition of done), so the command doesn't damage prompts that don't need rewriting.
- **Inventing-flag rule** — if the rewriter fills in details the user didn't mention (file paths, constraints), it must explicitly flag those for review rather than silently presenting them as ground truth.

### Architecture notes
- The rewrite happens **in the current Claude session**, not via an external `claude --print` subprocess. We tried the subprocess approach first; it had two real problems: (a) `--bare` (which would isolate the call cleanly) requires `ANTHROPIC_API_KEY` and skips OAuth/keychain auth, and (b) without `--bare`, the rewriter call inherits the user's installed skills (e.g., superpowers' `systematic-debugging`) and ignores our system prompt. The in-context approach avoids both problems and adds zero latency from process spawning.
- Trade-off: rewrite uses the active session's model (Sonnet/Opus typically) instead of cheaper Haiku. Acceptable because the rewrite is small (~500–1500 input + 200–600 output tokens) and `/improve` is opt-in (used when a draft is genuinely worth thinking about).
- No separate `ANTHROPIC_API_KEY` required. No subprocess. No subscription complications.

## [1.2.0] — 2026-04-30

### Added
- New sibling skill: `skills/grill-me/SKILL.md`. Activates on phrases like "grill me", "stress-test this", "challenge my design", "poke holes", "what am I missing". Asks one question per turn, walks the design tree across seven categories (requirements, assumptions, edge cases, trade-offs, operability, composition, reversibility), exits cleanly on user signal or convergence, summarizes locked decisions / open issues / assumptions to re-check.
- The skill is plan-and-design-shaped Socratic — distinct from `/quiz` (which tests known material at depth) and from the main `ai-mentor` skill (which manages cognitive mode). Composition documented in the skill body.

### Changed
- ai-mentor's main `SKILL.md` gets a one-line "See also" pointer to the new `grill-me` skill.

## [1.1.1] — 2026-04-27

### Added
- `ai-mentor/tests/test-hooks.sh` — 28-test regression suite (state helpers, PreToolUse hook, SessionStart source-awareness). Run with `bash ai-mentor/tests/test-hooks.sh`. Closes spec open question B4.

### Documentation
- README "Platforms" section: declared Linux/macOS only. Closes spec open question B3.
- `ai-mentor/tests/README.md`: how to run the regression suite, dependencies, when to run.

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
