# Tracker resolution

Depth for `SKILL.md` §1's routing pointer, and the file every other wayfinder
reference cites by section number: §1 the ladder that decides which tracker a
map lives on, §2 the query both chart and work modes run against it, §3 the
fallback for when no tracker is reachable at all.

A **map** is the parent ticket for one decision — the question wayfinder
exists to resolve. Its **tickets** are the map's sub-issues: the research,
smoke tests, spikes, prototypes, grilling sessions, and plain tasks the
decision needs before it can close.

---

## 1. Which tracker

**Branch 0 runs first.** If `.workspace/pairing.json` and `.wayfinder.json`
both exist and name different trackers, **stop and ask**. Never resolve it
silently: a repo that adopted ossify after using wayfinder would otherwise
switch trackers and orphan every existing map.

1. The AI workspace is discoverable — `.ossify/topology.json` or
   `.workspace/pairing.json`, by walking up from `$PWD` → the tracker is that
   workspace repo's **own git remote**. Maps are process records, so they go
   to the workspace and never to a canonical; no manifest key records this.
2. No manifest, `.wayfinder.json` present → use it.
3. Neither → ask once, then write `.wayfinder.json`.
4. Chosen tracker unreachable → fall back to §3 and name the branch that
   fired.

**Whichever branch fires, it ends by binding `$OWNER_REPO`, `$OWNER` and
`$REPO`.** Those three names are what every other wayfinder file consumes and
none of them assigns — this is their only definition site. Branch 1 derives
them from the workspace remote below; branches 2 and 3 derive them from
`.wayfinder.json`'s `tracker` value, dropping its `github:` prefix. A `local`
tracker binds none of the three and goes straight to §3.

Resolve the workspace root with the shipped resolver, then read its remote
**from git, never from the manifest**:

```bash
# `oss repo_root` walks up from $PWD and refuses by name when unpaired: a
# non-zero rc here IS branch 2, not an error. It resolves the root under
# either manifest schema, so the topology branch needs no separate read.
AI_ROOT="$(oss repo_root ai_workspace)"

OWNER_REPO="$(git -C "$AI_ROOT" remote get-url origin \
  | sed -E 's#^git@github\.com:#https://github.com/#; s#^https://github\.com/##; s#\.git$##')"
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"
```

**Why this reads git, and not a manifest field that plainly exists.** A
concurrent internal design, landing after wayfinder, makes the workspace root
implicit and removes the key that would otherwise carry it — routing fields,
including a tracker pointer, are on that design's list of keys ossify's own
resolvers never read. An `ai_workspace.git_remote` field and a
`routing.wayfinder_maps` key would both be dependencies on manifest surfaces
already scheduled for deletion. The workspace root is stable across both the
current and the incoming schema, and `git remote get-url` returns the
identical string under either one — so branch 1 asks git directly, and a
future reader who "fixes" this back to a manifest read is reintroducing the
dependency this design deliberately avoided.

**Why the resolver and not a hand-rolled `jq` read of the manifest.**
`oss repo_root ai_workspace` is the walk-up branch 1 describes — a raw
`jq -r '.ai_workspace.root' .workspace/pairing.json` only ever finds a
manifest sitting in `$PWD`, so branch 1 misses on a correctly paired repo
invoked from any subdirectory. The resolver also substitutes the manifest's
`${…}` tokens and refuses with a named message, which is why this repo
removed `oss_cmd_manifest_get` in v0.2.0 (`lib/commands.sh:117-126`): the raw
read handed the caller a literal unresolved token string. It is a read that
already ships, so using it adds no verb.

Check reachability before committing to a tracker — auth lapses and issues
can be disabled per repo:

```bash
[ -n "$OWNER_REPO" ] || { echo "wayfinder: tracker resolution failed - \$OWNER_REPO is empty; this is not branch 4" >&2; exit 1; }
gh repo view "$OWNER_REPO" --json hasIssuesEnabled --jq '.hasIssuesEnabled'
```

A `false`, or a `gh` error from a probe that was actually constructed, is
branch 4: fall through to §3 and say which branch fired, so the operator can
tell an unreachable tracker from one that simply has issues turned off.

**An unresolved tracker is a stop, never branch 4.** The guard above fires
when `$OWNER_REPO` was never bound at all — a resolution step failed upstream
of the probe — and that is a bug to report, not a fallback to take. Without
it the probe runs as `gh repo view ""`, errors, and the error is
indistinguishable from a legitimate branch 4: every map on a perfectly
reachable tracker would go to local markdown, with a documented branch fired
and nothing red anywhere. Branch 4 means the probe ran and said no. It never
means the probe could not be built.

---

## 2. The frontier query

A map's frontier is the tickets ready to work right now: open, unassigned,
and not waiting on another open ticket. The obvious per-ticket form — one
REST call per sub-issue to read its assignees and what blocks it — is N+1: a
15-ticket map costs 15 round trips before a session can say what's next.
This query costs one, and is written **once**, here, never re-inlined
elsewhere:

```bash
gh api graphql -f query='
query($owner:String!,$repo:String!,$number:Int!){
  repository(owner:$owner,name:$repo){
    issue(number:$number){
      title url
      subIssues(first:100){
        nodes{
          number title url state
          assignees(first:5){nodes{login}}
          labels(first:10){nodes{name}}
          blockedBy(first:20){nodes{number state}}
        }
      }
    }
  }
}' -F owner="$OWNER" -F repo="$REPO" -F number="$MAP" --jq '
  .data.repository.issue.subIssues.nodes
  | map(select(.state=="OPEN"
        and (.assignees.nodes|length)==0
        and ([.blockedBy.nodes[]|select(.state=="OPEN")]|length)==0))
  | .[] | "\(.title)  [\([.labels.nodes[].name | select(startswith("wayfinder:"))] | .[0] // "no-type")]  #\(.number)"'
```

`$MAP` is the map's issue number, resolved once — from the name or URL the
operator gave — and never asked for again. The bracket in each output line is
the ticket's type label: `wayfinder:research`, `wayfinder:smoke-test`,
`wayfinder:spike`, `wayfinder:prototype`, `wayfinder:grilling`, or
`wayfinder:task`, set when the ticket was filed; the map itself carries
`wayfinder:map`. The filter picks that label out by prefix rather than by
position — a ticket also carrying an unrelated label (`priority:high`, say)
still reports its real type, and a ticket carrying none reports `no-type`
rather than guessing.

The `--jq` filter is doing the derivation the REST form would need N calls to
assemble: three raw facts per ticket — `state`, `assignees`, `blockedBy` —
collapse into one boolean, frontier-eligible or not. §3's front-matter keeps
the same three facts so the local fallback computes the identical boolean
without a network call.

---

## 3. Local-markdown fallback

When no tracker is reachable (branch 4), or the operator chose none, a map
lives as Markdown instead of an issue: `docs/wayfinder/<map-slug>/MAP.md`,
with its tickets as `NN-<slug>.md` files beside it — `NN` a stable two-digit
order so a directory listing sorts the way the frontier would, `<slug>` the
ticket's own short name. A ticket is referred to by that name, the same rule
as on the tracker — never by the bare `NN`.

Each ticket file's front-matter carries four fields: `state` (`open` or
`closed`), `type` (the ticket's `wayfinder:<type>` label, without the
prefix), `assignee` (a name, or empty), and `blocked_by` (the slugs of
tickets still open that block it, or empty). Frontier eligibility computes
exactly as §2's query derives it — `state` open, `assignee` empty,
`blocked_by` empty — the same three-fact boolean, read from disk instead of
queried over the network.
