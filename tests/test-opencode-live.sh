#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OPENCODE_VERSION="1.18.13"
PACKAGE_NAME="claude-agent-scaffolding-opencode"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OPENCODE_BIN="$(command -v opencode || true)"
NODE_BIN="$(command -v node || true)"

if [ -z "$OPENCODE_BIN" ]; then
  printf 'FAIL: opencode is required\n' >&2
  exit 1
fi
if [ -z "$NODE_BIN" ]; then
  printf 'FAIL: node is required\n' >&2
  exit 1
fi

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/opencode-live.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

SAFE_PATH="${OPENCODE_BIN%/*}:${NODE_BIN%/*}:/usr/local/bin:/usr/bin:/bin"

print_file() {
  file="$1"
  while IFS= read -r line || [ -n "$line" ]; do
    printf '  %s\n' "$line" >&2
  done < "$file"
}

seed_opencode_directory() {
  directory="$1"
  mkdir -p "$directory/node_modules"
  printf '%s\n' \
    '{"dependencies":{"@opencode-ai/plugin":"1.18.13"}}' \
    > "$directory/package.json"
  printf '%s\n' \
    '{"lockfileVersion":3,"packages":{"":{"dependencies":{"@opencode-ai/plugin":"1.18.13"}}}}' \
    > "$directory/package-lock.json"
}

prepare_case() {
  case_root="$1"
  selection="$2"

  mkdir -p \
    "$case_root/home" \
    "$case_root/config/opencode" \
    "$case_root/data" \
    "$case_root/cache/npm" \
    "$case_root/state" \
    "$case_root/tmp" \
    "$case_root/project" \
    "$case_root/config-dir/plugins"

  seed_opencode_directory "$case_root/config/opencode"
  seed_opencode_directory "$case_root/config-dir"
  ln -s "$ROOT" "$case_root/config-dir/node_modules/$PACKAGE_NAME"

  printf '%s\n' '{"autoupdate":false,"share":"disabled"}' \
    > "$case_root/config/opencode-test.json"
  printf '%s\n' '{}' > "$case_root/config/tui.json"

  if [ "$selection" = "default" ]; then
    printf '%s\n' \
      'import { ScaffoldingPlugin } from "claude-agent-scaffolding-opencode";' \
      '' \
      'export const LiveDefaultPlugin = (input) => ScaffoldingPlugin(input);' \
      > "$case_root/config-dir/plugins/live-default.js"
  else
    printf '%s\n' \
      'import { ScaffoldingPlugin } from "claude-agent-scaffolding-opencode";' \
      '' \
      'export const LiveAllPlugin = (input) =>' \
      '  ScaffoldingPlugin(input, {' \
      '    plugins: ["workspace-init", "ai-mentor", "architect-critic", "ossify"],' \
      '  });' \
      > "$case_root/config-dir/plugins/live-all.js"
  fi
}

run_opencode() {
  case_root="$1"
  shift

  (
    cd "$case_root/project"
    env -i \
      HOME="$case_root/home" \
      XDG_CONFIG_HOME="$case_root/config" \
      XDG_DATA_HOME="$case_root/data" \
      XDG_CACHE_HOME="$case_root/cache" \
      XDG_STATE_HOME="$case_root/state" \
      TMPDIR="$case_root/tmp" \
      OPENCODE_TEST_HOME="$case_root/home" \
      OPENCODE_CONFIG="$case_root/config/opencode-test.json" \
      OPENCODE_CONFIG_DIR="$case_root/config-dir" \
      OPENCODE_CONFIG_CONTENT='{"autoupdate":false,"share":"disabled"}' \
      OPENCODE_TUI_CONFIG="$case_root/config/tui.json" \
      OPENCODE_DB="$case_root/state/opencode.db" \
      OPENCODE_DISABLE_PROJECT_CONFIG=1 \
      OPENCODE_DISABLE_DEFAULT_PLUGINS=1 \
      OPENCODE_DISABLE_EXTERNAL_SKILLS=1 \
      OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1 \
      OPENCODE_DISABLE_AUTOUPDATE=1 \
      OPENCODE_DISABLE_MODELS_FETCH=1 \
      OPENCODE_CLIENT=cli \
      NPM_CONFIG_OFFLINE=true \
      npm_config_offline=true \
      npm_config_cache="$case_root/cache/npm" \
      GIT_CONFIG_GLOBAL=/dev/null \
      GIT_CONFIG_SYSTEM=/dev/null \
      GIT_CONFIG_NOSYSTEM=1 \
      CI=1 \
      NO_COLOR=1 \
      TERM=dumb \
      PATH="$SAFE_PATH" \
      "$OPENCODE_BIN" "$@"
  )
}

capture_success() {
  label="$1"
  output="$2"
  case_root="$3"
  shift 3
  error="$output.stderr"

  if ! run_opencode "$case_root" "$@" > "$output" 2> "$error"; then
    printf 'FAIL: %s\n' "$label" >&2
    print_file "$error"
    exit 1
  fi
  if [ -s "$error" ]; then
    printf 'FAIL: %s wrote unexpected stderr\n' "$label" >&2
    print_file "$error"
    exit 1
  fi
}

