import assert from "node:assert/strict";
import {
  mkdir,
  mkdtemp,
  readFile,
  realpath,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const marketplaceUrl = new URL(".opencode/plugins/marketplace.js", root);
const catalogUrl = new URL(".opencode/lib/catalog.js", root);
const markdownUrl = new URL(".opencode/lib/markdown.js", root);
const translateUrl = new URL(".opencode/lib/translate.js", root);
const ossifyAgentUrl = new URL("ossify/agents/implementer-agent.md", root);
const wrapperDirectory = fileURLToPath(new URL(".opencode/bin", root));
const selectedPluginsEnvironment = "OPENCODE_SCAFFOLDING_PLUGINS";

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

async function createRegisteredOssifyHooks() {
  const hooks = await createPluginHooks({ plugins: ["ossify"] });
  await hooks.config({});
  return hooks;
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

test("Ossify selection registers the translated canonical implementer agent", async () => {
  const config = await applyPluginConfig({ plugins: ["ossify"] }, {});
  const agent = config.agent["ossify-implementer-agent"];
  const canonical = await readFile(ossifyAgentUrl, "utf8");
  const { parseMarkdown } = await import(markdownUrl);
  const { frontmatter, body } = parseMarkdown(
    canonical,
    fileURLToPath(ossifyAgentUrl),
  );
  const ossifyRoot = fileURLToPath(new URL("ossify", root)).replace(/\/$/, "");

  assert.equal(agent.description, frontmatter.description);
  assert.equal(agent.mode, "subagent");
  assert.ok(!Object.hasOwn(agent, "model"));
  assert.equal(
    agent.prompt,
    body.replaceAll("${CLAUDE_PLUGIN_ROOT}", ossifyRoot),
  );
  assert.ok(!agent.prompt.includes("CLAUDE_PLUGIN_ROOT"));
  assert.ok(
    agent.prompt.includes(
      '{"mode": "complete", "report_path": "<abs path to report.md>", "summary": "<one-line>", "stage_status": "all_staged | partial | none"}',
    ),
  );
  assert.ok(
    agent.prompt.includes(
      '{"mode": "gaps-surfaced", "gaps": [{"section": "<ref>", "question": "<concrete question>", "severity": "blocking | nice-to-have"}, ...]}',
    ),
  );
  assert.match(agent.prompt, /You never commit\./);
  assert.deepEqual(Object.keys(agent.permission), [
    "*",
    "read",
    "edit",
    "glob",
    "grep",
    "bash",
    "task",
    "external_directory",
  ]);
  assert.deepEqual(agent.permission, {
    "*": "deny",
    read: "allow",
    edit: "allow",
    glob: "allow",
    grep: "allow",
    bash: "allow",
    task: "deny",
    external_directory: "ask",
  });
});

test("the Ossify implementer agent is absent unless Ossify is selected", async () => {
  const defaultConfig = await applyPluginConfig(undefined, {});
  const withoutOssify = await applyPluginConfig(
    { plugins: ["workspace-init", "ai-mentor"] },
    {},
  );

  assert.ok(!defaultConfig.agent?.["ossify-implementer-agent"]);
  assert.ok(!withoutOssify.agent?.["ossify-implementer-agent"]);
});

test("Ossify rejects caller config that collides with its reserved agent", async () => {
  const callerAgent = {
    description: "Caller-owned agent",
    mode: "subagent",
  };
  for (const existing of [callerAgent, undefined]) {
    const hooks = await createPluginHooks({ plugins: ["ossify"] });
    const config = {
      agent: { "ossify-implementer-agent": existing },
    };

    await assert.rejects(
      hooks.config(config),
      /ossify-implementer-agent.*reserved.*collision/i,
    );
    assert.ok(Object.hasOwn(config.agent, "ossify-implementer-agent"));
    assert.strictEqual(config.agent["ossify-implementer-agent"], existing);
  }
});

test("non-Ossify config preserves the same caller-defined agent name", async () => {
  const callerAgent = {
    description: "Caller-owned agent",
    mode: "subagent",
  };
  const config = {
    agent: { "ossify-implementer-agent": callerAgent },
  };

  await applyPluginConfig({ plugins: ["workspace-init"] }, config);

  assert.strictEqual(config.agent["ossify-implementer-agent"], callerAgent);
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

test("auto-skill command translation requires selected package base metadata", async (t) => {
  const { getSkillOwner } = await import(catalogUrl);
  const hooks = await createPluginHooks({ plugins: ["ossify"] });
  const owner = getSkillOwner("plan-spine");
  const canonicalDirectory = join(owner.root, "skills", "plan-spine");
  const externalDirectory = await mkdtemp(
    join(tmpdir(), "opencode-colliding-command-"),
  );
  t.after(() => rm(externalDirectory, { recursive: true, force: true }));
  await writeFile(
    join(externalDirectory, "SKILL.md"),
    "---\nname: plan-spine\ndescription: External collision\n---\nExternal",
    "utf8",
  );
  const invocation = "Skill(ai-mentor:grill-me)";
  const cases = [
    ["canonical marker", canonicalDirectory, true],
    ["external collision", externalDirectory, false],
    ["absent marker", undefined, false],
    ["malformed marker", "", false],
    ["unresolvable marker", join(externalDirectory, "missing"), false],
  ];

  const mismatches = {};
  for (const [label, baseDirectory, shouldTranslate] of cases) {
    const marker =
      baseDirectory === undefined
        ? ""
        : `\nBase directory for this skill: ${baseDirectory}`;
    const output = { parts: [{ type: "text", text: invocation + marker }] };
    await hooks["command.execute.before"](
      {
        command: "plan-spine",
        sessionID: `auto-${label}`,
        arguments: "r1.s1",
      },
      output,
    );
    const expected =
      (shouldTranslate ? 'skill(name="grill-me")' : invocation) + marker;
    if (output.parts[0].text !== expected) {
      mismatches[label] = { actual: output.parts[0].text, expected };
    }
  }
  assert.deepEqual(mismatches, {});

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

test("registered package aliases translate without skill base metadata", async () => {
  const hooks = await createPluginHooks({ plugins: ["architect-critic"] });
  await hooks.config({});
  const output = {
    parts: [{ type: "text", text: "Skill(ai-mentor:grill-me)" }],
  };

  await hooks["command.execute.before"](
    { command: "critique", sessionID: "registered-alias", arguments: "" },
    output,
  );

  assert.equal(output.parts[0].text, 'skill(name="grill-me")');
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

test("skill output translation requires selected package directory evidence", async (t) => {
  const { getSkillOwner } = await import(catalogUrl);
  const hooks = await createPluginHooks({ plugins: ["ai-mentor"] });
  const owner = getSkillOwner("grill-me");
  const canonicalDirectory = join(owner.root, "skills", "grill-me");
  const externalDirectory = await mkdtemp(
    join(tmpdir(), "opencode-colliding-skill-"),
  );
  t.after(() => rm(externalDirectory, { recursive: true, force: true }));
  await writeFile(
    join(externalDirectory, "SKILL.md"),
    "---\nname: grill-me\ndescription: External collision\n---\nExternal",
    "utf8",
  );
  const source =
    "Policy: ${CLAUDE_PLUGIN_ROOT}/references/recommendation-policy.md\n" +
    "Use AskUserQuestion.";
  const translated =
    `Policy: ${join(owner.root, "references/recommendation-policy.md")}\n` +
    "Use question.";
  const cases = [
    ["canonical directory", { dir: canonicalDirectory }, translated],
    ["external collision", { dir: externalDirectory }, source],
    ["absent metadata", undefined, source],
    ["malformed metadata", { dir: 42 }, source],
    [
      "unresolvable metadata",
      { dir: join(externalDirectory, "missing") },
      source,
    ],
  ];

  const mismatches = {};
  for (const [label, metadata, expected] of cases) {
    const output = { output: source, metadata };
    await hooks["tool.execute.after"](
      {
        tool: "skill",
        sessionID: "skill-owner",
        callID: `skill-${label}`,
        args: { name: "grill-me" },
      },
      output,
    );
    if (output.output !== expected) {
      mismatches[label] = { actual: output.output, expected };
    }
  }
  assert.deepEqual(mismatches, {});
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
  await hooks.config({});
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

test("Ossify implementer sessions reject forbidden Git verbs anywhere in bash logs", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const forbidden = [
    ["ordinary commit", "git commit -m work"],
    ["ordinary push", "git push origin topic"],
    ["ordinary pull", "git pull --ff-only"],
    ["ordinary fetch", "git fetch --all"],
    ["worktree option", "git -C /tmp/worktree commit -m work"],
    ["git directory option", "git --git-dir /tmp/repo/.git push"],
    ["equals git directory", "git --git-dir=/tmp/repo/.git pull"],
    [
      "work tree option",
      "git --git-dir=/tmp/repo/.git --work-tree /tmp/repo fetch",
    ],
    ["config option", "git -c user.name=worker commit -m work"],
    [
      "combined global options",
      "git -C /tmp/repo -c user.email=worker@example.test push",
    ],
    ["absolute executable", "/usr/bin/git commit -m work"],
    ["path executable", "./tools/git fetch origin"],
    ["quoted executable", "\"/usr/local/bin/git\" pull"],
    ["single-quoted full command", "printf '%s\\n' 'git commit -m work'"],
    ["double-quoted full command", 'printf "%s\\n" "git fetch --all"'],
    ["ANSI-C nested commit", "bash -c $'git commit -m nested'"],
    ["ANSI-C eval push", "eval $'git push origin topic'"],
    [
      "ANSI-C hex whitespace",
      String.raw`bash -c $'git\x20commit -m nested'`,
    ],
    [
      "ANSI-C eval hex whitespace",
      String.raw`eval $'git\x20push origin topic'`,
    ],
    ["ANSI-C tab whitespace", String.raw`bash -c $'git\tpull --ff-only'`],
    ["ANSI-C octal whitespace", String.raw`bash -c $'git\040fetch --all'`],
    [
      "ANSI-C short Unicode whitespace",
      String.raw`bash -c $'git\u0020commit -m nested'`,
    ],
    [
      "ANSI-C long Unicode whitespace",
      String.raw`bash -c $'git\U00000020push origin topic'`,
    ],
    ["quoted executable piece", "/usr/bin/'git' fetch origin"],
    [
      "review repro quoted worktree",
      'git -C "/tmp/ossify worktree" commit -m work',
    ],
    [
      "review repro quoted git directories",
      'git --git-dir "/tmp/repo data/.git" --work-tree "/tmp/work tree" push',
    ],
    [
      "review repro quoted executable and exec path",
      '"/opt/git tools/bin/git" --exec-path="/opt/git tools/libexec" fetch',
    ],
    [
      "escaped worktree whitespace",
      String.raw`git -C /tmp/ossify\ worktree pull`,
    ],
    ["namespace equals", 'git --namespace="worker namespace" commit'],
    ["super prefix", 'git --super-prefix "worker prefix/" push'],
    [
      "config environment",
      "git --config-env safe.directory=SAFE_DIRECTORY fetch",
    ],
    ["attribute source", 'git --attr-source "topic branch" commit'],
    ["comment", 'git status --short # never run "git fetch" here'],
    ["leading hash boundary", "#git commit -m work"],
    ["inline hash boundary", "echo ok #git fetch --all"],
    ["quoted hash boundary", `printf '%s\\n' "#git push origin topic"`],
    [
      "heredoc",
      'cat <<\'EOF\' > instructions.txt\nNever run "git pull" here.\nEOF',
    ],
    [
      "heredoc hash boundary",
      'cat <<\'EOF\' > instructions.txt\n"#git pull"\nEOF',
    ],
    ["pipeline", "printf ready | git fetch origin"],
    ["tab whitespace", "git\tcommit -m work"],
    ["multiline whitespace", "git\nfetch --all"],
  ];

  const rejected = [];
  for (const [label, command] of forbidden) {
    const sessionID = `ossify-forbidden-${label}`;
    await hooks["chat.message"](
      { sessionID, agent: "ossify-implementer-agent" },
      { message: { role: "user" }, parts: [] },
    );
    await assert.rejects(
      hooks["tool.execute.before"](
        { tool: "bash", sessionID, callID: `call-${label}` },
        { args: { command } },
      ),
      /ossify-implementer-agent.*git (?:commit|push|pull|fetch)/i,
    );
    rejected.push(label);
  }

  assert.deepEqual(
    rejected,
    forbidden.map(([label]) => label),
  );
});

test("Ossify Git guard allows only canonical operations in representative literal forms", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-allowed-git";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const operations = [
    "status --porcelain",
    "rev-parse --abbrev-ref HEAD",
    "diff --cached",
    "add -A",
  ];
  const allowed = operations.flatMap((operation) => [
    `git ${operation}`,
    `/usr/bin/git ${operation}`,
    `git -C /tmp/worktree --git-dir=.git -c color.ui=false ${operation}`,
    `'git ${operation}'`,
    `bash -c "git ${operation}"`,
  ]);
  allowed.push(
    "git --exec-path commit",
    "git --html-path commit",
    "git --man-path push",
    "git --info-path pull",
    "git --version fetch",
    "git -v commit",
    "git --help push",
    "git -h pull",
    "git --list-cmds commit",
    "git --list-cmds=builtins commit",
    "git --config-env safe.directory=SAFE_DIRECTORY status --short",
    "git -ccolor.ui=false status --short",
    'git -C /tmp/"repo data" status --short',
    'git -c color.ui="auto always" status --short',
    "git --version; commit is-a-different-command",
    "npm test",
    "printf '%s\\n' ready",
    "cat <<'EOF'\nit's ready\nEOF",
  );

  for (const [index, command] of allowed.entries()) {
    const output = { args: { command, description: "unchanged" } };
    const before = structuredClone(output);
    await hooks["tool.execute.before"](
      { tool: "bash", sessionID, callID: `allowed-${index}` },
      output,
    );
    assert.deepEqual(output, before, command);
  }
});

test("Ossify Git guard rejects aliases and every non-canonical Git subcommand", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-git-aliases";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const forbidden = [
    [
      "direct commit",
      "git -c alias.ci=commit ci -m work",
      /inline git alias/i,
    ],
    [
      "direct pull",
      "git -c alias.update=pull update --ff-only",
      /inline git alias/i,
    ],
    [
      "shell push",
      "git -c 'alias.publish=!git push origin topic' publish",
      /inline git alias/i,
    ],
    [
      "shell fetch",
      "git -c 'alias.sync=!git fetch --all' sync",
      /inline git alias/i,
    ],
    [
      "chained aliases",
      "git -c alias.a=b -c alias.b=commit a",
      /inline git alias/i,
    ],
    [
      "case-insensitive alias key",
      "git -c ALIAS.ci=commit ci",
      /inline git alias/i,
    ],
    [
      "attached alias config",
      "git -calias.ci=commit status",
      /inline git alias/i,
    ],
    [
      "attached uppercase alias config",
      "git -cALIAS.ci=commit status",
      /inline git alias/i,
    ],
    [
      "attached mixed-case alias config",
      "git -cAlias.CI=commit status",
      /inline git alias/i,
    ],
    [
      "attached equals alias config",
      "git -c=alias.ci=commit status",
      /inline git alias/i,
    ],
    [
      "config environment alias",
      "COMMIT_ALIAS=commit git --config-env=alias.ci=COMMIT_ALIAS ci",
      /inline git alias/i,
    ],
    [
      "separate config environment alias",
      "COMMIT_ALIAS=commit git --config-env ALIAS.ci=COMMIT_ALIAS ci",
      /inline git alias/i,
    ],
    [
      "safe direct alias",
      "git -c alias.st=status st --short",
      /inline git alias/i,
    ],
    [
      "safe config environment alias",
      "SAFE_ALIAS=status git --config-env=alias.st=SAFE_ALIAS st --short",
      /inline git alias/i,
    ],
    [
      "unknown configured alias",
      "git ci -m work",
      /unknown git subcommand.*ci/i,
    ],
    [
      "environment-configured alias",
      "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.ci GIT_CONFIG_VALUE_0=commit git ci -m work",
      /unknown git subcommand.*ci/i,
    ],
    [
      "quoted unknown path-qualified operation",
      "printf '%s\\n' '/usr/bin/git banana'",
      /unknown git subcommand.*banana/i,
    ],
    ["branch builtin", "git branch --show-current", /git subcommand.*branch/i],
    ["log builtin", "git log -1 --oneline", /git subcommand.*log/i],
    ["show builtin", "git show --stat HEAD", /git subcommand.*show/i],
    ["worktree builtin", "git worktree list", /git subcommand.*worktree/i],
    [
      "repository alias using version-dependent repo name",
      "git -C /tmp/repo repo",
      /git subcommand.*repo/i,
    ],
    [
      "environment alias using version-dependent backfill name",
      "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.backfill GIT_CONFIG_VALUE_0=status git backfill",
      /git subcommand.*backfill/i,
    ],
    ["deprecated stage name", "git stage -A", /git subcommand.*stage/i],
    [
      "allowed occurrence before denied occurrence",
      `printf '%s\\n' "git status; git branch --show-current"`,
      /git subcommand.*branch/i,
    ],
    [
      "nested allowed occurrence before forbidden occurrence",
      "bash -c 'git status; git commit -m nested'",
      /git commit/i,
    ],
    [
      "deprecated whatchanged name",
      "git whatchanged --oneline",
      /git subcommand.*whatchanged/i,
    ],
    [
      "safe inline config before non-canonical operation",
      "git -c color.ui=false branch --show-current",
      /git subcommand.*branch/i,
    ],
    [
      "inline config without a canonical operation",
      "git -c color.ui=false",
      /canonical git subcommand/i,
    ],
    [
      "dispatcher builtin",
      "git for-each-repo --config=maintenance.repo commit",
      /git subcommand.*for-each-repo/i,
    ],
  ];

  for (const [label, command, error] of forbidden) {
    await assert.rejects(
      hooks["tool.execute.before"](
        { tool: "bash", sessionID, callID: `alias-${label}` },
        { args: { command } },
      ),
      error,
      label,
    );
  }
});

test("Ossify Git guard normalizes shell quote syntax across the full command text", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-nested-shell";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const forbidden = [
    ["bash commit", "bash -c 'git commit -m nested'"],
    ["path sh push", '"/bin/sh" -c "git push origin topic"'],
    ["path zsh pull", "/bin/zsh -c 'git pull --ff-only'"],
    ["eval fetch", "eval 'git fetch --all'"],
    ["nested eval", `bash -c "eval 'git commit -m deep'"`],
    ["bash separator commit", 'bash -c -- "git commit -m nested"'],
    ["sh separator push", "sh -c -- 'git push origin topic'"],
    ["zsh separator fetch", "zsh -c -- 'git fetch --all'"],
    ["combined bash options", "bash -lc -- 'git pull --ff-only'"],
    ["combined sh options", "sh -xec -- 'git commit -m nested'"],
    ["single-quoted prose", "printf '%s\\n' 'git commit -m nested'"],
    ["double-quoted prose", 'printf "%s\\n" "git fetch --all"'],
    ["ANSI-C shell string", "bash -c $'git push origin topic'"],
    ["ANSI-C eval string", "eval $'git pull --ff-only'"],
  ];

  for (const [label, command] of forbidden) {
    await assert.rejects(
      hooks["tool.execute.before"](
        { tool: "bash", sessionID, callID: `nested-${label}` },
        { args: { command } },
      ),
      /ossify-implementer-agent.*git (?:commit|push|pull|fetch)/i,
      label,
    );
  }

  for (const command of [
    "sh -c 'git status --short'",
    'bash -c "git diff --cached"',
    "zsh -c 'git add -A'",
    "eval 'git rev-parse HEAD'",
    "bash -c -- 'git status --short'",
    "sh -ec -- 'git diff --cached'",
    "zsh -fc -- 'git add -A'",
  ]) {
    const output = { args: { command } };
    await hooks["tool.execute.before"](
      { tool: "bash", sessionID, callID: `allowed-nested-${command}` },
      output,
    );
    assert.equal(output.args.command, command);
  }
});

test("Ossify Git guard is not a shell validator", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-literal-audit-not-shell-validator";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const allowed = [
    "cat <<'EOF'\nit's ready\nEOF",
    "printf %s it's",
    "printf %s it's; git -C /tmp status",
    "bash -c",
    "sh -xec --",
  ];
  for (const [index, command] of allowed.entries()) {
    const output = { args: { command } };
    await hooks["tool.execute.before"](
      { tool: "bash", sessionID, callID: `literal-audit-${index}` },
      output,
    );
    assert.equal(output.args.command, command);
  }
});

test("Ossify Git guard decodes bounded ANSI-C whitespace escapes", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-ansi-c-whitespace";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const forbidden = [
    ["hex tab", String.raw`bash -c $'git\x09commit -m nested'`],
    ["three-digit octal tab", String.raw`bash -c $'git\011push origin topic'`],
    ["two-digit octal tab", String.raw`bash -c $'git\11pull --ff-only'`],
    ["short Unicode tab", String.raw`bash -c $'git\u0009fetch --all'`],
    ["long Unicode tab", String.raw`bash -c $'git\U00000009commit -m nested'`],
  ];
  const accepted = [];
  for (const [label, command] of forbidden) {
    try {
      await hooks["tool.execute.before"](
        { tool: "bash", sessionID, callID: `ansi-whitespace-${label}` },
        { args: { command } },
      );
      accepted.push(label);
    } catch (error) {
      assert.match(
        error.message,
        /ossify-implementer-agent.*git (?:commit|push|pull|fetch)/i,
        label,
      );
    }
  }
  assert.deepEqual(accepted, []);
});

