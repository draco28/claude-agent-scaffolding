# Task 7 Report

## Status

Implemented hermetic native package-loader coverage for OpenCode 1.18.13 and
expanded CI from shell-only wording/coverage to all deterministic repository
test suites. Review fixes expose the package's native server entrypoint and
harden managed-policy, timeout, alias, and agent assertions.

## RED

Live-loader command before implementation:

```bash
bash tests/test-opencode-live.sh
```

Result: failed with `tests/test-opencode-live.sh: No such file or directory`.

Workflow contract command before the workflow edit:

```bash
node -e 'const fs=require("fs");const text=fs.readFileSync(".github/workflows/tests.yml","utf8");for(const expected of ["name: repository test suites","npm install --global opencode-ai@1.18.13","bash ai-mentor/tests/test-frontmatter-lint.sh","bash ossify/tests/run-all.sh","node --test tests/test-opencode-runtime-adapter.mjs","bash tests/test-opencode-live.sh"])if(!text.includes(expected))throw new Error(`missing workflow text: ${expected}`)'
```

Result: failed on missing `name: repository test suites` while the workflow
still described and ran only shell suites.

The first live-loader GREEN attempt also failed structurally because pinned
OpenCode contributes one native `customize-opencode` skill at location
`<built-in>`. The harness now asserts that exact native entry separately from
the exact package-owned default/all-four skill sets and locations.

## GREEN

Live loader:

```bash
bash tests/test-opencode-live.sh
```

Result: `OpenCode 1.18.13 live loader integration: PASS`.

Adapter suite:

```bash
node --test tests/test-opencode-runtime-adapter.mjs
```

Result: 62 passed, 0 failed, 0 skipped.

Selected plugin suites:

```bash
bash ai-mentor/tests/test-frontmatter-lint.sh
bash ossify/tests/run-all.sh
```

Results: AI Mentor reported 36 passed and 0 failed. Ossify ran all 24
`test-*.sh` entrypoints and reported `ALL GREEN`.

Parity gates:

```bash
bash tests/test-codex-dual-publish.sh
bash tests/test-recommendation-policy-parity.sh
```

Results: 155 passed and 0 failed; 7 passed and 0 failed, respectively.

Workflow checks:

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/tests.yml"); puts "workflow YAML syntax: PASS"'
node -e 'const fs=require("fs");const text=fs.readFileSync(".github/workflows/tests.yml","utf8");for(const expected of ["name: repository test suites","npm install --global opencode-ai@1.18.13","bash ai-mentor/tests/test-frontmatter-lint.sh","bash ossify/tests/run-all.sh","node --test tests/test-opencode-runtime-adapter.mjs","bash tests/test-opencode-live.sh"])if(!text.includes(expected))throw new Error(`missing workflow text: ${expected}`)'
```

Results: YAML syntax passed and every expected pinned install/suite command was
present.

## Isolation And Coverage

- Every actual OpenCode process runs under `env -i` from a temporary project
  root with explicit temporary `HOME`, all four XDG roots, `TMPDIR`,
  `OPENCODE_TEST_HOME`, `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, inline config,
  TUI config, and database state paths.
- Project config, default plugins, external skills, Claude skills, updates, and
  model fetching are disabled. Git global/system config is also suppressed.
- OpenCode's package manager is forced offline. Temporary config directories
  contain the exact pinned dependency metadata needed to prevent startup from
  attempting dependency installation.
- `opencode debug paths` is parsed and checked for both default and all-four
  cases, proving home/config/data/cache/state/tmp resolution remains under the
  corresponding temporary case root.
- Each temporary custom config names the root package directly as a native
  `file://` package spec. Defaults use the plain spec; all-four uses OpenCode's
  native `[specifier, options]` tuple with the exact `workspace-init`,
  `ai-mentor`, `architect-critic`, `ossify` allowlist. No local wrapper or
  package-name symlink exists.
- Every process points `OPENCODE_TEST_MANAGED_CONFIG_DIR` at an empty temporary
  directory. A failing `plutil` shim blocks real macOS managed preferences, and
  exact config/skill/agent assertions plus poison fixtures prove managed
  provider/model/permission/plugin/agent/skill contamination is rejected.
- Every command runs through Node `spawnSync` with a 60-second timeout, a hard
  `SIGKILL` bound, and direct file-backed stdout/stderr. `debug wait` and a
  SIGTERM-ignoring child both prove timeout exit 124; failures print both streams
  with the case and command label.
