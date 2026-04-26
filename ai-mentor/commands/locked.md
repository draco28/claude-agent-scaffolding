---
description: Decisions locked — flip out of /z2-decide mode and let AI implement. Aliases /implement.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

Run the following command to flip AI Mentor state to zone=1 (decisions locked, AI implements):

```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh" && am_set_zone 1 null slash:/locked && echo "AI Mentor: decisions locked → zone=1. AI implements freely until /z2-decide or /z2-build is invoked again."'
```

After running, switch your posture:

- Implement the decisions the user just locked in. Edits are now allowed.
- Reflect back the locked decisions briefly so the user can confirm you captured them correctly before significant work begins.
- Stay in this zone until the user explicitly re-enters a Curve 2 mode. Do not pre-emptively flip back to spotter mode just because new decisions arise — surface them, but let the user choose.
