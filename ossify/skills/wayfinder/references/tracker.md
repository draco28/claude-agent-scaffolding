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

Resolve the workspace root, then read its remote **from git, never from the
manifest**:

```bash
# root: implicit under topology.json (the .ossify parent), explicit under pairing.json
AI_ROOT="$(jq -r '.ai_workspace.root' .workspace/pairing.json)"   # pairing branch
# AI_ROOT="$(dirname "$(dirname "$TOPOLOGY_FILE")")"              # topology branch

git -C "$AI_ROOT" remote get-url origin \
  | sed -E 's#^https://github\.com/##; s#\.git$##'
```

**Why this reads git, and not a manifest field that plainly exists.** A
concurrent design
(`docs/superpowers/specs/2026-08-24-ossify-multi-canonical-design.md`, landing
after wayfinder) replaces `pairing.json` with `.ossify/topology.json`, where
the workspace root is implicit — its §1 states plainly that *"there is no
`ai_workspace` key to drift"* — and its §9 lists `routing` among the keys
ossify **never reads**. An `ai_workspace.git_remote` field and a
`routing.wayfinder_maps` key would both be dependencies on manifest surfaces
already scheduled for deletion. The workspace root is stable under both
schemas, and `git remote get-url` returns the identical string under either
one (verified 2026-08-24) — so branch 1 asks git directly, and a future
reader who "fixes" this back to a manifest read is reintroducing the
dependency this design deliberately avoided.

Check reachability before committing to a tracker — auth lapses and issues
can be disabled per repo:

```bash
gh repo view "$OWNER_REPO" --json hasIssuesEnabled --jq '.hasIssuesEnabled'
```

A `false`, or a `gh` error, is branch 4: fall through to §3 and say which
branch fired, so the operator can tell an unreachable tracker from one that
simply has issues turned off.

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
  | .[] | "\(.title)  [\(.labels.nodes[0].name)]  #\(.number)"'
```

`$MAP` is the map's issue number, resolved once — from the name or URL the
operator gave — and never asked for again. The bracket in each output line is
the ticket's type label: `wayfinder:research`, `wayfinder:smoke-test`,
`wayfinder:spike`, `wayfinder:prototype`, `wayfinder:grilling`, or
`wayfinder:task`, set when the ticket was filed; the map itself carries
`wayfinder:map`.

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
