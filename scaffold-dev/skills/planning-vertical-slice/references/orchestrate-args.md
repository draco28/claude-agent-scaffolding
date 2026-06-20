# `/orchestrate VS-N.M.K` argument parsing (§13)

Referenced by `planning-vertical-slice` §13. The `/orchestrate` slash command (`commands/orchestrate.md`) exports the raw slash-argument string as `$SCAFFOLD_DEV_ARGS` (per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. at template-render time and silently corrupts bash positionals).

**Parse `$SCAFFOLD_DEV_ARGS` in bash; never reference `$1` / `$2`.** Extract the VS-id (the full 3-part `VS-<phase>.<sprint>.<slice>`) and the optional per-invocation `--backend` / `--gate` overrides:

```bash
vs_id=""
backend_override=""
gate_override=""
read -r -a scaffold_dev_argv <<<"${SCAFFOLD_DEV_ARGS:-}"
i=0
while [[ "$i" -lt "${#scaffold_dev_argv[@]}" ]]; do
  arg="${scaffold_dev_argv[$i]}"
  case "$arg" in
    --backend)
      next_i=$((i + 1))
      if [[ "$next_i" -ge "${#scaffold_dev_argv[@]}" || "${scaffold_dev_argv[$next_i]}" == --* ]]; then
        echo "orchestrate: missing value for --backend" >&2
        exit 2
      fi
      backend_override="${scaffold_dev_argv[$next_i]}"
      i=$((i + 2))
      ;;
    --gate)
      next_i=$((i + 1))
      if [[ "$next_i" -ge "${#scaffold_dev_argv[@]}" || "${scaffold_dev_argv[$next_i]}" == --* ]]; then
        echo "orchestrate: missing value for --gate" >&2
        exit 2
      fi
      gate_override="${scaffold_dev_argv[$next_i]}"
      i=$((i + 2))
      ;;
    VS-*)
      vs_id="$arg"
      i=$((i + 1))
      ;;
    *)
      echo "orchestrate: unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done
```

Carry `backend_override` through §8.3 as `sd backend_resolve --backend "$backend_override"` when set, and `gate_override` through §7.0 as `sd review_gate_resolve --gate "$gate_override"` when set (a one-off review gate, e.g. `/orchestrate VS-1.1.1 --gate spec_close`, overriding the manifest `.review_gate`). Then proceed to §3 pre-flight.

Unknown or missing VS-id → one-line error + stop:

> /orchestrate requires a VS-id argument. Example: /orchestrate VS-1.1.1
