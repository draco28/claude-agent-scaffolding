import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const marketplaceUrl = new URL(".opencode/plugins/marketplace.js", root);
const catalogUrl = new URL(".opencode/lib/catalog.js", root);
const markdownUrl = new URL(".opencode/lib/markdown.js", root);
const translateUrl = new URL(".opencode/lib/translate.js", root);

async function applyPluginConfig(options, config = {}) {
  const { ScaffoldingPlugin } = await import(marketplaceUrl);
  const hooks = await ScaffoldingPlugin({}, options);
  await hooks.config(config);
  return config;
}

async function createPluginHooks(options) {
  const { ScaffoldingPlugin } = await import(marketplaceUrl);
  return ScaffoldingPlugin({ directory: fileURLToPath(root) }, options);
}

const expectedPlugins = [
  "workspace-init",
  "ai-mentor",
  "architect-critic",
  "ossify",
];

const excludedPlugins = [
  "scaffold",
  "scaffold-onboard",
  "scaffold-dev",
  "claude-security-audit",
];

const expectedAliases = {
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

test("root package declares the OpenCode bundle contract", async () => {
  const packageJson = JSON.parse(
    await readFile(new URL("package.json", root), "utf8"),
  );

  assert.equal(packageJson.name, "claude-agent-scaffolding-opencode");
  assert.equal(packageJson.version, "0.1.0");
  assert.equal(packageJson.type, "module");
  assert.equal(packageJson.exports, "./.opencode/plugins/marketplace.js");
  assert.deepEqual(packageJson.engines, { opencode: ">=1.18.13" });
  assert.deepEqual(packageJson.os, ["darwin", "linux"]);
  assert.deepEqual(packageJson.dependencies, {});
  assert.deepEqual(packageJson.files, [
    ".opencode",
    "workspace-init",
    "ai-mentor",
    "architect-critic",
    "ossify",
    "LICENSE",
  ]);
});

test("default selection contains only the three stable plugins", async () => {
  const { resolveEnabledPlugins } = await import(catalogUrl);
  const selected = resolveEnabledPlugins();

  assert.deepEqual(
    selected.map(({ name }) => name),
    expectedPlugins.slice(0, 3),
  );
  assert.ok(Object.isFrozen(selected));
  assert.ok(selected.every(Object.isFrozen));
});

test("the explicit allowlist contains exactly four immutable definitions", async () => {
  const { PLUGIN_CATALOG, resolveEnabledPlugins } = await import(catalogUrl);
  const selected = resolveEnabledPlugins({ plugins: expectedPlugins });

  assert.deepEqual(
    selected.map(({ name }) => name),
    expectedPlugins,
  );
  assert.deepEqual(
    PLUGIN_CATALOG.map(({ name }) => name),
    expectedPlugins,
  );
  assert.ok(Object.isFrozen(PLUGIN_CATALOG));
  assert.ok(
    PLUGIN_CATALOG.every(
      (plugin) =>
        Object.isFrozen(plugin) &&
        Object.isFrozen(plugin.skills) &&
        Object.isFrozen(plugin.commands),
    ),
  );
  const aliases = PLUGIN_CATALOG.flatMap(({ commands }) => commands);
  assert.equal(aliases.length, 9);
  assert.ok(aliases.every(Object.isFrozen));
});

test("skill and command ownership comes from catalog metadata", async () => {
  const { getCommandOwner, getSkillOwner } = await import(catalogUrl);

  assert.equal(getSkillOwner("grill-me")?.name, "ai-mentor");
  assert.equal(getSkillOwner("plan-release")?.name, "ossify");
  assert.equal(getCommandOwner("init-workspace")?.name, "workspace-init");
  assert.equal(getCommandOwner("critique-jobs")?.name, "architect-critic");
  assert.equal(getSkillOwner("missing"), undefined);
  assert.equal(getCommandOwner("missing"), undefined);
});

test("unknown and malformed plugin selections are rejected", async () => {
  const { resolveEnabledPlugins } = await import(catalogUrl);

  assert.throws(
    () => resolveEnabledPlugins({ plugins: ["workspace-init", "unknown"] }),
    /Unknown OpenCode plugin: unknown/,
  );
  assert.throws(
    () => resolveEnabledPlugins({ plugins: "workspace-init" }),
    /plugins must be an array/,
  );
});

test("options accept only undefined or a plain object with optional plugins", async () => {
  const { resolveEnabledPlugins } = await import(catalogUrl);
  const defaults = expectedPlugins.slice(0, 3);

  for (const options of [undefined, {}, { plugins: undefined }]) {
    assert.deepEqual(
      resolveEnabledPlugins(options).map(({ name }) => name),
      defaults,
    );
  }

  const invalidContainers = [
    null,
    [],
    "workspace-init",
    1,
    true,
    () => {},
    new Date(),
  ];
  for (const options of invalidContainers) {
    assert.throws(
      () => resolveEnabledPlugins(options),
      /options must be a plain object/,
    );
  }
});

test("options reject unknown and misspelled keys", async () => {
  const { resolveEnabledPlugins } = await import(catalogUrl);

  assert.throws(
    () => resolveEnabledPlugins({ plugin: ["workspace-init"] }),
    /Unknown OpenCode option: plugin/,
  );
  assert.throws(
    () => resolveEnabledPlugins({ plugins: [], extra: true }),
    /Unknown OpenCode option: extra/,
  );
});

test("excluded plugins cannot enter the catalog or package payload", async () => {
  const { PLUGIN_CATALOG, resolveEnabledPlugins } = await import(catalogUrl);
  const packageJson = JSON.parse(
    await readFile(new URL("package.json", root), "utf8"),
  );

  for (const name of excludedPlugins) {
    assert.ok(!PLUGIN_CATALOG.some((plugin) => plugin.name === name));
    assert.ok(!packageJson.files.includes(name));
    assert.throws(
      () => resolveEnabledPlugins({ plugins: [name] }),
      new RegExp(`Unknown OpenCode plugin: ${name}`),
    );
  }
});

test("plugin entrypoint applies strict selection before returning hooks", async () => {
  const { ScaffoldingPlugin } = await import(marketplaceUrl);

  const hooks = await ScaffoldingPlugin({}, { plugins: ["ossify"] });
  assert.deepEqual(Object.keys(hooks), [
    "config",
    "chat.message",
    "command.execute.before",
    "tool.execute.before",
    "tool.execute.after",
    "shell.env",
  ]);
  assert.equal(typeof hooks.config, "function");
  await assert.rejects(
    ScaffoldingPlugin({}, { plugins: ["scaffold"] }),
    /Unknown OpenCode plugin: scaffold/,
  );
  await assert.rejects(
    ScaffoldingPlugin({}, null),
    /options must be a plain object/,
  );
});

test("markdown parser accepts the supported flat frontmatter subset", async () => {
  const { parseMarkdown } = await import(markdownUrl);
  const parsed = parseMarkdown(
    "---\r\n" +
      "name: sample-skill\r\n" +
      "description: Plain value: with colon\r\n" +
      'quoted: "Double-quoted value"\r\n' +
      "hint: 'It''s supported'\r\n" +
      'allowed-tools: ["Read", "Bash"]\r\n' +
      "---\r\n\r\nPrompt body\r\n",
    "supported.md",
  );

  assert.deepEqual(parsed, {
    frontmatter: {
      name: "sample-skill",
      description: "Plain value: with colon",
      quoted: "Double-quoted value",
      hint: "It's supported",
      "allowed-tools": ["Read", "Bash"],
    },
    body: "Prompt body",
  });
});

test("markdown parser rejects ambiguous or unsupported frontmatter", async () => {
  const { parseMarkdown } = await import(markdownUrl);
  const invalid = [
    ["duplicate key", "name: first\nname: second"],
    ["indented or nested value", "name: first\n  nested: value"],
    ["block scalar", "description: |\nname: first"],
    ["malformed line", "name first"],
    ["ambiguous comment", "description: value # comment"],
    ["invalid double-quoted value", 'description: "unterminated'],
    ["invalid single-quoted value", "description: 'can't'"],
    ["invalid string list", 'allowed-tools: "Read"'],
    ["invalid string list", "allowed-tools: 'Read'"],
    ["flow mapping", "metadata: {owner: team}"],
    ["flow sequence", "metadata: [owner, team]"],
    ["anchor", "description: &shared value"],
    ["alias", "description: *shared"],
    ["unsupported YAML construct", "description: !custom value"],
    ["unsupported YAML construct", "description: - sequence item"],
  ];

  for (const [expectedError, frontmatter] of invalid) {
    assert.throws(
      () => parseMarkdown(`---\n${frontmatter}\n---\nBody`, "fixture.md"),
      new RegExp(`fixture\\.md: frontmatter line \\d+: ${expectedError}`),
    );
  }
});

test("selected plugins append only their exact canonical skill paths", async () => {
  const config = await applyPluginConfig(
    { plugins: ["workspace-init", "ossify"] },
    {},
  );

  assert.deepEqual(config.skills.paths, [
    fileURLToPath(new URL("workspace-init/skills", root)),
    fileURLToPath(new URL("ossify/skills", root)),
  ]);
});

test("config registration is idempotent and preserves caller config", async () => {
  const { ScaffoldingPlugin } = await import(marketplaceUrl);
  const hooks = await ScaffoldingPlugin({});
  const existingCommand = { template: "Keep this command" };
  const existingCritique = { template: "Use my critique workflow" };
  const config = {
    skills: {
      paths: ["/user/skills"],
      urls: ["https://example.com/skills/index.json"],
    },
    command: { existing: existingCommand, critique: existingCritique },
    permission: { skill: "ask" },
  };

  await hooks.config(config);
  await hooks.config(config);

  assert.deepEqual(config.skills, {
    paths: [
      "/user/skills",
      fileURLToPath(new URL("workspace-init/skills", root)),
      fileURLToPath(new URL("ai-mentor/skills", root)),
      fileURLToPath(new URL("architect-critic/skills", root)),
    ],
    urls: ["https://example.com/skills/index.json"],
  });
  assert.strictEqual(config.command.existing, existingCommand);
  assert.strictEqual(config.command.critique, existingCritique);
  assert.deepEqual(config.permission, { skill: "ask" });
  assert.equal(new Set(config.skills.paths).size, config.skills.paths.length);
});

test("canonical skills satisfy OpenCode frontmatter and uniqueness rules", async () => {
  const { PLUGIN_CATALOG } = await import(catalogUrl);
  const { parseMarkdown } = await import(markdownUrl);
  const names = new Set();

  for (const plugin of PLUGIN_CATALOG) {
    for (const skill of plugin.skills) {
      const source = await readFile(
        join(plugin.root, "skills", skill, "SKILL.md"),
        "utf8",
      );
      const { frontmatter } = parseMarkdown(source);

      assert.equal(frontmatter.name, skill);
      assert.match(frontmatter.name, /^[a-z0-9]+(?:-[a-z0-9]+)*$/);
      assert.ok(frontmatter.name.length >= 1 && frontmatter.name.length <= 64);
      assert.ok(
        frontmatter.description.length >= 1 &&
          frontmatter.description.length <= 1024,
      );
      assert.ok(!names.has(frontmatter.name), `duplicate skill: ${skill}`);
      names.add(frontmatter.name);
    }
  }

  assert.equal(
    names.size,
    PLUGIN_CATALOG.reduce((total, plugin) => total + plugin.skills.length, 0),
  );
});

test("default config registers exactly the nine canonical command aliases", async () => {
  const { PLUGIN_CATALOG } = await import(catalogUrl);
  const { parseMarkdown } = await import(markdownUrl);
  const config = await applyPluginConfig(undefined, {});
  const expectedNames = Object.keys(expectedAliases);

  assert.deepEqual(Object.keys(config.command), expectedNames);
  assert.equal(expectedNames.length, 9);

  for (const [alias, skill] of Object.entries(expectedAliases)) {
    const plugin = PLUGIN_CATALOG.find(({ commands }) =>
      commands.some(({ name }) => name === alias),
    );
    const commandPath = join(plugin.root, "commands", `${alias}.md`);
    const source = await readFile(commandPath, "utf8");
    const { frontmatter } = parseMarkdown(source, commandPath);
    const argumentsLine =
      alias === "critique-doctor" ? "" : "\n\nArguments: $ARGUMENTS";

    assert.deepEqual(config.command[alias], {
      description: frontmatter.description,
      template:
        `Use OpenCode's \`skill\` tool to invoke the unqualified ` +
        `\`${skill}\` skill and follow it exactly.${argumentsLine}`,
    });
    assert.ok(!config.command[alias].template.includes("Skill("));
  }
});

test("same-named AI Mentor and Ossify skills do not get aliases", async () => {
  const config = await applyPluginConfig(
    { plugins: ["ai-mentor", "ossify"] },
    {},
  );

  assert.deepEqual(config.command, {});
});

test("prompt translation maps qualified invocations and questions", async () => {
  const { translatePrompt } = await import(translateUrl);
  const translated = translatePrompt(
    'Skill(ai-mentor:grill-me)\n' +
      'Task(subagent_type="ossify:implementer-agent", prompt=<brief>)\n' +
      "Use AskUserQuestion if needed.",
    { root: "/opt/plugins/ossify" },
  );

  assert.equal(
    translated,
    'skill(name="grill-me")\n' +
      'task(subagent_type="ossify-implementer-agent", prompt=<brief>)\n' +
      "Use question if needed.",
  );
});

test("prompt translation resolves package placeholders in either shell form", async () => {
  const { translatePrompt } = await import(translateUrl);
  const translated = translatePrompt(
    "${CLAUDE_PLUGIN_ROOT}/references/policy.md\n" +
      "${CLAUDE_PLUGIN_DATA}/run.json\n" +
      "$CLAUDE_PLUGIN_ROOT/templates/default.md\n" +
      "$CLAUDE_PLUGIN_DATA/cache.json",
    {
      root: "/opt/plugins/ai-mentor",
      dataRoot: "/var/data/ai-mentor",
    },
  );

  assert.equal(
    translated,
    "/opt/plugins/ai-mentor/references/policy.md\n" +
      "/var/data/ai-mentor/run.json\n" +
      "/opt/plugins/ai-mentor/templates/default.md\n" +
      "/var/data/ai-mentor/cache.json",
  );
});

test("prompt path substitution preserves replacement tokens literally", async () => {
  const { translatePrompt } = await import(translateUrl);
  const rootPath = "/tmp/plugin-$&-$'-$`";
  const dataPath = "/tmp/data-$&-$'-$`";

  assert.equal(
    translatePrompt("${CLAUDE_PLUGIN_ROOT}/artifact", {
      root: rootPath,
      dataRoot: "/tmp/data",
    }),
    `${rootPath}/artifact`,
  );
  assert.equal(
    translatePrompt("$CLAUDE_PLUGIN_DATA/artifact", {
      root: "/tmp/plugin",
      dataRoot: dataPath,
    }),
    `${dataPath}/artifact`,
  );
});

test("command translation is limited to selected canonical skills and aliases", async () => {
  const hooks = await createPluginHooks({ plugins: ["ossify"] });
  const selected = {
    parts: [{ type: "text", text: "Skill(ai-mentor:grill-me)" }],
  };
  await hooks["command.execute.before"](
    { command: "plan-spine", sessionID: "selected", arguments: "r1.s1" },
    selected,
  );
  assert.equal(selected.parts[0].text, 'skill(name="grill-me")');

  for (const command of ["critique", "project-command"]) {
    const unowned = {
      parts: [{ type: "text", text: "Skill(ai-mentor:grill-me)" }],
    };
    await hooks["command.execute.before"](
      { command, sessionID: "unowned", arguments: "" },
      unowned,
    );
    assert.equal(unowned.parts[0].text, "Skill(ai-mentor:grill-me)");
  }
});

test("caller-defined command collisions are not treated as package content", async () => {
  const hooks = await createPluginHooks({ plugins: ["architect-critic"] });
  const config = {
    command: {
      critique: { template: "Skill(ai-mentor:grill-me)" },
    },
  };
  await hooks.config(config);
  const output = {
    parts: [{ type: "text", text: config.command.critique.template }],
  };

  await hooks["command.execute.before"](
    { command: "critique", sessionID: "custom-command", arguments: "" },
    output,
  );

  assert.equal(output.parts[0].text, "Skill(ai-mentor:grill-me)");
});

test("skill output translation uses the canonical skill owner", async () => {
  const { getSkillOwner } = await import(catalogUrl);
  const hooks = await createPluginHooks({ plugins: ["ai-mentor"] });
  const owner = getSkillOwner("grill-me");
  const output = {
    output:
      "Policy: ${CLAUDE_PLUGIN_ROOT}/references/recommendation-policy.md\n" +
      "Use AskUserQuestion.",
  };

  await hooks["tool.execute.after"](
    {
      tool: "skill",
      sessionID: "skill-owner",
      callID: "call-1",
      args: { name: "grill-me" },
    },
    output,
  );

  assert.equal(
    output.output,
    `Policy: ${join(owner.root, "references/recommendation-policy.md")}\n` +
      "Use question.",
  );
});

test("read translation uses real targets within selected plugin roots", async (t) => {
  const { getSkillOwner } = await import(catalogUrl);
  const hooks = await createPluginHooks({ plugins: ["ai-mentor"] });
  const owner = getSkillOwner("grill-me");
  const inside = join(owner.root, "skills", "grill-me", "SKILL.md");
  const outsideDirectory = await mkdtemp(
    join(tmpdir(), "opencode-runtime-read-"),
  );
  const siblingDirectory = await mkdtemp(`${owner.root.slice(0, -1)}-copy-`);
  const outsideFile = join(outsideDirectory, "project-notes.md");
  const outsideToInside = join(outsideDirectory, "package-skill.md");
  const insideToOutside = join(
    owner.root,
    `.opencode-runtime-outside-${process.pid}-${Date.now()}.md`,
  );
  const siblingFile = join(siblingDirectory, "reference.md");
  const nonexistent = join(
    owner.root,
    `.opencode-runtime-missing-${process.pid}-${Date.now()}.md`,
  );
  t.after(async () => {
    await rm(insideToOutside, { force: true });
    await rm(outsideDirectory, { recursive: true, force: true });
    await rm(siblingDirectory, { recursive: true, force: true });
  });
  await writeFile(outsideFile, "project content", "utf8");
  await writeFile(siblingFile, "sibling content", "utf8");
  await symlink(inside, outsideToInside);
  await symlink(outsideFile, insideToOutside);

  const cases = [
    ["real package file", inside, true],
    ["outside symlink to package file", outsideToInside, true],
    ["package symlink to outside file", insideToOutside, false],
    ["existing sibling-prefix file", siblingFile, false],
    ["nonexistent package path", nonexistent, false],
  ];
  const source = "${CLAUDE_PLUGIN_ROOT}/marker AskUserQuestion";
  const translated = `${owner.root.slice(0, -1)}/marker question`;

  const mismatches = {};
  for (const [label, filePath, shouldTranslate] of cases) {
    const output = { output: source };
    await hooks["tool.execute.after"](
      {
        tool: "read",
        sessionID: "read-owner",
        callID: `read-${label}`,
        args: { filePath },
      },
      output,
    );
    const expected = shouldTranslate ? translated : source;
    if (output.output !== expected) {
      mismatches[label] = { actual: output.output, expected };
    }
  }
  assert.deepEqual(mismatches, {});
});

test("Architect Critic command arguments survive their message then expire", async () => {
  const hooks = await createPluginHooks({ plugins: ["architect-critic"] });
  const commandOutput = {
    parts: [{ type: "text", text: "Run the native skill." }],
  };
  await hooks["command.execute.before"](
    {
      command: "critique",
      sessionID: "command-session",
      arguments: 'SPEC.md --close',
    },
    commandOutput,
  );

  await hooks["chat.message"](
    { sessionID: "command-session" },
    { message: { role: "user" }, parts: commandOutput.parts },
  );
  const commandEnv = { env: {} };
  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "command-session" },
    commandEnv,
  );
  assert.equal(commandEnv.env.ARCHITECT_CRITIC_ARGS, "SPEC.md --close");

  await hooks["chat.message"](
    { sessionID: "command-session" },
    {
      message: { role: "user" },
      parts: [{ type: "text", text: "Now do something unrelated" }],
    },
  );
  const expiredEnv = { env: {} };
  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "command-session" },
    expiredEnv,
  );
  assert.ok(!Object.hasOwn(expiredEnv.env, "ARCHITECT_CRITIC_ARGS"));
});