DEFAULT_CASE="$TEST_ROOT/default"
ALL_CASE="$TEST_ROOT/all"
prepare_case "$DEFAULT_CASE" default
prepare_case "$ALL_CASE" all

capture_success "OpenCode version" "$TEST_ROOT/version.txt" "$DEFAULT_CASE" --version
ACTUAL_VERSION="$(tr -d '[:space:]' < "$TEST_ROOT/version.txt")"
if [ "$ACTUAL_VERSION" != "$EXPECTED_OPENCODE_VERSION" ]; then
  printf 'FAIL: expected OpenCode %s, got %s\n' \
    "$EXPECTED_OPENCODE_VERSION" "$ACTUAL_VERSION" >&2
  exit 1
fi

capture_success "default debug paths" "$TEST_ROOT/default-paths.txt" "$DEFAULT_CASE" debug paths
capture_success "default debug config" "$TEST_ROOT/default-config.json" "$DEFAULT_CASE" debug config
capture_success "default debug skill" "$TEST_ROOT/default-skills.json" "$DEFAULT_CASE" debug skill

DEFAULT_AGENT_RC=0
if run_opencode "$DEFAULT_CASE" debug agent ossify-implementer-agent \
  > "$TEST_ROOT/default-agent.stdout" \
  2> "$TEST_ROOT/default-agent.stderr"; then
  printf 'FAIL: default debug agent unexpectedly found Ossify agent\n' >&2
  exit 1
else
  DEFAULT_AGENT_RC=$?
fi
if [ "$DEFAULT_AGENT_RC" -ne 1 ]; then
  printf 'FAIL: default debug agent exited %s instead of 1\n' "$DEFAULT_AGENT_RC" >&2
  print_file "$TEST_ROOT/default-agent.stderr"
  exit 1
fi

capture_success "all-four debug paths" "$TEST_ROOT/all-paths.txt" "$ALL_CASE" debug paths
capture_success "all-four debug config" "$TEST_ROOT/all-config.json" "$ALL_CASE" debug config
capture_success "all-four debug skill" "$TEST_ROOT/all-skills.json" "$ALL_CASE" debug skill
capture_success "all-four debug agent" "$TEST_ROOT/all-agent.json" "$ALL_CASE" \
  debug agent ossify-implementer-agent

"$NODE_BIN" - \
  "$ROOT" \
  "$DEFAULT_CASE" \
  "$ALL_CASE" \
  "$TEST_ROOT/default-paths.txt" \
  "$TEST_ROOT/default-config.json" \
  "$TEST_ROOT/default-skills.json" \
  "$TEST_ROOT/default-agent.stdout" \
  "$TEST_ROOT/default-agent.stderr" \
  "$TEST_ROOT/all-paths.txt" \
  "$TEST_ROOT/all-config.json" \
  "$TEST_ROOT/all-skills.json" \
  "$TEST_ROOT/all-agent.json" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const [
  root,
  defaultCase,
  allCase,
  defaultPathsFile,
  defaultConfigFile,
  defaultSkillsFile,
  defaultAgentStdoutFile,
  defaultAgentStderrFile,
  allPathsFile,
  allConfigFile,
  allSkillsFile,
  allAgentFile,
] = process.argv.slice(2);

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const sorted = (values) => [...values].sort();
const unique = (values, label) =>
  assert.equal(new Set(values).size, values.length, `${label} contains duplicates`);

const plugins = {
  "workspace-init": [
    "initializing-dual-repo-workspace",
    "pairing-canonical-repo",
    "pairing-existing-dual",
  ],
  "ai-mentor": ["grill-me", "council", "eli10", "fool"],
  "architect-critic": [
    "critiquing-spec",
    "reviewing-critique-history",
    "listing-principles",
    "promoting-principle",
    "checking-adversary-readiness",
    "managing-async-critique",
  ],
  ossify: ["start", "plan-spine", "work-item", "close", "plan-release"],
};

const aliases = {
  "init-workspace": "initializing-dual-repo-workspace",
  "pair-workspace": "pairing-canonical-repo",
  "pair-existing-dual": "pairing-existing-dual",
  critique: "critiquing-spec",
  "critique-list": "reviewing-critique-history",
  "principles-list": "listing-principles",
  "promote-principle": "promoting-principle",
  "critique-doctor": "checking-adversary-readiness",
  "critique-jobs": "managing-async-critique",
};

function parsePaths(file) {
  const result = {};
  for (const line of fs.readFileSync(file, "utf8").trim().split("\n")) {
    const match = line.match(/^(\S+)\s+(.+)$/);
    assert.ok(match, `malformed debug paths line: ${line}`);
    result[match[1]] = match[2];
  }
  return result;
}

