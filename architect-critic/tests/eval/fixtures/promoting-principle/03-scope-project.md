---
scenario_id: 03-scope-project
expected_behavior: principle is written to the project-scoped file (.claude/memory-bank/03-code-patterns.md) rather than user-global; if the project-scoped file does not exist, it is created; success message cites the project-scoped file path
fixture_kind: invocation-args
---

Invocation: `/promote-principle "Use 2-space indent for all TypeScript source files" --scope project`

No project-scoped principles file exists yet (`.claude/memory-bank/03-code-patterns.md` is absent). The `.claude/memory-bank/` directory exists because the project was onboarded via scaffold-project. The skill must:
1. Create `.claude/memory-bank/03-code-patterns.md` if absent.
2. Append the principle with `[promoted YYYY-MM-DD source:manual scope:project]` annotation.
3. Record the promotion in `state.json` under `principle_promotions[]` with `"scope": "project"`.
4. Emit a success message citing the project-scoped file path, NOT the user-global path.

The user-global principles file (unmodified — skill must not touch it):

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

Avoid feature flags that outlive the experiment they gate [promoted 2026-05-10 source:manual]
```

State at invocation time (no prior promotions with project scope):

```json
{
  "schema_version": 1,
  "in_flight": [],
  "recent_runs": [],
  "principle_promotions": [
    {
      "timestamp": "2026-05-10T11:34:00Z",
      "source": "manual",
      "text": "Avoid feature flags that outlive the experiment they gate",
      "scope": "user"
    }
  ],
  "candidate_promotions": [],
  "declined_candidates": []
}
```