test("standalone cross-skill literal exports carry arguments by session", async () => {
  const hooks = await createPluginHooks({
    plugins: ["architect-critic", "ossify"],
  });
  await hooks["tool.execute.before"](
    { tool: "bash", sessionID: "cross-skill", callID: "call-4" },
    {
      args: {
        command:
          'export ARCHITECT_CRITIC_ARGS="--spec \\"/tmp/SPINE.md\\" --close"',
      },
    },
  );

  const capturedEnv = { env: {} };
  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "cross-skill" },
    capturedEnv,
  );
  assert.equal(
    capturedEnv.env.ARCHITECT_CRITIC_ARGS,
    '--spec "/tmp/SPINE.md" --close',
  );

  await hooks["tool.execute.before"](
    { tool: "bash", sessionID: "single-quoted", callID: "call-5" },
    {
      args: {
        command:
          "export ARCHITECT_CRITIC_ARGS='--spec \"/tmp/SPINE 2.md\" --close'",
      },
    },
  );
  const singleQuotedEnv = { env: {} };
  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "single-quoted" },
    singleQuotedEnv,
  );
  assert.equal(
    singleQuotedEnv.env.ARCHITECT_CRITIC_ARGS,
    '--spec "/tmp/SPINE 2.md" --close',
  );

  const otherEnv = { env: {} };
  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "other-session" },
    otherEnv,
  );
  assert.ok(!Object.hasOwn(otherEnv.env, "ARCHITECT_CRITIC_ARGS"));

  await hooks["chat.message"](
    { sessionID: "cross-skill" },
    {
      message: { role: "user" },
      parts: [{ type: "text", text: "New request" }],
    },
  );
  const clearedEnv = { env: {} };
  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "cross-skill" },
    clearedEnv,
  );
  assert.ok(!Object.hasOwn(clearedEnv.env, "ARCHITECT_CRITIC_ARGS"));
});

