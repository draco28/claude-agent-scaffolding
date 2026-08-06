import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const marketplaceUrl = new URL(".opencode/plugins/marketplace.js", root);
const catalogUrl = new URL(".opencode/lib/catalog.js", root);

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

test("root package declares the OpenCode bundle contract", async () => {
  const packageJson = JSON.parse(
    await readFile(new URL("package.json", root), "utf8"),
  );

  assert.equal(packageJson.name, "claude-agent-scaffolding-opencode");
  assert.equal(packageJson.version, "0.1.0");
  assert.equal(packageJson.type, "module");
  assert.equal(packageJson.exports, "./.opencode/plugins/marketplace.js");
  assert.deepEqual(packageJson.engines, { opencode: ">=1.18.13" });
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

  assert.deepEqual(await ScaffoldingPlugin({}, { plugins: ["ossify"] }), {});
  await assert.rejects(
    ScaffoldingPlugin({}, { plugins: ["scaffold"] }),
    /Unknown OpenCode plugin: scaffold/,
  );
});