test("Ossify Git guard preserves shell-concatenated option pieces", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-concatenated-options";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const aliases = [
    'git -ca"lias".ci=commit status',
    'git -calias"."ci=commit status',
    'git -c a"lias".ci=commit status',
    'git --config-env=a"lias".ci=ENV status',
  ];
  const accepted = [];
  for (const [index, command] of aliases.entries()) {
    try {
      await hooks["tool.execute.before"](
        { tool: "bash", sessionID, callID: `concatenated-alias-${index}` },
        { args: { command } },
      );
      accepted.push(command);
    } catch (error) {
      assert.match(error.message, /inline git alias/i, command);
    }
  }
  assert.deepEqual(accepted, []);

  for (const [index, command] of [
    'git -cu"ser".name=worker status',
    'git -c u"ser".name=worker status',
    'git --config-env=c"olor".ui=ENV status',
  ].entries()) {
    await hooks["tool.execute.before"](
      { tool: "bash", sessionID, callID: `concatenated-safe-${index}` },
      { args: { command } },
    );
  }
});

test("Ossify Git guard keeps quoted separators inside option values", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-quoted-option-separators";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const allowed = [
    'git -c user.name="A#B" status',
    'git -C "/tmp/#repo" status',
    'git -c core.editor="printf a;b" diff',
  ];
  const rejected = [];
  for (const [index, command] of allowed.entries()) {
    try {
      await hooks["tool.execute.before"](
        { tool: "bash", sessionID, callID: `quoted-separator-${index}` },
        { args: { command } },
      );
    } catch (error) {
      rejected.push([command, error.message]);
    }
  }
  assert.deepEqual(rejected, []);
});

