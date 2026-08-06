function parseScalar(value) {
  if (value.startsWith('"') && value.endsWith('"')) {
    return JSON.parse(value);
  }
  if (value.startsWith("'") && value.endsWith("'")) {
    return value.slice(1, -1).replaceAll("''", "'");
  }
  return value;
}

export function parseMarkdown(source) {
  if (typeof source !== "string") {
    throw new TypeError("markdown source must be a string");
  }

  const lines = source.replaceAll("\r\n", "\n").split("\n");
  if (lines[0] !== "---") {
    throw new Error("markdown must start with frontmatter");
  }

  const closingDelimiter = lines.indexOf("---", 1);
  if (closingDelimiter === -1) {
    throw new Error("markdown frontmatter is not closed");
  }

  const frontmatter = {};
  for (const line of lines.slice(1, closingDelimiter)) {
    if (!line.trim()) continue;

    const separator = line.indexOf(":");
    if (separator === -1) {
      throw new Error(`invalid frontmatter line: ${line}`);
    }

    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim();
    frontmatter[key] = parseScalar(value);
  }

  return {
    frontmatter,
    body: lines.slice(closingDelimiter + 1).join("\n").trim(),
  };
}
