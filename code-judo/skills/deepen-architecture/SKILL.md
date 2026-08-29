---
name: deepen-architecture
description: Scan a codebase for deepening opportunities — shallow modules that should become deep ones — present them as a visual HTML report opened in the browser, then grill through whichever candidate the user picks. Human-invoked only. Use for an architecture review of a codebase, "where is this codebase shallow", "find refactors worth doing", "improve the architecture here", or a proactive deepening scan.
disable-model-invocation: true
---

# Deepen architecture

Surface architectural friction and propose **deepening opportunities**: refactors that turn
shallow modules into deep ones. What you are buying is testability and navigability — for
humans and for agents.

This skill is *informed* by the project's domain model and built on a shared design
vocabulary:

- Call the Skill tool with `code-judo:codebase-design` for the architecture vocabulary —
  **module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality** —
  and its principles: the deletion test, "the interface is the test surface", "one adapter is
  a hypothetical seam, two is a real one". Use those terms exactly in every suggestion. Do
  not drift into "component", "service", "API", or "boundary".
- The domain language in `CONTEXT.md` gives names to good seams. ADRs in `docs/adr/` record
  decisions this skill does not re-litigate.

## 1. Explore

**Scope before you scan: YAGNI.** Deepening a module pays off by making *future* changes to
it easier, so weight the parts of the codebase that have recently changed. Decide *where* to
look before you look:

- If the user named a direction — a module, a subsystem, a pain point — take it, and skip the
  inference below.
- Otherwise walk back a good stretch of commit history (`git log --oneline`) to find the
  codebase's hot spots: the files and areas that keep coming up. Let those paths pull your
  attention first. **If the changes are scattered with no clear hot spot, widen the net.**

Read the project's domain glossary (`CONTEXT.md`) and any ADRs covering the area you are
touching **first**, before forming opinions.

Then spawn a sub-agent to walk the codebase. Do not follow rigid heuristics — explore
organically and note where *you* experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow**, with an interface nearly as complex as the implementation?
- Where have pure functions been extracted purely for testability, while the real bugs hide
  in how they are called — no **locality**?
- Where do tightly-coupled modules leak across their seams?
- Which parts are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate
complexity, or just move it? A "yes, concentrates" is the signal you want.

## 2. Present the candidates as an HTML report

Write a **self-contained** HTML file to the OS temp directory, so nothing lands in the repo.
Resolve the temp directory from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows),
and write `<tmpdir>/architecture-review-<timestamp>.html` so every run gets a fresh file.
Open it for the user and tell them the **absolute path**.

```bash
dir="${TMPDIR:-/tmp}"; dir="${dir%/}"
report="$dir/architecture-review-$(date +%Y%m%d-%H%M%S).html"
# ... write the report to "$report" ...
if command -v open >/dev/null 2>&1; then open "$report"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$report"
elif command -v start >/dev/null 2>&1; then start "$report"
fi
printf 'report: %s\n' "$report"
```

The report is not published anywhere. It is a file on the user's machine that their browser
opens; it may contain the names and shapes of private code, and it stays local.

The report uses **Tailwind via CDN** for layout and styling, and **Mermaid via CDN** for
diagrams wherever a graph, flow, or sequence communicates the structure reliably. Mix Mermaid
with hand-crafted CSS and SVG: Mermaid when relationships are graph-shaped (call graphs,
dependencies, sequences), hand-built divs and SVG when you want something more editorial
(mass diagrams, cross-sections, collapses). **Every candidate gets a before/after
visualisation. Be visual.**

Each candidate is a card carrying:

- **Files** — which files and modules are involved
- **Problem** — why the current architecture causes friction
- **Solution** — plain English, what would change
- **Benefits** — in terms of locality and leverage, and how the tests would improve
- **Before / after diagram** — side by side, custom-drawn, showing the shallowness and the
  deepening
- **Recommendation strength** — one of `Strong`, `Worth exploring`, `Speculative`, as a badge

End the report with a **Top recommendation** section: which candidate you would tackle first,
and why.

**Use `CONTEXT.md` vocabulary for the domain and the codebase-design vocabulary for the
architecture.** If `CONTEXT.md` defines "Order", talk about "the Order intake module" — not
"the FooBarHandler", and not "the Order service".

**ADR conflicts.** If a candidate contradicts an existing ADR, surface it *only* when the
friction is real enough to warrant revisiting that ADR, and mark it clearly in the card — a
warning callout reading *"contradicts ADR-0007, but worth reopening because …"*. Do not list
every theoretical refactor an ADR forbids.

The full HTML scaffold, the diagram patterns, and the styling and tone rules are in
`references/html-report.md`.

**Do NOT propose interfaces yet.** After the file is written, ask the user: *"Which of these
would you like to explore?"*

## 3. Grilling loop

Once the user picks a candidate, grill through it — walking the decision tree with them:
constraints, dependencies, the shape of the deepened module, what sits behind the seam, and
what tests survive.

Which griller runs is resolved at invocation time. See `references/grilling.md` for the
order, the probe, and the in-plugin protocol that runs when nothing else is installed.

### Side effects, inline

These happen as decisions crystallize, not in a batch at the end. Call the Skill tool with
`code-judo:domain-modeling` to keep the domain model current as you go.

- **Naming a deepened module after a concept that is not in `CONTEXT.md`?** Add the term.
  Create the file lazily if it does not exist.
- **Sharpening a fuzzy term during the conversation?** Update `CONTEXT.md` right there.
- **User rejects the candidate for a load-bearing reason?** Offer an ADR, framed as: *"Want
  me to record this as an ADR so future architecture reviews don't re-suggest it?"* Offer it
  only when the reason is one a future explorer would actually need in order to avoid
  re-suggesting the same thing. Skip ephemeral reasons ("not worth it right now") and
  self-evident ones.
- **Want to explore alternative interfaces for the deepened module?** Call the Skill tool
  with `code-judo:codebase-design` and use its design-it-twice parallel sub-agent pattern.

### In an ossify project

If the repo runs an ossify lifecycle, an accepted candidate is **feature-map and wayfinder
material** — say so, and point at it. That is a pointer for the user to act on, not a state
mutation.

**This plugin never runs `oss` verbs.** It does not open spines, close work items, or write
anything under `.ossify/`.
