# HTML report format

The architecture review is rendered as a **single HTML file** in the OS temp directory.
Mermaid handles graph-shaped diagrams reliably; hand-built divs and inline SVG handle the more
editorial visuals — mass diagrams, cross-sections. Mix the two. Leaning on Mermaid for
everything makes the report look generic.

**One file is not the same as self-contained.** Tailwind and Mermaid load from CDNs, so the
report needs network access to render: offline or on a restricted network it opens unstyled
and without diagrams. Say so when you hand over the path, rather than describing the file as
self-contained. Two consequences follow, and both are in the scaffold below:

- **Pin Mermaid to an exact version**, not a major range. An unpinned dependency means the
  report renders differently next month than it does today, and the report is the artifact
  the decision gets made from.
- **Keep `securityLevel: "strict"`.** Diagram labels are derived from the repository — module
  names, file paths, sometimes identifiers pulled straight out of the code. Under `"loose"`
  those labels are interpreted as HTML and click handlers are enabled, which turns repository
  text into markup in the reader's browser. Escape any label you are unsure of, and reach for
  a looser level only if a specific diagram genuinely needs interactivity.

## Scaffold

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Architecture review for {{repo name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11.17.2/dist/mermaid.esm.min.mjs";
      mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "strict" });
    </script>
    <style>
      /* small custom layer for what Tailwind does not cover cleanly:
         dashed seam lines, hand-drawn-feeling arrow heads, and so on */
      .seam { stroke-dasharray: 4 4; }
      .leak { stroke: #dc2626; }
      .deep { background: linear-gradient(135deg, #0f172a, #1e293b); }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-5xl mx-auto px-6 py-12 space-y-12">
      <header>...</header>
      <section id="candidates" class="space-y-10">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

## Header

Repo name, date, and a compact legend: solid box = module, dashed line = seam, red arrow =
leakage, thick dark box = deep module. **No introduction paragraph.** Straight into the
candidates.

## Candidate card

The diagrams carry the weight. Prose is sparse, plain, and uses the glossary terms from
`code-judo:codebase-design` without ceremony.

Each candidate is one `<article>`:

- **Title** — short, names the deepening. "Collapse the Order intake pipeline."
- **Badge row** — recommendation strength (`Strong` = emerald, `Worth exploring` = amber,
  `Speculative` = slate), plus a tag for the dependency category: `in-process`,
  `local-substitutable`, `ports & adapters`, `mock`. The four categories are defined in
  `code-judo:codebase-design` → `references/deepening.md`; classify before you tag.
- **Files** — monospaced list, `font-mono text-sm`.
- **Before / after diagram** — the centrepiece. Two columns, side by side. Patterns below.
- **Problem** — one sentence. What hurts.
- **Solution** — one sentence. What changes.
- **Wins** — bullets, six words or fewer each. "Tests hit one interface." "Pricing stops
  leaking." "Delete 4 shallow wrappers."
- **ADR callout**, where applicable — one line, amber-tinted box.

**No paragraphs of explanation.** If the diagram needs a paragraph to be understood, redraw
the diagram.

## Diagram patterns

Pick the pattern that fits the candidate. Mix them. Do not make every diagram look the same —
variety is part of the point.

### Mermaid graph — the workhorse for dependencies and call flow

Use a Mermaid `flowchart` or `graph` when the point is "X calls Y calls Z, and look at the
mess." Wrap it in a Tailwind-styled card so it does not look parachuted in. Use `classDef` to
colour leakage edges red and the deep module dark. Sequence diagrams work well for "before:
six round-trips; after: one."

```html
<div class="rounded-lg border border-slate-200 bg-white p-4">
  <pre class="mermaid">
    flowchart LR
      A[OrderHandler] --> B[OrderValidator]
      B --> C[OrderRepo]
      C -.leak.-> D[PricingClient]
      classDef leak stroke:#dc2626,stroke-width:2px;
      class C,D leak
  </pre>
</div>
```

### Hand-built boxes and arrows — when Mermaid's layout fights you

Modules as `<div>`s with borders and labels. Arrows as inline SVG `<line>` or `<path>`
positioned absolutely over a relative container. Reach for this when the "after" diagram
should feel like one thick-bordered deep module with greyed-out internals — Mermaid will not
render that with the right weight.

### Cross-section — good for layered shallowness

Stack horizontal bands (`h-12 border-l-4`) showing the layers a call passes through. Before:
six thin layers each doing nothing. After: one thick band labelled with the consolidated
responsibility.

### Mass diagram — good for "interface as wide as implementation"

Two rectangles per module: one for interface surface area, one for implementation. Before:
the interface rectangle is nearly as tall as the implementation rectangle — shallow. After:
the interface rectangle is short and the implementation rectangle is tall — deep.

### Call-graph collapse

Before: a tree of function calls as nested boxes. After: the same tree collapsed into one
box, the now-internal calls shown faded inside it.

## Style

- Lean editorial, not corporate-dashboard. Generous whitespace. Serif headings work well with
  stone and slate.
- Colour sparingly: one accent (emerald or indigo), plus red for leakage and amber for
  warnings.
- Keep diagrams around 320px tall, so before and after sit side by side without scrolling.
- Use `text-xs uppercase tracking-wider` for module labels inside diagrams, so they read as
  schematic rather than as UI.
- **The only scripts are the Tailwind CDN and the Mermaid ESM import.** The report is
  otherwise static: no app code, no interactivity beyond Mermaid's own rendering. Do not add
  a third script; every one of them runs in the same document as a review of private code.

## Top recommendation section

One larger card. Candidate name, one sentence on why, anchor link to its card. That is it.

## Tone

Plain English, concise — but the architectural nouns and verbs come straight from
`code-judo:codebase-design`. Concision is not an excuse to drift.

**Use exactly:** module, interface, implementation, depth, deep, shallow, seam, adapter,
leverage, locality.

**Never substitute:** component, service, unit (for module) · API, signature (for interface) ·
boundary (for seam) · layer, wrapper (for module, when you mean module).

Phrasings that fit:

- "Order intake module is shallow: interface nearly matches the implementation."
- "Pricing leaks across the seam."
- "Deepen: one interface, one place to test."
- "Two adapters justify the seam: HTTP in prod, in-memory in tests."

**Wins bullets name the gain in glossary terms** — *"locality: bugs concentrate in one
module"*, *"leverage: one interface, N call sites"*, *"interface shrinks; implementation
absorbs the wrappers"*. Do not write *"easier to maintain"* or *"cleaner code"*: those terms
are not in the glossary and they do not earn their place.

No hedging, no throat-clearing, no "it's worth noting that…". If a sentence could be a
bullet, make it a bullet. If a bullet could be cut, cut it. If a term is not in the
`code-judo:codebase-design` glossary, reach for one that is before inventing a new one.
