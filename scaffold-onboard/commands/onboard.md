---
description: Guided 10-phase onboarding conversation that authors MASTER-SPEC.md as source of truth for this project.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

[Stub — implementation in Phase C, Task TC.6]

This command will:
1. Detect mode (new / resume / re-onboard) from onboarding-state.json
2. Walk the user through 10 expert-role phases (~54 questions)
3. Author MASTER-SPEC.md section-by-section
4. Generate EXECUTIVE-SUMMARY.md after Phase 10
5. Invoke architect-critic at Phase 5 recap, Phase 7 recap, and MASTER-SPEC close (if installed)
