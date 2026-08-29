# Changelog

All notable changes to the `code-judo` plugin.

## 0.1.0

Initial release. Four prose skills, no runtime library.

- `deep-review` — strict maintainability review of a diff or branch. Ports the upstream
  standards, review questions, escalation list, preferred remedies, tone, prioritized output
  order, approval bar, and presumptive blockers. Human-invoked only.
- `deepen-architecture` — proactive codebase scan for deepening opportunities, rendered as a
  single HTML report in the OS temp directory and opened in the browser. Human-invoked
  only.
- `codebase-design` — the deep-module vocabulary and principles, plus the dependency
  categories, seam discipline, and the design-it-twice parallel pattern.
- `domain-modeling` — `CONTEXT.md` glossary discipline and ADR authoring.

Invocation posture is declared on both surfaces, because they read different files:
`disable-model-invocation: true` in SKILL.md frontmatter for Claude Code, and
`policy.allow_implicit_invocation: false` in `skills/*/agents/openai.yaml` for Codex, which
does not read the frontmatter field. The lint asserts the two agree, in both directions.

Three deliberate departures from upstream. `deep-review` produces one report and one
categorical disposition pass and never loops, and its verdict is advisory rather than a merge
gate. The cross-skill dependency web is internalized, with the grilling step resolving softly
to `ossify:challenge`, then `ai-mentor:grill-me`, then an in-plugin protocol. And
`deepen-architecture` reads path-bearing history (`git log --name-only`) for its hot-spot
scan: upstream specifies `--oneline`, which prints commit subjects and no file names, so it
cannot answer the question it is asked. The requirement is ported; the command is corrected.

Deferred to a later release: the OpenCode adapter surface, eval fixtures for the two review
skills, and the upstream security/correctness review axis. Tracked on #382.