test("Ossify Git guard treats contraction apostrophes as plain text", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-contraction-apostrophe";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const command = "printf %s it's git -C /tmp status";

  await hooks["tool.execute.before"](
    { tool: "bash", sessionID, callID: "contraction-apostrophe" },
    { args: { command } },
  );
});

test("Git guard applies only to Ossify implementer bash sessions", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const cases = [
    ["untracked session", "bash", "untracked"],
    ["other agent", "bash", "other-agent"],
    ["non-bash tool", "read", "ossify-read"],
  ];
  await hooks["chat.message"](
    { sessionID: "other-agent", agent: "build" },
    { message: { role: "user" }, parts: [] },
  );
  await hooks["chat.message"](
    { sessionID: "ossify-read", agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );

  for (const [label, tool, sessionID] of cases) {
    const output = { args: { command: "git commit -m work" } };
    const before = structuredClone(output);
    await hooks["tool.execute.before"](
      { tool, sessionID, callID: label },
      output,
    );
    assert.deepEqual(output, before, label);
  }

  await hooks["chat.message"](
    { sessionID: "ossify-read", agent: "build" },
    { message: { role: "user" }, parts: [] },
  );
  await hooks["tool.execute.before"](
    { tool: "bash", sessionID: "ossify-read", callID: "agent-changed" },
    { args: { command: "git push" } },
  );
});

