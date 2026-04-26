# SPEC: AI Mentor Plugin

**Status:** Draft v0.2 — design locked, build in progress
**Date:** 2026-04-26
**Owner:** Praveen Kumar Singh
**Distribution:** User-level — installed once globally via this marketplace; applies to *every* task and *every* project.
**Source:** Naval/Vinny-style "Top 1% use AI backwards" 4-step framework (transcript provided by user 2026-04-26).
**Companion spec:** `SPEC.md` archived as `docs/archive/SPEC-v1.md`; the "ultimate" scaffolding plugin will get a fresh spec before it is built.
**Repo home:** `claude-agent-scaffolding` marketplace (this repo).

---

## v0.2 amendments (locked decisions)

The v0.1 spec below remains the long-form design reference. The following decisions were made during the 2026-04-26 iteration session and **override** v0.1 where they conflict.

### A1. Pillar scope in v1
Ship **Pillars 3 (Gym) and 4 (Fool) only**. Defer Pillars 1 (DRAG) and 2 (Hill) to v1.1.
*Reason:* Pillar 3 is load-bearing mechanics (the PreToolUse hook); Pillar 4 is cheap (2 commands + 1 paragraph). DRAG/Hill add ambient cognitive nudges without enforcement and risk skill bloat. Validate the spotter mechanism first.

### A2. Zone 2 splits into two sub-modes
Two distinct sub-modes under `zone=2`, each with different unblock signals:

| Sub-mode | When to use | The "rep" the user does | Hook unblocks when |
|---|---|---|---|
| **`decide`** (daily/work) | Real project work where decisions matter but typing is overhead | Architecture, gap analysis, trade-off thinking, decision lock-in | User runs `/locked` (or `/implement` alias) — flips to `zone=1`, edits flow until user re-enters `/z2-decide` |
| **`build`** (personal/learning) | Side-project, capability-building | Both decisions *and* the typing | Per-edit inline override phrases ("show me", "skip to solution", "just write it", "z1") in last user message |

This is the most material refinement vs. v0.1, where Zone 2 conflated thinking and typing. The state schema gains a `submode` field.

### A3. Hook strictness: hard block with override grammar
PreToolUse hook **hard blocks** `Edit`/`Write`/`NotebookEdit` when `zone=2`. **Fail-open** on any error (missing state file, malformed JSON, missing transcript, jq error → allow tool). Never bricks the user's session.

### A4. State location: user-level
`~/.claude/ai-mentor/state.json` (single file across all projects). Default at SessionStart: `{ zone: "ambient", submode: null }` — no carryover from prior sessions.

State schema:
```json
{
  "zone": "1" | "2" | "ambient",
  "submode": "decide" | "build" | null,
  "set_at": "<iso timestamp>",
  "set_by": "skill" | "slash:/z1" | "slash:/z2-decide" | "slash:/z2-build" | "slash:/locked",
  "session_id": "<claude session id>",
  "quiz_level": 1 | 2 | 3 | 4 | null
}
```

### A5. Slash commands in v1 (7 total)

| Command | Effect |
|---|---|
| `/z1` | `zone=1, submode=null` — pure delegation, hook is no-op |
| `/z2-decide` | `zone=2, submode=decide` — block edits until `/locked` |
| `/z2-build` | `zone=2, submode=build` — block edits unless inline override phrase |
| `/locked` (alias `/implement`) | `zone=1, submode=null` — flips out of decide mode; AI implements |
| `/quiz l1`..`l4` / `/quiz off` | Sets/clears `quiz_level`; skill instructs Socratic depth |
| `/eli10` | Re-explain simpler; repeatable for further simplification |
| `/fool` | Sticky beginner's-mind mode for the conversation |

Pillar 1 commands (`/drag`) and Pillar 2 commands (`/cot`, `/ground`) deferred to v1.1.

### A6. Token budget
Always-on SessionStart `additionalContext` for v1 (Pillars 3+4 only): **~460 tokens** — *less* than the current pair-program plugin (~650 tokens). On-demand `SKILL.md` body adds ~750–1000 tokens, lazy-loaded.

