#!/usr/bin/env bash
# Cumulative auto-demo runner (spec §6.1 core row). Halt-on-first-fail.

# §6.1 + companion §4.3: the demo runs against the real product build — the
# composition root when one is declared, the sole declared repo's root
# otherwise (#272/#310 Task 4: routed through the sole-repo default rule, not
# a literal `canonical` - N>1 declared repos refuses rather than guessing).
# Resolved ONCE, BEFORE any cd, because oss_manifest_discover walks up from
# $PWD and every manifest/state read after a cd would otherwise resolve
# somewhere else. Precedence is EXPLICIT > composition_root > sole-declared-repo
# root — the same explicit-beats-derived shape as _oss_resolve_state. The
# explicit leg is not a convenience: without it this function would require a
# pairing manifest, and
# every existing demo test (test-demo-runner.sh, test-integration.sh) runs
# against a bare temp state with no manifest on the walk-up path. A
# manifest-only resolver would break them all, and "fall back to $PWD when there
# is no manifest" would silently reinstate the very bug this task fixes.
oss_demo_workdir() { # $1=state-file [$2=explicit-workdir]
  local sf="$1" explicit="${2:-}" root comp dk
  [ -n "$explicit" ] && { printf '%s\n' "$explicit"; return 0; }
  comp="$(jq -r '.project.composition_root // empty' "$sf" 2>/dev/null)" || comp=""
  dk="$(_oss_default_repo_key)" || return $?
  root="$(_oss_repo_root "$dk")" || return $?
  if [ -n "$comp" ]; then
    case "$comp" in /*) printf '%s\n' "$comp" ;; *) printf '%s\n' "$root/$comp" ;; esac
  else
    printf '%s\n' "$root"
  fi
}

oss_demo_run_auto() { # $1=state-file [$2=explicit-workdir]
  local sf="$1" wd n i line id text cmd expected want out rc passed=0
  wd="$(oss_demo_workdir "$sf" "${2:-}")" || return 1
  [ -d "$wd" ] || { echo "oss: demo working dir does not exist: $wd" >&2; return 1; }
  n="$(jq '[.demo_ledger[] | select(.type=="auto" and (.status=="active" or .status=="quarantined"))] | length' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read state $sf" >&2; return 1; }
  i=0
  while [ "$i" -lt "$n" ]; do
    line="$(jq -c "[.demo_ledger[] | select(.type==\"auto\" and (.status==\"active\" or .status==\"quarantined\"))][$i]" "$sf")"
    id="$(printf '%s' "$line" | jq -r '.id')"
    text="$(printf '%s' "$line" | jq -r '.text')"
    if [ "$(printf '%s' "$line" | jq -r '.status')" = "quarantined" ]; then
      echo "SKIP $id (quarantined) - $text"
      i=$((i+1)); continue
    fi
    cmd="$(printf '%s' "$line" | jq -r '.command')"
    expected="$(printf '%s' "$line" | jq -r '.expected')"
    # Subshell cd: the process cwd is never mutated, so the NEXT iteration's
    # jq reads and any later manifest resolution still see the original $PWD.
    # `if out="$(...)"; then rc=0; else rc=$?; fi` — NOT `set +e; ...; set -e`.
    # `set`'s options are process-global, not function-scoped, so the toggle
    # this function used to do reaches past its own return and mutates
    # errexit for every caller up the stack (exactly what lib/verify.sh's
    # sibling comment calls out as the fragile idiom it replaced with this
    # same `if`-capture form). Standardized here to match.
    if out="$( cd "$wd" && bash -c "$cmd" 2>&1 )"; then rc=0; else rc=$?; fi
    # Every arm FAILS CLOSED. The ledger is append-only: a line written by an
    # older, looser validator is re-run forever, so the runner cannot assume its
    # `expected` was ever validated. A `case` with no default arm silently
    # counted an unrecognized expected as a PASS, and a non-numeric `exit:`
    # operand made `[ ... -ne ... ]` exit 2 — which the `if` reads as false, so
    # the FAIL branch never ran. Both now fail the line.
    case "$expected" in
      exit:*)
        want="${expected#exit:}"
        case "$want" in ''|*[!0-9]*)
          echo "FAIL $id - $text (malformed expected '$expected': 'exit:' takes digits only)"; return 1;; esac
        if [ "$rc" -ne "$want" ]; then
          echo "FAIL $id - $text (rc=$rc, wanted $want)"; printf '%s\n' "$out" | tail -5; return 1
        fi
        # Vacuous-green is checked ONLY for a success expectation. The previous
        # unscoped placement ran after every arm, so a line legitimately
        # expecting exit:1 from a recognized runner was failed as vacuous.
        if [ "$want" = "0" ] && printf '%s' "$out" | oss_verify_zero_tests_guard "$cmd"; then
          echo "FAIL $id - $text (vacuous-green: recognized runner executed zero tests)"; return 1
        fi ;;
      contains:?*)
        case "$out" in *"${expected#contains:}"*) ;; *)
          echo "FAIL $id - $text (output missing '${expected#contains:}')"; printf '%s\n' "$out" | tail -5; return 1;; esac ;;
      *)
        echo "FAIL $id - $text (unrecognized expected '$expected'; the grammar is exit:<n> | contains:<str>)"; return 1 ;;
    esac
    passed=$((passed+1)); i=$((i+1))
  done
  echo "PASS $passed lines"
}

# §6.1 spine close walks the CLOSING SPINE'S OWN user lines; §6.2 release close
# walks EVERY accumulated one. One verb, scoped by an optional spine argument.
oss_demo_user_lines() { # $1=state-file [$2=spine]
  if [ -n "${2:-}" ]; then
    jq --arg s "$2" '[.demo_ledger[] | select(.type=="user" and .status=="active" and .source_spine==$s)]' "$1"
  else
    jq '[.demo_ledger[] | select(.type=="user" and .status=="active")]' "$1"
  fi
}

oss_demo_record_close() { # $1=state $2=scope $3=id $4=passed(true|false) $5=line-count $6=notes
  case "$2" in work_item|spine|release) ;; *)
    echo "oss: close scope must be work_item|spine|release" >&2; return 2;; esac
  case "$4" in true|false) ;; *) echo "oss: passed must be true|false" >&2; return 2;; esac
  oss_state_mutate "$1" add_close_record \
    "$(jq -n --arg sc "$2" --arg id "$3" --argjson ok "$4" --argjson n "${5:-0}" \
        --arg notes "${6:-}" --arg ts "$(_oss_now)" \
      '{scope:$sc,id:$id,demo_passed:$ok,demo_lines:$n,notes:$notes,at:$ts}')"
}