test("chat messages without a valid agent preserve tracked session identity", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const followups = [
    ["missing", {}],
    ["undefined", { agent: undefined }],
    ["empty", { agent: "" }],
    ["blank", { agent: "   " }],
  ];

  for (const [label, followup] of followups) {
    const sessionID = `ossify-agent-preserved-${label}`;
    await hooks["chat.message"](
      { sessionID, agent: "ossify-implementer-agent" },
      { message: { role: "user" }, parts: [] },
    );
    await hooks["chat.message"](
      { sessionID, ...followup },
      { message: { role: "user" }, parts: [] },
    );

    await assert.rejects(
      hooks["tool.execute.before"](
        { tool: "bash", sessionID, callID: `preserved-${label}` },
        { args: { command: "git commit -m work" } },
      ),
      /ossify-implementer-agent.*git commit/i,
      label,
    );
  }
});

test("Git guard does not trust reserved-name sessions before agent registration", async () => {
  const hooks = await createPluginHooks({ plugins: ["ossify"] });
  const sessionID = "ossify-unvalidated-agent";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const output = { args: { command: "git commit -m work" } };

  await hooks["tool.execute.before"](
    { tool: "bash", sessionID, callID: "unvalidated-agent" },
    output,
  );

  assert.equal(output.args.command, "git commit -m work");
});

