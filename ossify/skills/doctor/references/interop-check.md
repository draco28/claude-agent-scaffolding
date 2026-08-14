# Workspace interop check

The depth behind `doctor/SKILL.md` §7. Absorbed from `scaffold-onboard`'s
`checking-workspace-interoperability` (spec §8.1), so the unified plugin owns
the question and `workspace-init` stays unchanged.

**Check only.** Spec §9.1 allocates `doctor` an *interop check*; the additive
repair half was scaffold-onboard's own extension and is not shipped here. This
surface reports and names the fix. It does not edit the manifest and does not
touch `AGENTS.md`.

**You perform this check by reading. There is no dispatcher verb for it** — the
`interop_check` subcommand was removed. It was 175 lines of bash that opened
files and described what it found, which is work a model does directly and
better. What remains deterministic is *path resolution* (`oss repo_root`,
`oss state_path`), because every mutating verb routes through it and two
spellings of one path is a real defect class. Deciding whether what you read is
healthy is yours.

---

## 1. The question

*Can this workspace be driven by Claude Code and by Codex, interchangeably,
mid-project, without either one silently working from different assumptions?*

Everything below is a way that question comes out **no**.

### Output grammar — match it exactly

One line per check, `ok:` or `fail:`, then the check name, then a dash and the
detail. Same grammar as `oss doctor`, because a single read-out should not carry
two vocabularies:

```
ok: manifest - /path/to/.workspace/pairing.json
fail: agents_md - no AGENTS.md at /path/AGENTS.md; a Codex session gets no project instructions at all
```

Check names, in this order: `manifest`, `canonical`, `ai_workspace`,
`state_path`, `agents_md`. **If any line is `fail:`, say so explicitly at the
end** — there is no exit code to carry it now, so the summary is what the reader
acts on. Report every failing line, not just the first, except where §3 says to
stop.

---

## 2. What was absorbed: the question, not the checklist

The scaffold-onboard original requires ten `.routing.*` keys including
`roadmap`, `sprint_specs` and `implementation_handoffs`, plus a
`.workspace/locks` directory.

**Every one of those is an artifact this stack retired.** `ROADMAP.md` is
replaced by the feature map plus `RELEASE.md`; sprint specs by spine specs;
`PROJECT_PLAN.md` outright. ossify's lock is a `<state>.lock` directory beside
the state file, not a workspace-wide one.

Porting that key set would make `doctor` report a correctly-configured ossify
project as broken for not having the previous stack's furniture — a check whose
failures are all false is worse than no check, because someone will eventually
"fix" a healthy project to satisfy it.

**If you are ever tempted to add a key here, the test is: does an ossify
ceremony read it?** If nothing reads it, its absence is not a finding.

---

## 3. The checks

### `manifest`

Walk up from `$PWD` for `.workspace/pairing.json` and read it. That walk is a
few directory checks; do it yourself.

`oss manifest_require` is the *refusal*, not the finder — it returns rc 1 and
prints the project's canonical refusal text to **stderr**, and discards the path
on success. Use it when you want that exact wording; do not expect a path from
it. There is no dispatcher verb that echoes the manifest path.

**Absent → `fail:`, and STOP.** Do not run the remaining checks. Every one of
them reads this file, so continuing emits four derived failures for one root
cause and buries the only thing that has to be fixed first. Remedy:
`/init-workspace` (new workspace) or `/pair-workspace` (existing canonical
repo) — name those tokens literally, do not paraphrase them.

**Present but unreadable → `fail:`, and STOP**, for the same reason. Read the
file and satisfy yourself it is **exactly one JSON object**. Three ways it is
not, all of which used to reach the later checks and produce nonsense:

- Malformed JSON.
- A valid non-object: `[]`, `null`, `42`, `"a string"`. Each parses, then every
  key read comes back empty.
