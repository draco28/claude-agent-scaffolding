import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const marketplaceUrl = new URL(".opencode/plugins/marketplace.js", root);
const catalogUrl = new URL(".opencode/lib/catalog.js", root);
const markdownUrl = new URL(".opencode/lib/markdown.js", root);

async function applyPluginConfig(options, config = {}) {
  const { ScaffoldingPlugin } = await import(marketplaceUrl);
  const hooks = await ScaffoldingPlugin({}, options);
  await hooks.config(config);
  return config;
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
  assert.deepEqual(Object.keys(hooks), ["config"]);
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
