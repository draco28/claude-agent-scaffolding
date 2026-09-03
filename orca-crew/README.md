# orca-crew

The orchestrator/worker session model over Orca orchestration. One prose skill, no
runtime library.

One orchestrator session (`claude` on Fable, or `claude-sol`) keeps its context for
decisions and dispatches everything else to GLM sessions launched by alias through Orca.
`claude-glm` implements planned work, `claude-glm-flash` implements bounded work, one
`claude-glm-flash` session runs `/code-review` once per PR and returns findings through
`worker_done`, the retained implementer works GitHub threads to zero, and the merge waits
for the operator's word.

## Skill

| Skill | What it does |
|---|---|
| `orchestrate` | The playbook for the orchestrator session: the delegation floor and its decidable test, the role table, the thirteen-step run, five self-contained brief templates, the ossify seam, and the refusals. Defers every other Orca command to `orca skills get orchestration`. |

## Command

| Command | Skill |
|---|---|
| `/orca-crew:orchestrate [objective]` | `orchestrate` |

## The delegation floor

The orchestrator's own turns take these kinds of action, and no others: single-command
probes; writing briefs, dispositions, and the handoff; reading `worker_done` bodies;
deciding; conversing with the operator and workers; executing single authorized
mutations. If an answer needs more than one command's output, it is dispatched to a
verifier session.

## Roles

| Role | Alias | Class |
|---|---|---|
| Orchestrator | `claude` or `claude-sol` | |
| Implementer, planned | `claude-glm` (high; `--effort max` on demand) | `contract`, and the default when unclassified |
| Implementer, fast | `claude-glm-flash` | `bounded` |
| Reviewer | `claude-glm-flash`, `/code-review <PR>` once | |
| Verifier | `claude-glm` at high; `claude-glm-flash` for purely mechanical runs. Read-only | |
| Operator | the human: the merge word | |

Aliases are shell profiles that carry provider routing and pinned defaults. The skill
never substitutes `claude --model`.

## Session budget

One implementer seat and one verifier seat per work item; one reviewer per PR. A fix
round may re-use the verifier seat, and a context-rotation replacement occupies the
seat it replaces; any session outside those seats is a planning defect, and the
orchestrator stops to re-plan the item. The authority is the skill's `roles.md`.
The implementer is retained across consecutive work items until it passes half its
context window (checked by `/context` at each task boundary) or the harness
auto-compacts; the next item starts fresh with the handoff the orchestrator writes
from the inputs in its `worker_done`.

## With ossify

ossify's ceremonies (`start`, `adopt`, `plan-release`, `plan-spine`, `wayfinder`,
`challenge`, `handoff`, `handoff-resume`) run in the orchestrator session. Its execution lanes
(`run-spine`, `work-item`, `close`, `work-pr`, `doctor`) are dispatched to Orca sessions.
No ossify contract changes.

## Requirements

- Orca running with the orchestration feature enabled.
- The aliases `claude-glm` and `claude-glm-flash` defined in the shell Orca's terminals
  inherit.
- The `/code-review` skill available to the reviewer session. If it is unavailable, the
  reviewer reports that in its `worker_done` and the operator decides.
- The target repository's ruleset requires conversation resolution before merge, so
  GitHub itself refuses a merge while any review thread is open.

## Tests

```bash
bash orca-crew/run-tests.sh
```

Frontmatter lint (skill, command, and Codex posture agree) and five fidelity pins.
