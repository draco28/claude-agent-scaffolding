function frontmatterError(context, lineNumber, message) {
  throw new Error(`${context}: frontmatter line ${lineNumber}: ${message}`);
}

function parseScalar(key, value, context, lineNumber) {
  if (value.startsWith('"') || value.endsWith('"')) {
    try {
      const parsed = JSON.parse(value);
      if (typeof parsed !== "string") throw new Error();
      return parsed;
    } catch {
      frontmatterError(context, lineNumber, "invalid double-quoted value");
    }
  }

  if (value.startsWith("'") || value.endsWith("'")) {
    if (!value.startsWith("'") || !value.endsWith("'") || value.length < 2) {
      frontmatterError(context, lineNumber, "invalid single-quoted value");
    }

    let parsed = "";
    const inner = value.slice(1, -1);
    for (let index = 0; index < inner.length; index += 1) {
      if (inner[index] !== "'") {
        parsed += inner[index];
      } else if (inner[index + 1] === "'") {
        parsed += "'";
        index += 1;
      } else {
        frontmatterError(context, lineNumber, "invalid single-quoted value");
      }
    }
    return parsed;
  }

  if (key === "allowed-tools") {
    try {
      const parsed = JSON.parse(value);
      if (
        !Array.isArray(parsed) ||
        !parsed.every((item) => typeof item === "string")
      ) {
        throw new Error();
      }
      return parsed;
    } catch {
      frontmatterError(context, lineNumber, "invalid string list");
    }
  }
  if (value.startsWith("[") && key !== "argument-hint") {
    frontmatterError(context, lineNumber, "flow sequence");
  }

  if (/^[|>]/.test(value)) {
    frontmatterError(context, lineNumber, "block scalar");
  }
  if (/(^|\s)#/.test(value)) {
    frontmatterError(context, lineNumber, "ambiguous comment");
  }
  if (value.startsWith("{")) {
    frontmatterError(context, lineNumber, "flow mapping");
  }
  if (value.startsWith("&")) {
    frontmatterError(context, lineNumber, "anchor");
  }
  if (value.startsWith("*")) {
    frontmatterError(context, lineNumber, "alias");
  }
  if (
    value.startsWith("!") ||
    value.startsWith("%") ||
    value.startsWith("- ") ||
    value.startsWith("? ") ||
    value.startsWith("@") ||
    value.startsWith("`")
  ) {
    frontmatterError(context, lineNumber, "unsupported YAML construct");
  }

  return value;
}

export function parseMarkdown(source, context = "markdown") {
  if (typeof source !== "string") {
    throw new TypeError(`${context}: markdown source must be a string`);
  }

  const lines = source.replaceAll("\r\n", "\n").split("\n");
  if (lines[0] !== "---") {
    throw new Error(`${context}: markdown must start with frontmatter`);
  }

  const closingDelimiter = lines.indexOf("---", 1);
  if (closingDelimiter === -1) {
    throw new Error(`${context}: markdown frontmatter is not closed`);
  }

  const frontmatter = {};
  for (let index = 1; index < closingDelimiter; index += 1) {
    const line = lines[index];
    const lineNumber = index + 1;
    if (!line) continue;
    if (/^\s/.test(line)) {
      frontmatterError(context, lineNumber, "indented or nested value");
    }

    const separator = line.indexOf(":");
    if (separator <= 0) {
      frontmatterError(context, lineNumber, "malformed line");
    }

    const key = line.slice(0, separator);
    const value = line.slice(separator + 1).trim();
    if (!/^[a-z][a-z0-9-]*$/.test(key) || !value) {
      frontmatterError(context, lineNumber, "malformed line");
    }
    if (Object.hasOwn(frontmatter, key)) {
      frontmatterError(context, lineNumber, "duplicate key");
    }

    frontmatter[key] = parseScalar(key, value, context, lineNumber);
  }

  return {
    frontmatter,
    body: lines.slice(closingDelimiter + 1).join("\n").trim(),
  };
}
