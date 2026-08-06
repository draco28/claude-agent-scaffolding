import { resolveEnabledPlugins } from "../lib/catalog.js";

export async function ScaffoldingPlugin(input, options = {}) {
  void input;
  resolveEnabledPlugins(options);
  return {};
}