test("cross-skill export capture rejects non-literal or compound shell", async () => {
  const hooks = await createPluginHooks({ plugins: ["architect-critic"] });
  const rejected = [
    ["variable expansion", 'export ARCHITECT_CRITIC_ARGS="--spec $spec --close"'],
    [
      "dollar command substitution",
      'export ARCHITECT_CRITIC_ARGS="--spec $(pwd)/SPEC.md --close"',
    ],
    [
      "backtick command substitution",
      'export ARCHITECT_CRITIC_ARGS="--spec `pwd`/SPEC.md --close"',
    ],
    ["unquoted value", "export ARCHITECT_CRITIC_ARGS=--close"],
    ["unterminated quote", 'export ARCHITECT_CRITIC_ARGS="--close'],
    [
      "comment",
      'export ARCHITECT_CRITIC_ARGS="--close" # retain this value',
    ],
    ["pipeline", 'export ARCHITECT_CRITIC_ARGS="--close" | cat'],
    [
      "following command",
      'export ARCHITECT_CRITIC_ARGS="--close"; printf done',
    ],
    [
      "preceding command",
      'printf ready\nexport ARCHITECT_CRITIC_ARGS="--close"',
    ],
    [
      "multiple lines",
      'export ARCHITECT_CRITIC_ARGS="--close"\nprintf done',
    ],
    [
      "heredoc",
      'cat <<EOF\nexport ARCHITECT_CRITIC_ARGS="--close"\nEOF',
    ],
  ];

  const captured = [];
  for (const [label, command] of rejected) {
    const sessionID = `rejected-${label}`;
    await hooks["tool.execute.before"](
      { tool: "bash", sessionID, callID: `call-${label}` },
      { args: { command } },
    );
    const output = { env: {} };
    await hooks["shell.env"](
      { cwd: fileURLToPath(root), sessionID },
      output,
    );
    if (Object.hasOwn(output.env, "ARCHITECT_CRITIC_ARGS")) {
      captured.push(label);
    }
  }
  assert.deepEqual(captured, []);
});