test("Git guard fails closed on malformed Ossify implementer bash calls", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-malformed-bash";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );

  for (const command of [undefined, null, 42]) {
    await assert.rejects(
      hooks["tool.execute.before"](
        {
          tool: "bash",
          sessionID: "untracked",
          callID: `malformed-${command}`,
        },
        { args: { command } },
      ),
      /valid bash command/i,
    );
  }

  for (const invalidSessionID of [undefined, null, "", "   ", 42]) {
    await assert.rejects(
      hooks["tool.execute.before"](
        {
          tool: "bash",
          sessionID: invalidSessionID,
          callID: `malformed-session-${invalidSessionID}`,
        },
        { args: { command: "git status --short" } },
      ),
      /valid nonempty sessionID/i,
    );
  }

  const nonBashOutput = { args: { command: 42 } };
  const before = structuredClone(nonBashOutput);
  await hooks["tool.execute.before"](
    { tool: "read", callID: "non-bash-malformed" },
    nonBashOutput,
  );
  assert.deepEqual(nonBashOutput, before);
});

test("Git guard boundary excludes deliberately shell-obfuscated executable names", async () => {
  const hooks = await createRegisteredOssifyHooks();
  const sessionID = "ossify-obfuscated-git";
  await hooks["chat.message"](
    { sessionID, agent: "ossify-implementer-agent" },
    { message: { role: "user" }, parts: [] },
  );
  const boundaryExamples = [
    "g''it commit -m work",
    "$GIT push origin topic",
    String.raw`bash -c $'\x67it commit -m work'`,
  ];

  for (const command of boundaryExamples) {
    const output = { args: { command } };
    await hooks["tool.execute.before"](
      { tool: "bash", sessionID, callID: `boundary-${command}` },
      output,
    );
    assert.equal(output.args.command, command);
  }
});