### A7. Plugin layout (final v1)
```
ai-mentor/
├── .claude-plugin/plugin.json
├── hooks/hooks.json
├── hooks-handlers/
│   ├── session-start.sh         # reset state to ambient + emit additionalContext
│   └── pre-tool-use.sh          # enforcement (fail-open)
├── lib/state.sh                 # shared bash helpers
├── skills/ai-mentor/SKILL.md    # detailed Pillar 3 + 4 reference
├── commands/{z1,z2-decide,z2-build,locked,quiz,eli10,fool}.md
├── README.md
└── LICENSE
```

### A8. Resolved open questions (from §8 of v0.1)
- **Q1 (hook language)**: bash. `jq` is acceptable dependency on macOS/Linux.
- **Q2 (state location)**: user-level (`~/.claude/ai-mentor/state.json`).
- **Q3 (sticky vs per-edit)**: both — sub-modes encode the difference (decide is sticky-until-locked, build is per-edit override).
- **Q4 (auto-classification)**: skill *suggests* classification when ambiguous; user must explicitly `/z2-decide` or `/z2-build` to enter Curve 2. No auto-flip.
- **Q5 (quiz mode persistence)**: stored in `state.quiz_level`; cleared by `/quiz off` or session end.
- **Q6 (composition with scaffolding plugin)**: scaffolding plugin TBD; will use disjoint command namespace.
- **Q7 (distribution)**: directory marketplace for development, github marketplace for production install.
- **Q8 (default at session start)**: `ambient` — no carryover. SessionStart hook resets state.
- **Q9 (telemetry)**: deferred. Privacy-sensitive; add only if usage data motivates it.

### A9. Iteration log addendum
- **v0.2 (2026-04-26):** Locked all 9 open questions from v0.1. Introduced Zone 2 sub-mode split (`decide` vs `build`) — the most material refinement. Scoped v1 to Pillars 3+4. Selected `/locked` as the explicit decide→implement transition. Bootstrapped `claude-agent-scaffolding` repo as the marketplace home.

---

## Original v0.1 spec (below, retained for context)

## 1. TL;DR

A user-level Claude Code plugin that turns Claude into a **cognitive partner** rather than a code-vending machine. It encodes a 4-pillar framework (Intelligent Laziness / Hill / Gym / Fool) for deciding *when AI should remove friction* (Curve 1 work — capped payoff) versus *when AI should add friction* (Curve 2 work — transformative). Mechanical enforcement (hook + state file + slash commands) ensures the model can't drift back into "just write the code" mode when the user is supposed to be learning.

---

## 2. Motivation

The user previously authored a `pair-program` skill (Z1 / Z2 boilerplate vs. logic-building) — but it leaks: under task pressure Claude announces Z2 then writes the code anyway. Investigation revealed the skill was lifted from a richer source ("Top 1% use AI backwards" framework) but only carried over Step 3 of 4 (the spotter analogy). Without:

- **Step 1 (Intelligent Laziness)** — *which curve is this task on?* — classification was ad-hoc.
- **Step 2 (Intelligent Hill)** — *am I prompting at the right maturity level?* — quality of AI output unmanaged.
- **Step 4 (Intelligent Fool)** — *is my ego blocking learning?* — beginner-mind behavior absent.

…the spotter behavior had no surrounding scaffolding, so it was easy for both Claude and the user to forget when it should apply.

This plugin restores all 4 pillars and adds **mechanical enforcement** so spotter mode can't be silently violated.

---

## 3. Goals & Non-goals

### Goals
- **G1.** Encode the full 4-pillar framework as an always-on user-level skill.
- **G2.** Mechanical enforcement of Curve 2 (spotter mode) via hook + state file — no relying on Claude's discipline.
- **G3.** Frictionless escape hatch (slash commands + inline phrases) so the user can override per-edit or per-session.
- **G4.** Universal applicability — works for code, prose, strategy, learning, decisions. Not coding-specific.
- **G5.** Composable with other plugins (e.g., scaffolding plugin in `SPEC.md`) without conflicts.

### Non-goals
- **NG1.** Project scaffolding, governance docs, slice-specs — those live in the scaffolding plugin.
- **NG2.** Code-quality rules (CP-1..CP-9) — those live in the scaffolding plugin's `code-patterns` skill.
- **NG3.** Auto-classifying tasks. The skill suggests classification; user confirms via slash commands or inline phrases.
- **NG4.** Multi-user / team mode. Personal cognitive practice only.

---

