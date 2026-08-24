# Ceremony pre-flight

Depth for the pointer at the end of `start/SKILL.md` §3 and
`plan-release/SKILL.md` §3: the branch a ceremony runs, once its own
fail-fast gates have resolved a workspace root, to notice whether a
decision map already exists for this repo before its stations start
asking. It reads `references/tracker.md` §1 to resolve `$OWNER_REPO`, and
on the one-map branch reads `references/charting.md`'s `## Decisions so
far` heading. Nothing downstream reads this file's own output — the
ceremony that ran it is the last consumer, whichever branch fires.

---

## 1. Count the maps

A map is chartered with the label `wayfinder:map` (`references/charting.md`
§4). Counting them tells the ceremony whether this repo already has a
decision on record that bears on its own stations.

```bash
gh issue list -R "$OWNER_REPO" --label "wayfinder:map" --state all \
  --json number,title,state,url
```

`--state all` on purpose: a closed map's `Decisions so far` is still a
resolved decision worth reading back, and a map that later reopens must
not have silently dropped out of the count.

---

## 2. Branch on the count

| Count | Behaviour |
|---|---|
| 0 | Proceed exactly as today — the common case, and it costs nothing. |
| 1 | Read its `## Decisions so far` (`references/charting.md` §3) and carry each recorded decision into §3 below. |
| >1 | Name every map — by title, never by bare number — and ask the operator which one this ceremony is for. |

The zero branch is the load-bearing one: a repo with no map yet must not
pay a network round trip's latency, let alone a prompt, on every single
`/start` or `/plan-release` run. An empty `gh issue list` result **is**
the answer; nothing else in this file executes.

---

## 3. Pre-fills a station; never replaces one

**Binding.** A map's resolved decisions change *how* a station is asked,
never *whether* it is asked. `/start` still walks all nine
forced-enumeration categories (`start/references/bones-registry.md` §2)
end to end, and `plan-release` still walks every one of its own steps, in
full, on every run. A category the map already answered gets that answer
**read back for confirmation** in place of an open question — the operator
can still overrule it — but the station itself still runs, the same as a
category with no map at all. Letting pre-flight skip a station outright,
even a fully-answered one, would reintroduce through a new door the same
completion-floor defect #303 already tracks: a ceremony reporting complete
without ever covering the categories it exists to cover.