test("shell environment exposes capabilities and prepends wrappers idempotently", async () => {
  const hooks = await createPluginHooks();
  const callerPath = ["/caller/bin", wrapperDirectory, "/caller/tools"].join(
    delimiter,
  );
  const output = { env: { PATH: callerPath } };

  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "wrapper-path" },
    output,
  );
  await hooks["shell.env"](
    { cwd: fileURLToPath(root), sessionID: "wrapper-path" },
    output,
  );

  assert.deepEqual(output.env.PATH.split(delimiter), [
    wrapperDirectory,
    "/caller/bin",
    "/caller/tools",
  ]);
  assert.equal(
    output.env[selectedPluginsEnvironment],
    expectedPlugins.slice(0, 3).join(":"),
  );
});

test("default capabilities reject the experimental oss wrapper", async (t) => {
  const fixture = await mkdtemp(join(tmpdir(), "opencode-wrapper-default-"));
  t.after(() => rm(fixture, { recursive: true, force: true }));
  const hooks = await createPluginHooks();
  const output = { env: { PATH: process.env.PATH ?? "" } };
  await hooks["shell.env"](
    { cwd: fixture, sessionID: "default-wrapper" },
    output,
  );

  const result = spawnSync("oss", ["--help"], {
    cwd: fixture,
    encoding: "utf8",
    env: { ...process.env, ...output.env },
  });

  assert.equal(result.status, 2);
  assert.equal(result.stdout, "");
  assert.match(result.stderr, /ossify.*not selected/i);
});

