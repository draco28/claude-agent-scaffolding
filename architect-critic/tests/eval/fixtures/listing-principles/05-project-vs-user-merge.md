---
scenario_id: 05-project-vs-user-merge
expected_behavior: when a project-scoped principle shares a fingerprint with a user-global principle, the skill shows the project version winning and annotates it as overriding the user-global entry; the user-global version does not appear as a separate active principle
fixture_kind: mixed
---

The user-global principles file has one principle: "Prefer explicit over implicit configuration". The project-scoped patterns file has a refined version of the same principle with additional context: "Prefer explicit over implicit configuration — all feature flags must be declared in config/features.yaml". The fingerprints (normalized text match) overlap on the shared prefix. The skill must show the project version as the active principle and annotate that it overrides the user-global version rather than listing both.

User-global principles file:

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

Prefer explicit over implicit configuration [promoted 2026-05-01 source:manual]
```

Project-scoped patterns file (`.claude/memory-bank/03-code-patterns.md`):

```markdown
# Code patterns — pulse-hive

Prefer explicit over implicit configuration — all feature flags must be declared in config/features.yaml [promoted 2026-05-20 source:manual scope:project]
```
