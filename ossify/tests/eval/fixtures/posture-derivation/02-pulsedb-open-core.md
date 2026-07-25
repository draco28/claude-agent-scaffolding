---
scenario_id: 02-pulsedb-open-core
expected_posture: open-core
expected_channel: private-package
---
Project: PulseDB (Rust, ports-and-adapters, 6 port traits; carries a written PUBLIC_BOUNDARY.md).
Observable facts: decay/re-rank implementations are public but their spec (DECAY_SPEC.md) is private; a 76KB SPEC.md is untracked-but-present in the public working tree (gitignored).
Intent signal: the core DB is open; the intelligence (ranking/decay algorithms + spec) stays private. Revenue intent: license (AGPL + commercial dual-license).