test("each wrapper rejects execution when its owning plugin is not selected", async (t) => {
  const fixture = await mkdtemp(join(tmpdir(), "opencode-wrapper-rejection-"));
  t.after(() => rm(fixture, { recursive: true, force: true }));
  const hooks = await createPluginHooks({ plugins: ["ai-mentor"] });
  const output = { env: { PATH: process.env.PATH ?? "" } };
  await hooks["shell.env"](
    { cwd: fixture, sessionID: "unselected-wrappers" },
    output,
  );

  for (const [command, owner] of [
    ["wi", "workspace-init"],
    ["arc", "architect-critic"],
    ["oss", "ossify"],
  ]) {
    const result = spawnSync(command, ["--list"], {
      cwd: fixture,
      encoding: "utf8",
      env: { ...process.env, ...output.env },
    });
    assert.equal(result.status, 2, command);
    assert.equal(result.stdout, "", command);
    assert.match(result.stderr, new RegExp(`${owner}.*not selected`, "i"));
  }
});

test("arc wrapper exports the shared Architect Critic data fallback", async (t) => {
  const fixture = await mkdtemp(join(tmpdir(), "opencode-wrapper-arc-data-"));
  t.after(() => rm(fixture, { recursive: true, force: true }));
  const adapterBin = join(fixture, ".opencode", "bin");
  const canonicalBin = join(fixture, "architect-critic", "bin");
  const home = join(fixture, "home");
  await mkdir(adapterBin, { recursive: true });
  await mkdir(canonicalBin, { recursive: true });
  await mkdir(home);
  await writeFile(
    join(adapterBin, "arc"),
    await readFile(join(wrapperDirectory, "arc"), "utf8"),
    { encoding: "utf8", mode: 0o755 },
  );
  await writeFile(
    join(canonicalBin, "arc"),
    '#!/bin/sh\nprintf "%s\\n" "${CLAUDE_PLUGIN_DATA-}"\n',
    { encoding: "utf8", mode: 0o755 },
  );
  const env = {
    ...process.env,
    HOME: home,
    OPENCODE_SCAFFOLDING_PLUGINS: "architect-critic",
  };
  delete env.CLAUDE_PLUGIN_DATA;

  const result = spawnSync(join(adapterBin, "arc"), [], {
    cwd: await realpath(fixture),
    encoding: "utf8",
    env,
  });

  assert.equal(result.status, 0);
  assert.equal(result.stderr, "");
  assert.equal(result.stdout, `${join(home, ".claude/architect-critic")}\n`);
});

