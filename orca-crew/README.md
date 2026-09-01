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
| `orchestrate` | The playbook for the orchestrator session: the delegation floor and its decidable test, the role table, the twelve-step run, four self-contained brief templates, the ossify seam, and the refusals. Defers every Orca command to `orca skills get orchestration`. |

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

| Role | Alias |
|---|---|
| Orchestrator | `claude` or `claude-sol` |
| Implementer, planned | `claude-glm` (high; `--effort max` on demand) |
| Implementer, fast | `claude-glm-flash` |
| Reviewer | `claude-glm-flash`, `/code-review <PR>` once |
| Verifier | `claude-glm-flash`, read-only |
| Operator | the human: the merge word |

Aliases are shell profiles that carry provider routing and pinned defaults. The skill
never substitutes `claude --model`.

## With ossify

ossify's ceremonies (`start`, `adopt`, `plan-release`, `plan-spine`, `wayfinder`,
`challenge`, `handoff`) run in the orchestrator session. Its execution lanes
(`run-spine`, `work-item`, `close`, `work-pr`, `doctor`) are dispatched to Orca sessions.
No ossify contract changes.

## Requirements

- Orca running with the orchestration feature enabled.
- The aliases `claude-glm` and `claude-glm-flash` defined in the shell Orca's terminals
  inherit.
- The `/code-review` skill available to the reviewer session. If it is unavailable, the
  reviewer reports that in its `worker_done` and the operator decides.

## Tests

```bash
bash orca-crew/run-tests.sh
```

Frontmatter lint (skill, command, and Codex posture agree) and five fidelity pins.
