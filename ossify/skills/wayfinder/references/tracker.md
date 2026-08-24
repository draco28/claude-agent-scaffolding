# Tracker resolution

Depth for `SKILL.md` §1's routing pointer, and the file every other wayfinder
reference cites by section number: §1 the ladder that decides which tracker a
map lives on, and §2 the query both chart and work modes run against it.

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
   `.workspace/pairing.json`, by walking up from `$PWD` — **and that workspace
   repo has an `origin` remote** → the tracker is that remote. Maps are process
   records, so they go to the workspace and never to a canonical; no manifest
   key records this.
2. Branch 1 declined, `.wayfinder.json` present → use it.
3. Branch 1 declined, no `.wayfinder.json` → ask once, then write it.
4. Chosen tracker unreachable → **stop**, naming which probe failed and
   what would restore it.

**Branch 1 needs the remote, not just the workspace.** A discoverable
workspace with no `origin` declines to branch 2 — `workspace-init` writes
`git_remote: null` by default, and its own default-case test asserts exactly
that (`workspace-init/tests/test-manifest.sh:372`), so a freshly initialised
workspace has no remote as its **normal** state rather than as a failure.
Branching on discoverability alone would hand the reachability guard below an
empty `$OWNER_REPO` and stop wayfinder outright on every new workspace, while
reporting a resolution bug — which is why branches 2 and 3 key off "branch 1
declined" and not off "no manifest".

`.wayfinder.json` sits at the repo root and carries one key, in one of two
forms:

```json
{"tracker": "github:owner/repo"}
```

`github:owner/repo` is the only form 1.2.0 accepts. Branch 3 writes
**exactly this key name** — a session that invents
its own leaves a dotfile the next session cannot read, which orphans every
map on it just as surely as the silent tracker switch branch 0 exists to
prevent.

**Whichever branch fires, it ends by binding `$OWNER_REPO`, `$OWNER` and
`$REPO`.** Those three names are what every other wayfinder file consumes and
none of them assigns — this is their only definition site. Branch 1 derives
them from the workspace remote below; branches 2 and 3 derive them from
`.wayfinder.json`'s `tracker` value, dropping its `github:` prefix. There is
no branch that leaves them unbound: **wayfinder requires a reachable issue
tracker**, and every path that cannot produce one stops.

Resolve the workspace root with the shipped resolver, then read its remote
**from git, never from the manifest**:

```bash
# `oss repo_root` walks up from $PWD and refuses by name when unpaired: a
# non-zero rc here IS branch 2, not an error, so it is swallowed for the same
# reason the origin read below is. Under `set -e` a bare assignment would abort
# the session on the ordinary standalone repo before .wayfinder.json is read.
# It resolves the root under either manifest schema, so the topology branch
# needs no separate read.
AI_ROOT="$(oss repo_root ai_workspace 2>/dev/null || true)"

# Both branch-1 preconditions are now empty-or-set, so one test routes them:
# no workspace, or a workspace with no origin, is branch 2 either way. Written
# as an `if` rather than `[ ... ] && ...` on purpose - the AND-list form is
# safe under `set -e` but only by a rule about non-final list elements that a
# later reader is liable to "correct" the wrong way.
ORIGIN=""
if [ -n "$AI_ROOT" ]; then
  ORIGIN="$(git -C "$AI_ROOT" remote get-url origin 2>/dev/null || true)"
fi

OWNER_REPO="$(printf '%s' "$ORIGIN" \
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
[ -n "$OWNER_REPO" ] || { echo "wayfinder: tracker resolution failed - \$OWNER_REPO is empty after the ladder" >&2; exit 1; }
gh repo view "$OWNER_REPO" --json hasIssuesEnabled --jq '.hasIssuesEnabled'
```

A `false`, or a `gh` error from a probe that was actually constructed, is
branch 4: **stop**, and say which it was — an unreachable tracker and one that
simply has issues turned off need different things from the operator, and both
are recoverable outside this session.

**The two stops are different failures and say so.** Branch 4 means the probe
ran and answered no: auth, network, or issues disabled. The guard above means
the probe could not be built at all — it runs **after the ladder has
finished**, so it fires only when a branch that claimed to bind `$OWNER_REPO`
did not, which is a bug in the resolution rather than a fact about the
tracker. Without the guard the probe runs as `gh repo view ""`, errors, and
reports itself as branch 4 — a resolution bug wearing an unreachable-tracker
message.

An empty `$ORIGIN` is neither: branch 1 declined, so the ladder went on to
branch 2 or 3 and bound `$OWNER_REPO` from `.wayfinder.json`. The guard is
never handed the no-origin workspace.

**Why there is no local fallback.** An earlier draft of this file routed both
stops to a Markdown-backed map on disk. It was cut before release: nothing
exercised it, and every review round found another tracker operation the file
mapping did not cover — clearing a resolved blocker out of a dependent's
metadata, closing a map that has no state field, and a transient probe failure
silently splitting one effort across two backends once connectivity returned.
A map is a **shared, mutable, queryable** record with parent/child and
blocking edges, which is what an issue tracker is for. Requiring one is the
honest boundary; a half-built second backend is not a fallback, it is a second
place for maps to be lost.

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
          assignees(first:100){nodes{login}}
          labels(first:100){nodes{name}}
          blockedBy(first:100){nodes{number state}}
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

**Every nested connection asks for 100, the GraphQL maximum, and none of the
three may be trimmed to "enough".** Each one feeds the eligibility boolean, so
a truncated page does not lose information — it *inverts* the answer. Miss an
open blocker past the cut and the ticket is admitted to the frontier and worked
before its evidence exists; miss the `wayfinder:` label past the cut on a repo
with ten of its own and a correctly typed ticket reports `no-type` and loses
its resolver. A wayfinder map will not approach 100 of any of them; asking for
the maximum costs one page either way and removes the question.

The `--jq` filter is doing the derivation the REST form would need N calls to
assemble: three raw facts per ticket — `state`, `assignees`, `blockedBy` —
collapse into one boolean, frontier-eligible or not.

**The filter is a view, not the query.** `subIssues.nodes` holds *every* sub-issue
of the map with all three facts on it; the `--jq` above narrows that to the
eligible set and formats it for a human to pick from. Three callers need the
**unfiltered** nodes instead, and each reads them from this same single call
rather than issuing another:

- a **named ticket** — its node is read directly and the predicate applied to
  it, and its presence in the list is the parent check
  (`references/working.md` §1);
- the **claim re-read** — that node's `assignees`, immediately before
  assigning (`references/working.md` §1);
- the **terminal check** — an empty eligible set is ambiguous on its own, so
  §5's two cases are told apart by the unfiltered nodes: all closed, or some
  open but blocked or claimed (`references/working.md` §5).

That last one is why the distinction is stated here rather than left implicit.
A caller that saw only the filtered output would read an empty result as "no
work left" in both cases and could close a map with open tickets still on it.
