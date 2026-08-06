# Task 7 Report

## Status

Implemented hermetic real-loader coverage for OpenCode 1.18.13 and expanded CI
from shell-only wording/coverage to all deterministic repository test suites.

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
- Each temporary config directory contains exactly one local wrapper. It imports
  `claude-agent-scaffolding-opencode` by package name through a temporary
  `node_modules` symlink to the git-installable root, exercising the package
  export resolver rather than directly importing a plugin implementation file.
- The default wrapper delegates without options. The all-four wrapper delegates
  with the exact `workspace-init`, `ai-mentor`, `architect-critic`, `ossify`
  allowlist.
- Real `debug config`, `debug skill`, and `debug agent` outputs are parsed with
  Node. Assertions cover exact paths/names/alias targets, duplicate rejection,
  excluded plugin absence, Ossify opt-in skills and agent, agent tool/task
  permissions, and default Ossify-agent absence.
- Resolved config proves only the deliberate wrapper is loaded, so the
  worktree's `.opencode/plugins/marketplace.js` is never auto-loaded in parallel.

## CI

- Pins the official package with `npm install --global opencode-ai@1.18.13`.
- Preserves every existing suite and both root parity gates.
- Adds explicit AI Mentor, Ossify, adapter-unit, and live-loader steps.
- Renames the workflow and job to `repository test suites` and removes the
  obsolete shell-only comments.

## Files

- `tests/test-opencode-live.sh`: portable, fail-fast, offline live-loader test.
- `.github/workflows/tests.yml`: pinned OpenCode install and complete suite list.
- `.superpowers/sdd/task-7-report.md`: TDD and verification evidence.

## Commit And Concerns

Commit message: `test(opencode): add real loader integration coverage`.

No blocking concerns. OpenCode 1.18.13 does not expose a flag for disabling
machine-managed policy files, but the test's exact plugin/config/skill/agent
assertions fail closed if such policy contaminates a runner. Standard developer
configuration and credentials remain unreachable.