function assertIsolatedPaths(file, caseRoot) {
  const actual = parsePaths(file);
  assert.equal(actual.home, path.join(caseRoot, "home"));
  assert.equal(actual.data, path.join(caseRoot, "data", "opencode"));
  assert.equal(actual.cache, path.join(caseRoot, "cache", "opencode"));
  assert.equal(actual.config, path.join(caseRoot, "config", "opencode"));
  assert.equal(actual.state, path.join(caseRoot, "state", "opencode"));
  assert.equal(actual.tmp, path.join(caseRoot, "tmp", "opencode"));
}

function expectedSkillEntries(names) {
  return names.flatMap((plugin) =>
    plugins[plugin].map((name) => [
      name,
      path.join(root, plugin, "skills", name, "SKILL.md"),
    ]),
  );
}

function assertSkills(actual, selected) {
  assert.ok(Array.isArray(actual), "debug skill output must be an array");
  const names = actual.map(({ name }) => name);
  const locations = actual.map(({ location }) => location);
  unique(names, "skill names");
  unique(locations, "skill locations");

  const expected = [
    ["customize-opencode", "<built-in>"],
    ...expectedSkillEntries(selected),
  ];
  assert.deepEqual(sorted(names), sorted(expected.map(([name]) => name)));
  assert.deepEqual(
    sorted(actual.map(({ name, location }) => `${name}\0${location}`)),
    sorted(expected.map(([name, location]) => `${name}\0${location}`)),
  );
}

function assertAliases(config) {
  const commands = config.command ?? {};
  const names = Object.keys(commands);
  assert.deepEqual(sorted(names), sorted(Object.keys(aliases)));
  unique(names, "command aliases");

  const targets = [];
  for (const [name, target] of Object.entries(aliases)) {
    const command = commands[name];
    assert.equal(typeof command.description, "string", `${name} description`);
    const match = command.template.match(/unqualified `([^`]+)` skill/);
    assert.ok(match, `${name} template does not invoke an unqualified skill`);
    assert.equal(match[1], target, `${name} target`);
    targets.push(match[1]);
  }
  unique(targets, "command alias targets");
}

function assertSelection(config, skills, selected, wrapper) {
  const expectedPaths = selected.map((plugin) => path.join(root, plugin, "skills"));
  assert.deepEqual(config.skills?.paths, expectedPaths);
  unique(config.skills.paths, "configured skill paths");
  assertAliases(config);
  assertSkills(skills, selected);

  const wrapperUrl = pathToFileURL(wrapper).href;
  assert.deepEqual(config.plugin, [wrapperUrl]);
  assert.equal(config.plugin_origins?.length, 1);
  assert.equal(config.plugin_origins[0].spec, wrapperUrl);

  for (const excluded of [
    "scaffold",
    "scaffold-onboard",
    "scaffold-dev",
    "claude-security-audit",
  ]) {
    const excludedRoot = path.join(root, excluded) + path.sep;
    assert.ok(!config.skills.paths.some((entry) => entry.startsWith(excludedRoot)));
    assert.ok(!skills.some(({ location }) => location.startsWith(excludedRoot)));
  }
}

assertIsolatedPaths(defaultPathsFile, defaultCase);
assertIsolatedPaths(allPathsFile, allCase);

const defaultConfig = readJson(defaultConfigFile);
const defaultSkills = readJson(defaultSkillsFile);
assertSelection(
  defaultConfig,
  defaultSkills,
  ["workspace-init", "ai-mentor", "architect-critic"],
  path.join(defaultCase, "config-dir", "plugins", "live-default.js"),
);
assert.deepEqual(defaultConfig.agent, {});
assert.equal(fs.readFileSync(defaultAgentStdoutFile, "utf8"), "");
assert.match(
  fs.readFileSync(defaultAgentStderrFile, "utf8"),
  /^Agent ossify-implementer-agent not found,/,
);

const allConfig = readJson(allConfigFile);
const allSkills = readJson(allSkillsFile);
assertSelection(
  allConfig,
  allSkills,
  ["workspace-init", "ai-mentor", "architect-critic", "ossify"],
  path.join(allCase, "config-dir", "plugins", "live-all.js"),
);
assert.deepEqual(Object.keys(allConfig.agent ?? {}), ["ossify-implementer-agent"]);

const agent = readJson(allAgentFile);
assert.equal(agent.name, "ossify-implementer-agent");
assert.equal(agent.mode, "subagent");
assert.equal(agent.native, false);
assert.ok(!Object.hasOwn(agent, "model"));
assert.match(agent.prompt, /You are ossify's work-item executor/);
assert.ok(agent.prompt.includes(path.join(root, "ossify", "skills", "work-item", "SKILL.md")));
for (const tool of ["bash", "read", "glob", "grep", "edit", "write"]) {
  assert.equal(agent.tools[tool], true, `${tool} must be enabled`);
}
assert.equal(agent.tools.task, false);
assert.ok(
  agent.permission.some(
    (rule) =>
      rule.permission === "task" &&
      rule.action === "deny" &&
      rule.pattern === "*",
  ),
  "resolved agent permissions must deny task",
);
NODE

printf 'OpenCode %s live loader integration: PASS\n' "$EXPECTED_OPENCODE_VERSION"
