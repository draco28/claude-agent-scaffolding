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