## 4. Architecture overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     AI Mentor — 4-Pillar Framework                          │
│                       (always-on; user-level)                               │
│                                                                             │
│  ┌─────────────────────┐   ┌──────────────────────────────────────────┐     │
│  │ Pillar 1            │   │ Pillar 2                                 │     │
│  │ Intelligent         │   │ Intelligent Hill (prompting maturity)    │     │
│  │ Laziness (DRAG)     │   │   1. Oneshot                             │     │
│  │   D Drafting        │   │   2. Fewshot + grounding                 │     │
│  │   R Research        │   │   3. Chain-of-thought                    │     │
│  │   A Analysis        │   │   4. Agents                              │     │
│  │   G Grunt           │   │ Skill nudges user up the hill on demand. │     │
│  │ → Curve 1 only      │   └──────────────────────────────────────────┘     │
│  └─────────────────────┘                                                    │
│                                                                             │
│  ┌─────────────────────────────────┐  ┌──────────────────────────────────┐  │
│  │ Pillar 3                        │  │ Pillar 4                         │  │
│  │ Intelligent Gym                 │  │ Intelligent Fool                 │  │
│  │ (Curve 2 spotter mode)          │  │ (beginner's mind / fool's        │  │
│  │   - AI doesn't lift for you     │  │  advantage)                      │  │
│  │   - AI adds friction            │  │   /eli10  Explain Like I'm 10    │  │
│  │   - Progressive overload:       │  │   /fool   ask basic questions    │  │
│  │     /quiz l1 (high schooler)    │  │           without shame          │  │
│  │     /quiz l2 (college student)  │  │   probes false expertise         │  │
│  │     /quiz l3 (exec interview)   │  │                                  │  │
│  │     /quiz l4 (irate boss)       │  │                                  │  │
│  │   - Hook + state-file enforce   │  │                                  │  │
│  └─────────────────────────────────┘  └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

The skill loads on every session (user-level). Slash commands and the enforcement hook ship with the plugin and are registered globally.

---

## 5. Detailed design

### 5.1 Pillar 1 — Intelligent Laziness (DRAG)

**Two curves of work:**

| Curve | Nature | Examples | AI's role |
|---|---|---|---|
| **Curve 1** | Capped payoff. Effort → flat payoff after a point. | Internal emails, FYI meetings, expense reports, slide formatting, README tweaks, lint fixes. | Outsource — DRAG it (below). |
| **Curve 2** | Uncapped payoff. 1% better effort yields disproportionate result. | Customer conversations, product design, pricing, hiring, life decisions, learning new domains, architectural calls. | Spotter (Pillar 3) — friction, not replacement. |

**DRAG = four delegation modes for Curve 1:**
- **D — Drafting.** Blank-page problem. Use AIM protocol (Act / Input / Mission). First draft is bad on purpose; just unblock.
- **R — Research.** Deep search, summarization, competitive intel. Use Claude/GPT/Gemini deep-research mode where available.
- **A — Analysis.** First-pass pattern-finding on unstructured data.
- **G — Grunt.** Reformatting, translating, tabulating, data cleaning.

**Skill behavior:**
- When the user describes a task, the skill silently classifies (or asks if ambiguous): "This sounds like Curve 1 / Drafting — I'll just produce a first draft."
- Or: "This is Curve 2 / decision-making — let's set up spotter mode."
- Slash command `/drag <task description>` forces explicit DRAG classification.

### 5.2 Pillar 2 — Intelligent Hill (prompting maturity)

AI is a probability engine, not a calculator. Same prompt → different answer each time. The skill nudges the user up the four camps:

| Camp | Technique | Example shape |
|---|---|---|
| 1 | **Oneshot** — one example | "Write a LinkedIn post about X. Match the style of: [paste post]." |
| 2 | **Fewshot + grounding** — 3+ examples or docs attached | "Here are 5 of my prior presentations. Now write one for topic X in my voice." Includes "explain the pattern back to me first" pro-tip. |
| 3 | **Chain-of-thought** — make the model show its work | "Don't refine yet. List the top 3 issues with this report. Explain why for each. Think step-by-step." |
| 4 | **Agents** — multi-role compositions | "Do deep research on X. Cross-reference findings. Draft a one-page memo with the top 3 insights." |

**Skill behavior:**
- When the user issues a zeroshot prompt for a non-trivial task, the skill flags: "This is zeroshot — want me to suggest a Camp 2 (grounded) version?"
- Auto-formatting helpers: `/cot <prompt>` rewrites a prompt with chain-of-thought scaffolding; `/ground <prompt>` asks the user for example artifacts to attach.

### 5.3 Pillar 3 — Intelligent Gym (Curve 2 spotter mode)

The core enforcement pillar. For Curve 2 work where the user is supposed to grow capability:

**Spotter principles (lifted from transcript):**
1. The spotter doesn't lift the weight for you.
2. The spotter stands next to you and helps you lift only when you'd get crushed.
3. Progressive overload — increasingly harder challenges so capability grows.

**Behavioral rules in spotter mode:**
- Claude does NOT write code (or full prose, or full strategy) for the user.
- Claude offers hints at progressive levels (L1 nudge → L2 concept → L3 pseudocode → L4 solution); only L4 unblocks at user's explicit request.
- Claude asks Socratic questions to surface gaps in user's thinking.
- Claude calls out *bad reps* — flawed reasoning the user is about to commit to.

**Quiz protocol for learning a concept** (slash commands `/quiz l1..l4`):

| Level | Mode | Use when |
|---|---|---|
| L1 | Quiz like a high school student | Just learned the basics; checking comprehension. |
| L2 | Like a college student | Want to consolidate; expecting nuance. |
| L3 | Executive job interview | Stress-test under pressure; rapid-fire trade-offs. |
| L4 | Irate boss who thinks I'm unprepared | Adversarial probing of weak links; "convince me you understand." |

The user invokes `/quiz l<n>` to enter quiz mode; Claude runs Socratic grilling at that depth until the user invokes `/quiz off` or moves on.

### 5.4 Pillar 4 — Intelligent Fool (beginner's mind)

**Premise:** The biggest obstacle to intelligence is ego. Neuroplasticity happens at the *edge* of ability — when making errors, frustrated, uncomfortable. "If you don't feel stupid, you aren't learning."

**Behavioral rules:**
- Permission to ask "obvious" questions without judgment.
- The skill encourages re-asking the same explanation simpler N times: "Want me to explain that even simpler?"
- The skill **probes false expertise**: when the user uses jargon confidently, occasional checks like "What part of this would be hardest to explain to someone fresh?" or "If you only had 30 seconds, which detail would you drop?".

**Slash commands:**
- `/eli10` — Explain Like I'm 10. Re-invocable: each call simplifies further (`/eli10 again` → ELI5 → ELI3).
- `/fool` — enter fool's-advantage mode for the rest of the conversation. The skill stops assuming user expertise and walks ground-truth from first principles.

### 5.5 Slash commands (full list)

| Command | Pillar | Purpose |
|---|---|---|
| `/drag <task>` | 1 | Classify a task into Drafting / Research / Analysis / Grunt; switch to Curve 1 mode. |
| `/cot <prompt>` | 2 | Rewrite a prompt with chain-of-thought scaffolding. |
| `/ground <prompt>` | 2 | Ask user for example artifacts to attach for fewshot grounding. |
| `/z1` | 3 | Sticky toggle to Curve 1 (no enforcement). Hook becomes no-op. |
| `/z2` | 3 | Sticky toggle to Curve 2 (spotter mode). Hook blocks Edit/Write. |
| `/quiz l1`..`/quiz l4` | 3 | Enter Socratic quiz mode at level 1–4. |
| `/quiz off` | 3 | Exit quiz mode. |
| `/eli10` | 4 | Explain Like I'm 10. Repeatable for further simplification. |
| `/fool` | 4 | Enter fool's-advantage mode for the conversation. |

### 5.6 SKILL.md structure (sketch)

The skill auto-loads at session start and behaves as the cognitive operating system. Outline of `skills/ai-mentor/SKILL.md`:

1. **Identity:** "I'm your AI mentor. My job is to make you smarter, not to do your work."
2. **Default classification:** Default to Curve 2 for any task that involves judgment, learning, or design. Default to Curve 1 for grunt/admin work.
3. **Pillar 1 logic:** DRAG taxonomy + classification heuristics.
4. **Pillar 2 logic:** Maturity-camp detection + nudging.
5. **Pillar 3 logic:** Spotter behavior + progressive-hint escalation (L1–L4) + quiz protocol.
6. **Pillar 4 logic:** Beginner's mind defaults + false-expertise probes.
7. **Override grammar:** Recognize "z1", "just write it", "skip to solution", "show me", "/eli10", etc., as user-driven mode switches.
8. **State management:** Read/write `~/.claude/ai-mentor/state.json` when slash commands fire or user phrases trigger.

### 5.7 Curve-2 enforcement mechanism

**State file:** `~/.claude/ai-mentor/state.json` (user-level, not per-project).

```json
{
  "zone": "1" | "2" | "ambient",
  "set_at": "<iso timestamp>",
  "set_by": "skill" | "slash:/z1" | "slash:/z2" | "inline-phrase",
  "session_id": "<claude session id>"
}
```

Default value: `ambient` (no enforcement). User opts into Curve 2 via `/z2` or skill auto-classification.

**PreToolUse hook** (`hooks/pre-tool-use-curve2.sh`, registered in plugin's `settings.json`):

Pseudocode:
```
on tool ∈ {Edit, Write, NotebookEdit}:
  state = read(~/.claude/ai-mentor/state.json)
  if state.zone == "2":
    if last_user_message contains any of {"z1", "just write it", "just do it", "skip to solution", "show me"}:
      allow  # inline override
    else:
      block with error: "Curve 2 (spotter) mode is active. You're meant to do this rep yourself. Override: say 'z1' / 'just write it' / 'skip to solution', or run /z1 to flip the session."
  else:
    allow
```

**Slash commands** (`/z1`, `/z2`) update the state file synchronously before any other tool calls.

**Resilience:**
- If the hook script is missing or errors, default to allow (don't break user's session).
- Cross-platform: ship a `.sh` and a `.bat` (or use a Python script with a shebang line).
- The hook reads the state file directly, no daemon required.

---

## 6. Plugin layout

```
ai-mentor/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── ai-mentor/
│       └── SKILL.md                 # the 4-pillar framework
├── commands/
│   ├── drag.md                      # /drag — DRAG classification
│   ├── cot.md                       # /cot — chain-of-thought rewrite
│   ├── ground.md                    # /ground — fewshot grounding helper
│   ├── z1.md                        # /z1 — sticky Curve 1
│   ├── z2.md                        # /z2 — sticky Curve 2 (spotter)
│   ├── quiz.md                      # /quiz l1..l4 / off
│   ├── eli10.md                     # /eli10 — Explain Like I'm 10
│   └── fool.md                      # /fool — fool's-advantage mode
├── hooks/
│   ├── pre-tool-use-curve2.sh       # cross-platform: shell flavor
│   └── pre-tool-use-curve2.py       # cross-platform: python flavor (alt)
├── settings.json.tmpl               # registers the hook
├── README.md
└── LICENSE
```

---

## 7. Workflows / use cases

**Use case A — coding under spotter mode**
```
> /z2                                  # enter spotter mode
> "I want to implement a binary search."
[Claude] L1 hint: "What invariant must hold at each iteration?"
> "..."  (user thinks)
> "hint"
[Claude] L2: "It's a divide-and-conquer pattern. The invariant is on which half contains the target."
> "show me"                            # inline override
[Edit allowed by hook; Claude writes the function]
```

**Use case B — quiz protocol**
```
> "I just read about CAP theorem. /quiz l3"
[Claude] (executive interview) "Define partition tolerance in two sentences. Now justify why availability is sacrificed in CP systems. Counter-example?"
... (back-and-forth)
> "/quiz off"
```

**Use case C — beginner's mind on a foreign codebase**
```
> "/fool"
> "What does this regex do?"
[Claude] (explains at ground-truth level, no jargon assumed)
> "/eli10"
[Claude] (re-explains as a 10-year-old story)
> "/eli10 again"
[Claude] (simpler still)
```

---

## 8. Open questions

| # | Question | Notes |
|---|---|---|
| Q1 | **Hook script language** | Shell vs Python. Shell is portable but jq dependency for JSON state. Python is more robust but assumes interpreter. Probably ship both. |
| Q2 | **State file location** | `~/.claude/ai-mentor/state.json` (user-level, persistent across sessions and projects) vs. `.claude/.zone` (per-project). User-level chosen here, but per-project might better fit the "different mental mode for different projects" use case. |
| Q3 | **Sticky session vs per-edit** | `/z2` is sticky; do we also need a transient `/z2-once` for one-off mentor moments? |
| Q4 | **Auto-classification confidence** | Should the skill auto-flip to Curve 2 when it detects a "transformative" task, or always require explicit `/z2`? Auto risks annoyance; manual risks underuse. |
| Q5 | **Quiz mode persistence** | After `/quiz l3`, does `/quiz` (no arg) repeat the last level, or default to L1? |
| Q6 | **Composition with scaffolding plugin** | Both plugins ship slash commands. Are there name collisions? `/z1`/`/z2` should be only here, not in scaffolding. Naming convention TBD. |
| Q7 | **User-level distribution mechanism** | `~/.claude/plugins/` install? Marketplace entry? Git URL? Plugin distribution defaults to per-project, so user-level needs explicit user-level install. |
| Q8 | **Curve 2 default for new sessions** | At session start, does state default to `ambient`, or carry over from prior session? Sticky-across-sessions could be confusing; ambient feels right. |
| Q9 | **Telemetry / usage feedback** | Should the plugin log how often the user overrides (`/z1` / "just write it") to surface "you're overriding 80% of the time — maybe Curve 2 isn't the right mode for this work"? Privacy implications. |

---

## 9. Risks

- **R1 (high):** Hook annoys the user enough to disable the plugin. *Mitigation:* generous override grammar; clear error messages; sticky session toggle so override is once-per-session not once-per-edit.
- **R2 (medium):** Slash command name collisions with other user-level plugins. *Mitigation:* prefix with `mentor:` if collisions emerge — `/mentor:z2` etc.
- **R3 (medium):** Skill text grows unwieldy and bloats every session. *Mitigation:* aggressive editing; break into branch-loaded sections similar to the scaffolding plugin's CLAUDE.md tiered preload.
- **R4 (low):** Auto-classification gets it wrong consistently — flips to spotter on Curve 1 work. *Mitigation:* default to ambient; only auto-flip when user has opted into auto-classify mode.
- **R5 (low):** Cross-platform hook script issues (Windows users). *Mitigation:* ship both `.sh` and `.py`/`.bat` flavors; document setup.

---

## 10. Verification

1. **Pillar 1 smoke:** Ask the skill to classify `"reformat this CSV"` → expect Curve 1 / G (Grunt). Ask `"design a pricing model"` → expect Curve 2.
2. **Pillar 2 smoke:** Issue a zeroshot prompt for a hard task → expect skill to nudge toward Camp 2 (grounding).
3. **Pillar 3 smoke:**
   - Run `/z2` → trigger any Edit → expect hook block with override message.
   - Say "just write it" → expect Edit allowed.
   - Run `/z1` → trigger Edit → expect allowed.
4. **Pillar 4 smoke:** Run `/eli10` on a concept → expect simplified explanation. Run `/eli10 again` → expect even simpler.
5. **Quiz protocol smoke:** Run `/quiz l1` after pasting a concept → expect Socratic questioning at high-school level. Run `/quiz l4` → expect adversarial probing.
6. **Composition:** Install alongside scaffolding plugin → run a `/spec` from scaffolding → expect mentor skill to *not* interfere with Curve 1 spec authoring tasks.

---

## 11. Build sequence (when we get to it — not now)

1. Author `skills/ai-mentor/SKILL.md` (the 4-pillar framework).
2. Author slash command files (`drag`, `cot`, `ground`, `z1`, `z2`, `quiz`, `eli10`, `fool`).
3. Author hook scripts (shell + python) and `settings.json.tmpl`.
4. Author `.claude-plugin/plugin.json` manifest.
5. Author `README.md` (install instructions for user-level distribution).
6. Verify per §10.

---

## Iteration log

- **v0.1 (2026-04-26):** First-pass spec authored after the user identified that the original `pair-program` skill came from the "Top 1% use AI backwards" 4-step framework. Captures the full 4-pillar framework, 9 slash commands, hook-based Curve 2 enforcement design, plugin layout, workflows, 9 open questions, risks, and verification protocol. Co-located in the scaffolding-plugin repo for now; will move to its own repo when the AI Mentor plugin is built.
