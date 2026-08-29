# code-judo

Strict quality review and architecture deepening. Four prose skills, no runtime library.

The name is the thesis. A **code-judo move** is a restructuring that uses the existing
architecture more effectively and makes a change dramatically simpler — one that *deletes*
complexity rather than rearranging it. Both review surfaces here are built to hunt for those,
not to collect nits.

## Skills

| Skill | Scope | What it does |
|---|---|---|
| `deep-review` | diff / branch | An unusually strict maintainability review. The code-judo ambition standard, the 1000-line rule, spaghetti-growth suspicion, wrapper/cast/boundary rules, prioritized output, and a categorical approval bar. **Human-invoked only.** |
| `deepen-architecture` | codebase | A proactive scan for deepening opportunities, presented as a self-contained HTML report opened in your browser, then a grilling loop on the candidate you pick. **Human-invoked only.** |
| `codebase-design` | any | The design vocabulary the other two speak: module, interface, depth, seam, adapter, leverage, locality. The deletion test, "the interface is the test surface", seam discipline, and the design-it-twice pattern. |
| `domain-modeling` | any | The project's domain glossary (`CONTEXT.md`) and its ADRs. Adds terms as concepts get named, sharpens fuzzy ones in place, and offers an ADR only when a decision is hard to reverse, surprising, and a real trade-off. |

## Commands

| Command | Skill |
|---|---|
| `/code-judo:deep-review [base-ref]` | `deep-review` |
| `/code-judo:deepen-architecture [direction]` | `deepen-architecture` |
| `/code-judo:codebase-design [module or question]` | `codebase-design` |
| `/code-judo:domain-modeling [term or decision]` | `domain-modeling` |

## What `deep-review` is not

It is not a correctness review and not a security review. It does not look for bugs, breaking
changes, or vulnerabilities — those are different questions asked by different tools, and
mixing them into one pass makes both worse.

It produces **one report and one disposition pass, and never re-reviews its own fixes.** A
review that grades its own remedies always finds something, because every fix is new code and
new code has findings; a self-reviewing loop has no natural end, and its later rounds measure
the review rather than the change. A second review is a new human decision.

Its verdict is **advisory** — "the bar is not met, because …" — never a merge gate.

## The report

`deepen-architecture` writes a self-contained HTML file to the OS temp directory and opens it
in your browser, telling you the absolute path. Nothing lands in the repo and nothing is
published anywhere; the file may name private code and it stays on your machine. Tailwind and
Mermaid load from CDNs, so rendering it needs a network connection.

## Dependencies

None that are hard. The grilling step resolves softly: `ossify:challenge` when ossify is
installed, else `ai-mentor:grill-me` when present, else a complete grill protocol the plugin
carries itself. Nothing about correctness changes when neither is installed.

This plugin never runs `oss` verbs and never writes to another plugin's state.

## Lineage

Adapted, with thanks, from two upstreams:

- Cursor's `thermo-nuclear-code-quality-review` (`cursor/plugins`) — the review posture, the
  standards, the flags and remedies, the approval bar.
- Matt Pocock's `improve-codebase-architecture`, `codebase-design`, `domain-modeling`, and
  `grilling` (`mattpocock/skills`) — hot-spot scoping, the deletion test, the HTML report
  format, the grilling loop, and the ADR side effects.

Two things were deliberately changed: `deep-review` gained the stopping discipline described
above, and the cross-skill dependency web was internalized so the plugin is complete on its
own. See issue #382 for the full port record, including what was knowingly left out and why.
