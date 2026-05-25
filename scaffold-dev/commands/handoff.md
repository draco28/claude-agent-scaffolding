---
description: Author a session handoff doc. Usage: /handoff [--scope <s>] [--purpose <p>] [--return-of <id>]
argument-hint: "[--scope <s>] [--purpose <p>] [--return-of <id>]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

# /handoff

Wraps the `handing-off-session` skill — authors a handoff document for the
current session. Bridge `$ARGUMENTS` into an env var the skill body reads
(per `feedback_slash_command_dollar_n_bug` — never `$1`/`$2`/`$N`). Parses
`--scope`, `--purpose`, and `--return-of` flags out of `$ARGUMENTS` for the
skill body.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS

  # Flag extraction (single-pass, order-independent). Each flag value is the
  # token immediately following its name; --flag=value form also supported.
  _scope=""; _purpose=""; _return_of=""
  set -- $SCAFFOLD_DEV_ARGS
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope)           _scope="${2:-}";     shift 2 ;;
      --scope=*)         _scope="${1#--scope=}";       shift ;;
      --purpose)         _purpose="${2:-}";   shift 2 ;;
      --purpose=*)       _purpose="${1#--purpose=}";   shift ;;
      --return-of)       _return_of="${2:-}"; shift 2 ;;
      --return-of=*)     _return_of="${1#--return-of=}"; shift ;;
      *)                 shift ;;
    esac
  done
  export SCAFFOLD_DEV_SCOPE="$_scope"
  export SCAFFOLD_DEV_PURPOSE="$_purpose"
  export SCAFFOLD_DEV_RETURN_OF="$_return_of"

  echo "handoff: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
  echo "handoff: SCOPE=${SCAFFOLD_DEV_SCOPE:-<unset>}"
  echo "handoff: PURPOSE=${SCAFFOLD_DEV_PURPOSE:-<unset>}"
  echo "handoff: RETURN_OF=${SCAFFOLD_DEV_RETURN_OF:-<unset>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:handing-off-session)`** — pass the parsed `--scope`,
`--purpose`, and `--return-of` flags. The skill body owns handoff-doc
authoring (filename convention, frontmatter, scope/purpose/return-of
sections, work-item references, stage-status table) per scaffold-dev SPEC §8.
