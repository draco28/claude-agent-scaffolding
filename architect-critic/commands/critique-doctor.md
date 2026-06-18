---
description: Check external-adversary readiness (codex/claude installed, authed, schema-capable) before a deep critique
---

# /critique-doctor

Invoke the **checking-adversary-readiness** skill. The skill runs `arc codex_doctor`
(fail-soft, always exits 0), presents the readiness report, and offers user-approved
remediation for any gaps. This slash command is a thin wrapper. Takes no arguments.

## Invoke

Now invoke the skill via:

```
Skill(architect-critic:checking-adversary-readiness)
```

The qualified `<plugin>:<skill>` form is required.
