---
description: Author a session handoff doc. Usage: /handoff [--scope <s>] [--purpose <p>] [--return-of <id>] [--ephemeral]
argument-hint: "[--scope <s>] [--purpose <p>] [--return-of <id>] [--ephemeral]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

# /handoff

Wraps the `handing-off-session` skill — authors a handoff document for the
current session. Bridge `$ARGUMENTS` into an env var the skill body reads
(per `feedback_slash_command_dollar_n_bug` — never `$1`/`$2`/`$N`). Parses
`--scope`, `--purpose`, `--return-of`, and `--ephemeral` flags out of
`$ARGUMENTS` for the skill body. `--ephemeral` (#38 leg 5) prints the handoff
to stdout instead of writing a durable file and needs no pairing manifest.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS

  # Flag extraction delegates to the shared, unit-tested helper
  # sd_handoff_parse_flags (lib/handoff.sh), invoked through the bin/sd
  # dispatcher on PATH. CRITICAL (#19): never use bare $1/$2 here — the
  # slash-command renderer freezes them at template-render time, which silently
  # emptied --scope/--purpose/--return-of. The helper parses by regex and emits
  # FIVE ordered lines: scope, purpose, return_of, return_id, ephemeral (#38).
  { IFS= read -r _scope
    IFS= read -r _purpose
    IFS= read -r _return_of
    IFS= read -r _return_id
    IFS= read -r _ephemeral
  } < <(sd handoff_parse_flags "$SCAFFOLD_DEV_ARGS")
  export SCAFFOLD_DEV_SCOPE="$_scope"
  export SCAFFOLD_DEV_PURPOSE="$_purpose"
  export SCAFFOLD_DEV_RETURN_OF="$_return_of"
  export SCAFFOLD_DEV_EPHEMERAL="$_ephemeral"

  echo "handoff: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
  echo "handoff: SCOPE=${SCAFFOLD_DEV_SCOPE:-<unset>}"
  echo "handoff: PURPOSE=${SCAFFOLD_DEV_PURPOSE:-<unset>}"
  echo "handoff: RETURN_OF=${SCAFFOLD_DEV_RETURN_OF:-<unset>}"
  echo "handoff: EPHEMERAL=${SCAFFOLD_DEV_EPHEMERAL:-<unset>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:handing-off-session)`** — pass the parsed `--scope`,
`--purpose`, `--return-of`, and `--ephemeral` flags. The skill body owns
handoff-doc authoring (filename convention, frontmatter, scope/purpose/return-of
sections, References + Suggested-skills sections, next-session-focus field,
redaction pass, work-item references) per scaffold-dev SPEC §6b. Under
`--ephemeral` it renders to stdout instead of writing a file.