test("arc wrapper reaches canonical --list without HOME or plugin data", () => {
  const env = {
    PATH: ["/usr/bin", "/bin"].join(delimiter),
    OPENCODE_SCAFFOLDING_PLUGINS: "architect-critic",
  };
  const args = ["--list"];
  const wrapped = spawnSync(join(wrapperDirectory, "arc"), args, {
    encoding: "utf8",
    env,
  });
  const canonical = spawnSync(
    fileURLToPath(new URL("architect-critic/bin/arc", root)),
    args,
    { encoding: "utf8", env },
  );

  assert.deepEqual(
    {
      status: wrapped.status,
      stdout: wrapped.stdout,
      stderr: wrapped.stderr,
    },
    {
      status: canonical.status,
      stdout: canonical.stdout,
      stderr: canonical.stderr,
    },
  );
  assert.equal(wrapped.status, 0);
});

test("all-four capabilities self-locate wi and arc without changing output", async (t) => {
  const fixture = await mkdtemp(join(tmpdir(), "opencode-wrapper-location-"));
  t.after(() => rm(fixture, { recursive: true, force: true }));
  const hooks = await createPluginHooks({ plugins: expectedPlugins });
  const output = { env: { PATH: process.env.PATH ?? "" } };
  await hooks["shell.env"](
    { cwd: fixture, sessionID: "all-wrapper-location" },
    output,
  );
  const env = {
    ...process.env,
    ...output.env,
    CLAUDE_PLUGIN_ROOT: "/stale/plugin/root",
    PLUGIN_ROOT: "/stale/plugin/root",
  };

  assert.equal(
    env[selectedPluginsEnvironment],
    expectedPlugins.join(":"),
  );
  for (const [command, canonical] of [
    ["wi", fileURLToPath(new URL("workspace-init/bin/wi", root))],
    ["arc", fileURLToPath(new URL("architect-critic/bin/arc", root))],
  ]) {
    const wrapped = spawnSync(command, ["--list"], {
      cwd: fixture,
      encoding: "utf8",
      env,
    });
    const direct = spawnSync(canonical, ["--list"], {
      cwd: fixture,
      encoding: "utf8",
      env,
    });
    assert.deepEqual(
      {
        status: wrapped.status,
        stdout: wrapped.stdout,
        stderr: wrapped.stderr,
      },
      { status: direct.status, stdout: direct.stdout, stderr: direct.stderr },
      `${command} wrapper must preserve its canonical dispatcher result`,
    );
    assert.equal(wrapped.status, 0);
    assert.notEqual(wrapped.stdout, "");
  }
});

test("oss wrapper preserves verify_step and redgate dispositions", async (t) => {
  const fixture = await mkdtemp(join(tmpdir(), "opencode-wrapper-gates-"));
  t.after(() => rm(fixture, { recursive: true, force: true }));
  await writeFile(join(fixture, "passes"), "#!/bin/sh\nexit 0\n", {
    encoding: "utf8",
    mode: 0o755,
  });
  await writeFile(join(fixture, "fails"), "#!/bin/sh\nexit 1\n", {
    encoding: "utf8",
    mode: 0o755,
  });

  const hooks = await createPluginHooks({ plugins: expectedPlugins });
  const output = { env: { PATH: process.env.PATH ?? "" } };
  await hooks["shell.env"](
    { cwd: fixture, sessionID: "all-wrapper-gates" },
    output,
  );
  const env = { ...process.env, ...output.env, OSS_ROOT: "/stale/ossify" };
  const canonical = fileURLToPath(new URL("ossify/bin/oss", root));
  const cases = [
    ["verify_step pass", ["verify_step", fixture, "./fails", "exit 1"], 0],
    ["verify_step failure", ["verify_step", fixture, "./fails", "exit 0"], 1],
    ["verify_step malformed", ["verify_step", fixture, "./passes", "invalid"], 2],
    ["redgate RED", ["redgate", fixture, "./fails", "exit 0"], 0],
    ["redgate already GREEN", ["redgate", fixture, "./passes", "exit 0"], 1],
    ["redgate error", ["redgate", fixture, "./missing", "exit 0"], 2],
  ];

  for (const [label, args, status] of cases) {
    const wrapped = spawnSync("oss", args, {
      cwd: fixture,
      encoding: "utf8",
      env,
    });
    const direct = spawnSync(canonical, args, {
      cwd: fixture,
      encoding: "utf8",
      env,
    });
    assert.deepEqual(
      {
        status: wrapped.status,
        stdout: wrapped.stdout,
        stderr: wrapped.stderr,
      },
      { status: direct.status, stdout: direct.stdout, stderr: direct.stderr },
      `${label} must pass through unchanged`,
    );
    assert.equal(wrapped.status, status, label);
  }
});
