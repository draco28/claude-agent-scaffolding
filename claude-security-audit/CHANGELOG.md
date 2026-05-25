# claude-security-audit changelog

## Unreleased

### Phase 0 — Eval fixtures
- Plugin manifest (no hooks declared per T1-C opt-in pattern)
- Bash test harness skeleton (`_helpers.sh`, `run-tests.sh`) with accumulator-style exit propagation
- `.gitignore` override re-including `.claude/` fixtures vs contributor global gitignore
- 5 clean-set fixture projects (release-gate metric per SPEC D17)
- 8 issue-set fixture projects covering all 7 v0.1 aspects + dedicated PERM-005 schema-typo
- 15 fixture existence tests (full detection assertions deferred to Phase 7 e2e)

### Phase 1 — Skill body + references
- SKILL.md for auditing-claude-configs with rich description for natural-language matching
- references/threat-model.md (distilled from SPEC §4 + §6.3 enumerate algorithm)
- references/severity-rubric.md (5-tier + chat posture + GC)
- references/auto-fix-policy.md (two-flag system + safe-write allowlist + tamper detection + gitignore bootstrap)

### Phase 2 — Foundation libs
- `lib/helpers.sh`: csa_sha256 (cross-platform), csa_realpath (with macOS fallback), csa_sed_inplace (GNU/BSD), csa_mkdir_lock (atomic)
- `lib/redact.sh`: pattern-aware redaction for Anthropic/OpenAI keys, JWT, GitHub PAT family, AWS keys, base64 blobs; configurable length cap
- `lib/fingerprint.sh`: two-layer per T2-I — `csa_finding_uid` (durable, no line number) + `csa_dedup_fingerprint` (per-run); plugin-version-stripping
- `lib/severity.sh`: 5-tier rank + compare + validate
- 35 unit tests added (cumulative 50)

### Phase 3 — Orchestration libs
- `lib/enumerate-targets.sh` per §6.3 pinned algorithm (T2-J); local-dev fallback for marketplace operator dogfood
- `lib/rule-engine.sh` with SCANNER-001/002 High-severity emit (T2-G); banner aggregation for 3+ SCANNER-002
- `lib/state.sh` schema_version=2; findings registry keyed on finding_uid (T2-I); GC after 10-run absence (T2-K); self_integrity tamper detection (T1-F); first-audit gitignore bootstrap (T1-D)
- `lib/baseline.sh` NEW/PERSISTED tagging via finding_uid
- `lib/suppress.sh` with race-window refusal + Critical-cannot-suppress
- `lib/report-render.sh` chat+markdown per §8.4 with stable display_id
- `lib/apply-fix.sh` two-flag system (T2-H) + 5-layer defense-in-depth (rule re-validation, target re-resolution, symlink refusal, path-traversal refusal, atomic state log)
- 54 unit tests added (cumulative ~104)