- **Two or more concatenated top-level values** — `{...}{...}`. This is the one
  worth reading for deliberately. A tool checking only "does the last value
  parse as an object" accepts it, and every key read then returns *both* values'
  answers joined by a newline, so roots and paths come out as two-line strings
  and every later line is nonsense about a path nobody configured. Count the
  top-level values. (#169)

### `canonical` and `ai_workspace`

Both roots must resolve, and both must be real directories.

```bash
oss repo_root canonical
oss repo_root ai_workspace
```

Use the verb, not the raw JSON value. It substitutes `${...}` tokens and refuses
a path that only *looks* absolute — reading the raw value would pass a manifest
that every real call then fails on. Its refusals are already worded for you,
including the `${PLUGIN_DATA:...}` case, which is legal workspace-init
vocabulary that ossify does not resolve: report that refusal as written rather
than calling it malformed. (#165)

Distinguish the two failures — they have different causes and different fixes:

| Condition | Line | Means |
|---|---|---|
| the verb refuses | `fail: <key> - .<key>.root is absent, holds an unresolved ${...} token, or is not absolute` | the manifest is wrong |
| resolves, not a directory | `fail: <key> - resolved root is not a directory: <path>` | the manifest is right and the directory moved |

The second is the one that happens to real projects, usually after a repo is
renamed or moved.

**`canonical` must also be a git repository.** Probe it:

```bash
git -C "$(oss repo_root canonical)" rev-parse --git-dir
```

A canonical root that is an ordinary directory — `.git` removed, or the manifest
hand-edited — passes a directory check and then fails the first ceremony that
touches it: `oss_worktree_add` runs `git -C "$root" worktree add` immediately,
and spine close runs merges and reachability checks against the same root. Line:
`fail: canonical - resolved root is not a git repository: <path>`. (#153)

**Do not apply the git probe to `ai_workspace`.** That workspace is legitimately
allowed to be untracked, so the same probe there is a false failure. This is the
one place the two roots are deliberately *not* treated alike — a check that
loops over both keys uniformly is wrong.

### `state_path`

The state file's path must resolve, and the session must not be quietly driving
a different project's state.

```bash
oss state_path          # the manifest's answer, ignores the environment
echo "${OSS_STATE_FILE:-<unset>}"
```

**Resolution first.** If `oss state_path` fails, that is
`fail: state_path - the state path does not resolve to an absolute location (an
unresolved ${...} token, a relative routed value, or no ai_workspace.root)`.

**Routing is not required.** `.well_known_paths.project_state` is honoured when
present; when absent the path derives as
`<ai_workspace.root>/.ossify/project-state.json`. **Both forms are
manifest-absolute**, so both resolve identically from any directory. An unrouted
manifest is therefore **not** an interop risk and must not be reported as one.

**Then the override.** `$OSS_STATE_FILE` takes precedence over the manifest for
every ceremony in this session, so a check that reads only the manifest path
certifies the workspace switch-ready while this session reads and *mutates*
another project's state. That is the interop failure in its purest form.

Judge it in this order, and the order matters:

0. **Empty is not set.** If `$OSS_STATE_FILE` is exported but empty, there is no
   override. `_oss_resolve_state` guards on `[ -n "${OSS_STATE_FILE:-}" ]`, so an
   empty value falls through to the manifest exactly as an unset one does.
   Convicting it is a false failure on a healthy workspace — skip to
   `ok: state_path`.
1. **Relative override.** Set, non-empty, and does not begin with `/` → that is
   the finding, whether or not it points at the same file:
   `fail: state_path - the $OSS_STATE_FILE override is relative ('<value>'); it
   resolves against whichever directory each session starts in, so two sessions
   would drive two different files.` The manifest's own routed values are held
   to exactly this rule, and the override arm not being held to it was a real
   defect — a relative override whose target happened to exist under the cwd got
   promoted to an absolute path, compared equal, and printed `ok:` for precisely
   the cwd-dependent configuration this check exists to reject.
2. **Trailing `/` or `/.`** → fail; see the separator table below.
3. **A different PATHNAME from `oss state_path`**, after collapsing `//` and an
   *interior* `/./` and nothing else: `fail: state_path - $OSS_STATE_FILE
   overrides the manifest (<env>, not <routed>); this session's ceremonies would
   read another project's state`.
4. Otherwise `ok: state_path - <routed>`.

> **Compare PATHNAMES. Never `-ef`, and never any other inode test.** The state
> file is a **write target**: mutations commit with `mv "$tmp" "$sf"`
> (`lib/state.sh`), and `mv` replaces the *directory entry* rather than following
> or preserving the link. So an override that is the same inode right now forks
> into a second history on the very first write, while the routed path keeps its
> old contents. Measured, for both alias kinds:
>
> | Alias | `-L` | `-ef` | after one `mv` |
> |---|---|---|---|
> | symlink to routed | true | true | detached — routed file unchanged |
> | **hard link** to routed | **false** | **true** | **forked — two live histories** |
>
> A rule built on `-ef` says `ok:` to both. A rule built on `-L` catches only the
> first. **Pathname comparison rejects both without a special case**, which is why
> it is the rule here rather than a caveat attached to one. (PR #178 shipped an
> `-ef` guard and it was a P1; PR #182 round 1 then found the hard-link half that
> the symlink-only patch still missed. Fix the class, not the instance.)

**Two spellings can still be one file.** `$ws/./.ossify/project-state.json` and
`$ws/.ossify/project-state.json` name the same file, and reporting an override
there is a false alarm on a healthy workspace — that was a real bug (#150).
Collapsing `//` and an interior `/./` handles it, and needs no filesystem at all,
so it works identically whether or not the state file exists yet.

**Do not collapse a TRAILING `/` or `/.`, and do not collapse `..`.** Both change
which file the path names, and both were live defects:

| Spelling | `[ -f ]` | `jq` reads it |
|---|---|---|
| `s.json` | yes | ok |
| `s.json/` | **no** | **fails ENOTDIR** |
| `s.json/.` | **no** | **fails ENOTDIR** |

A trailing separator asserts a *directory* and POSIX enforces it, so collapsing
`<routed>/.` to `<routed>` reports `ok: state_path` for a path every state read
then fails on — certifying a workspace as switch-ready while the session cannot
read its state at all. That is exactly the defect PR #166 round 1 fixed in the
deleted bash. `..` is not collapsible either: `a/b/..` is not `a` when `b` is a
symlink.

**Echo the raw spellings in the message.** The operator typed that string;
showing them a normalized form they never typed makes the remedy harder to act
on.

**When the override is an alias, say which kind.** A symlink or hard link to the
routed path fails step 3 on its pathname, which is correct — but the remedy is
"remove the link and let the manifest route it", not "you are pointed at another
project". Name it: `fail: state_path - $OSS_STATE_FILE ('<env>') is an alias of
the manifest-routed <routed>; the first write replaces its directory entry and
the two paths fork into separate histories. Unset it rather than linking.`

### `agents_md`

The check that is actually about Codex.

`AGENTS.md` in the AI workspace must exist **and name ossify**. It is the only
file Codex reads for project instructions: a workspace whose `AGENTS.md` never
mentions ossify has a Codex session driving the project with none of its
ceremonies — no spine planning, no close gates, no demo ledger — while the state
file goes on recording a lifecycle nobody is following.

Read `<ai_workspace.root>/AGENTS.md` and look for `ossify`, case-insensitively,
anywhere in the file — a `## Ossify` heading satisfies it.

| Line | Remedy |
|---|---|
| `fail: agents_md - no AGENTS.md at <path>; a Codex session gets no project instructions at all` | author one; it is the Codex-side entry point |
| `fail: agents_md - <path> never mentions ossify; a Codex session would drive this project with none of its ceremonies` | add a section routing Codex to the ossify ceremonies |

If the `ai_workspace` root did not resolve, you cannot look for the file: report
`fail: agents_md - cannot look for AGENTS.md without a resolvable ai_workspace
root` and stop there.

**Do not write or edit `AGENTS.md` yourself.** It holds user-authored content,
and this surface has no managed-section contract to merge into — that machinery
belongs to the repair half that is deliberately not shipped here. Report the
line, name the fix, stop.

---

## 4. What this check cannot tell you

Stated so a green result is not over-read:

- **Whether a Codex session will actually behave.** The check is a handful of
  presence-and-resolution facts. `AGENTS.md` mentioning ossify is not the same
  as `AGENTS.md` describing it correctly.
- **Whether the two agents agree on anything else** — model config, tool
  availability, or which branch is checked out.
- **Anything about `.codex` memory.** There is no Codex memory mirror and there
  should not be one: the shared source of truth is the pairing manifest, the
  lean spec, the memory bank and `project-state.json`. If you find a `.codex`
  memory tree, that is drift worth reporting in the read-out, not a thing to
  create.
