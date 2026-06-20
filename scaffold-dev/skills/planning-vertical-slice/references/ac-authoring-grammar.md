# AC-authoring grammar (§6.2)

Referenced by `planning-vertical-slice` §6.2. Author each work-item spec's §6 `acs_block` as machine-checkable `auto:` / `user:` lines per the SPEC §14.1 grammar — one `auto:` line per programmatically-verifiable AC. Example shape:

```
- [ ] AC-1 auto: `pytest tests/test_foo.py` → expected: exit 0
- [ ] AC-2 auto: `grep -q "TARGET" src/foo.py` → expected: exit 0
- [ ] user: click "Export" and confirm a CSV downloads
```

Two hard requirements the `lib/verify.sh` helpers enforce — get either wrong and the gate misfires:

- **(a) The command MUST be wrapped in backticks** — `sd_verify_auto_step` extracts the command from the backticks; an un-backticked command is rejected as malformed so the AC never runs.
- **(b) Every `auto:` AC line MUST carry an `AC-N` label** — `sd_verify_report_cross_check` keys off `AC-N` IDs, and a spec with none *silently skips* the report cross-check.

Use ONLY the supported `expected:` forms: `exit 0`, `exit N`, `output contains <substring>` — the substring is **unquoted** (`sd_verify_auto_step` passes everything after `output contains ` straight to `grep -F`, so wrapping quotes would become part of the required output). No `count > 0` / arithmetic — unsupported.

`user:` lines are manual demo steps and carry **no** `AC-N` — they're verified at slice-close, not cross-checked against `report.md` (a labeled `user:` row would be wrongly required in the report).

These lines are the single AC source of truth the `implementation-checking` gate parses. Do NOT author a parallel prose AC table — the table/`auto:` split is what caused the gate to find zero ACs (#36).