- Real `debug config`, `debug skill`, and `debug agent` outputs are parsed with
  Node. Assertions cover exact paths/names/alias targets, duplicate rejection,
  excluded plugin absence, Ossify opt-in skills and agent, agent tool/task
  permissions, and default Ossify-agent absence.
- Resolved config and plugin origins identify the root package's plain default
  spec and all-four options tuple directly. The worktree project plugin is never
  auto-loaded in parallel, and no local wrapper or package-name symlink exists.

## CI

- Pins the official package with `npm install --global opencode-ai@1.18.13`.
- Preserves every existing suite and both root parity gates.
- Adds explicit AI Mentor, Ossify, adapter-unit, and live-loader steps.
- Renames the workflow and job to `repository test suites` and removes the
  obsolete shell-only comments.

## Files

- `tests/test-opencode-live.sh`: portable, fail-fast, offline live-loader test.
- `package.json`: root and OpenCode `./server` package exports.
- `tests/test-opencode-runtime-adapter.mjs`: package export contract assertion.
- `.github/workflows/tests.yml`: pinned OpenCode install and complete suite list.
- `.superpowers/sdd/task-7-report.md`: TDD and verification evidence.

## Commit And Concerns

Commit message: `test(opencode): add real loader integration coverage`.

No blocking concerns. Standard developer configuration, machine-managed files,
macOS managed preferences, credentials, model fetching, updates, and package
network access are isolated or disabled.

## Review Fix RED

Package contract command:

```bash
node --test --test-name-pattern="root package declares" tests/test-opencode-runtime-adapter.mjs
```

Result: 1 test, 0 passed and 1 failed. The actual root string export did not
match the required `.` plus `./server` export map.

Native live-loader command before the package fix:

```bash
bash tests/test-opencode-live.sh
```

Result: failed in the all-four `debug agent` command with exit 1 and
`Agent ossify-implementer-agent not found`. The plain and tuple package specs
were present in resolved config, but OpenCode skipped the package because no
native server entrypoint was exported.

The first timeout-runner GREEN attempt then exposed a harness regression:
OpenCode/Bun flushed only 65,138 bytes of `debug skill` JSON through a captured
pipe. The structural parser failed on the truncated JSON. Switching the same
bounded `spawnSync` process to direct file descriptors preserved full output.

## Review Fix GREEN

Focused package contract:

```bash
node --test --test-name-pattern="root package declares" tests/test-opencode-runtime-adapter.mjs
```

Result: 1 passed, 0 failed.

Native live loader:

```bash
bash tests/test-opencode-live.sh
```

Result: `OpenCode 1.18.13 native package loader integration: PASS`.

The final review-fix commit message is
`fix(opencode): expose native package loader entry`.

## Review Fix Final Verification

- `bash tests/test-opencode-live.sh`: OpenCode 1.18.13 native package loader
  integration passed.
- `node --test tests/test-opencode-runtime-adapter.mjs`: 62 passed, 0 failed,
  0 skipped.
- `bash ai-mentor/tests/test-frontmatter-lint.sh`: 36 passed, 0 failed.
- `bash ossify/tests/run-all.sh`: all 24 test scripts ran and reported
  `ALL GREEN`.
- `bash tests/test-codex-dual-publish.sh`: 155 passed, 0 failed.
- `bash tests/test-recommendation-policy-parity.sh`: 7 passed, 0 failed.
- Workflow Psych syntax and expected/stale text checks passed.
- `bash -n tests/test-opencode-live.sh` passed.
- `npm pack --dry-run --json` passed with 359 package entries.
- `git diff --check` passed with no output.

## Final Review RED And GREEN

The hard-timeout RED added a temporary child that ignores SIGTERM and self-exits
after three seconds. The runner still mapped the timeout to 124, but elapsed time
was 3,531 ms against the required 1,500 ms bound because `spawnSync` used its
default SIGTERM. After setting `killSignal: "SIGKILL"`, the same control returned
124 within the bound and the complete live-loader script passed.

A report contract probe failed on the stale phrase `deliberate wrapper`. The
corrected report now describes the plain native package spec, native all-four
tuple, direct package origin, and absence of wrapper/symlink indirection.

Final verification after these fixes:

- Native OpenCode 1.18.13 live loader passed, including both timeout controls.
- Adapter suite: 62 passed, 0 failed, 0 skipped.
- Bash syntax, workflow YAML, workflow text contract, and report text contract
  passed.
- `git diff --check` passed with no output.
