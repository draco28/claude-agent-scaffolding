# `user:` grammar — deep dive with worked examples

Reference for the `authoring-vertical-slice-demo` skill (scaffold-onboard SPEC §9.1, scaffold-dev SPEC §14.1). This doc covers the `user:` form only — the human-checkable demo-criterion line that scaffold-dev's `closing-vertical-slice` skill surfaces to a human reviewer at slice-close time. See `auto-grammar.md` for the `auto:` form.

---

## 1. Grammar

```
- [ ] user: <action description> → expected: <observable outcome>
```

Components, in order:

1. **Checkbox prefix** — `- [ ] ` (markdown mode; stripped in state-mode array entries).
2. **Form prefix** — the literal token `user:` followed by a single space.
3. **Action description** — a natural-language instruction a human can perform. Imperative voice (`Navigate to ...`, `Click ...`, `Submit ...`).
4. **Arrow delimiter** — the literal **U+2192 arrow character** (`→`), surrounded by single spaces. NOT the ASCII `->` digraph.
5. **Expected clause** — `expected:` followed by a single space, then an **observable outcome** — a UI state, a visible element, a perceivable result. NOT an exit code, NOT a stdout pattern.

scaffold-dev's slice-close walkthrough presents each `user:` line to the human reviewer, who performs the action manually and reports back (pass / fail / partial). The skill body does NOT execute these lines.

---

## 2. What counts as an "observable outcome"

A human can verify it in real time without instrumenting the system: a UI element visible / hidden / state-changed, a page navigation or panel open within a perceptible time bound, a form validation error rendering inline, a toast with specific text, an installed plugin appearing in a list. NOT observable (wrong-form for `user:`): exit codes (`auto:`), log lines (`auto:` + grep), DB row counts (`auto:` + SQL), "works correctly" (see §4.2).

---

## 3. Ten worked examples across user-facing surfaces

Each example is a complete, copy-paste-ready bullet line.

### 3.1 Web app page load (visible element)

```
- [ ] user: Navigate to localhost:3000/insights → expected: action-needed card visible with real data
```

The reviewer opens the URL in a browser and verifies the card renders with non-placeholder content. "With real data" is a meaningful qualifier — distinguishes a working page from one showing loading skeletons or demo fixtures.

### 3.2 UI panel toggle (interaction + time bound)

```
- [ ] user: Click the chatbot icon in the bottom-right corner → expected: chat panel opens within 2s
```

The action is a single click; the expected outcome includes a measurable time bound (2s) so "feels slow" isn't a judgment call. See §4 on making subjective qualities measurable.

### 3.3 Form validation (negative test)

```
- [ ] user: Submit the signup form with email "test@bad" → expected: inline error "Invalid email format" visible under the email field
```

Negative-test demos verify error paths. The expected outcome names both the error text AND its placement (under the field, not in a toast or modal) — both matter for a working error UX.

### 3.4 Plugin / skill installation (CLI-adjacent user action)

```
- [ ] user: Run `/plugin install insights-demo` in Claude Code, then restart the session → expected: `insights-demo` appears in /plugin list output
```

The "user" is a developer using the Claude Code CLI. The action runs a command, but the observable outcome is the visible plugin-list entry — that's why it's `user:`, not `auto:`.

### 3.5 Keyboard shortcut (interaction + state change)

```
- [ ] user: Press Cmd+K (macOS) or Ctrl+K (Linux/Windows) on the dashboard → expected: command palette opens with cursor in the search input
```

Two-part outcome: palette opens AND cursor focus lands in the search input (a common focus-trap regression).

### 3.6 Drag-and-drop (rich interaction)

```
- [ ] user: Drag a task card from "Todo" column to "Done" column → expected: card appears in "Done" and disappears from "Todo" within 1s
```

Drag-and-drop is hard to fake; the reviewer must perform it. Outcome covers both ends of the state transition within a time bound.

### 3.7 Authentication flow (multi-step boundary)

```
- [ ] user: Click "Sign in with Google" and complete OAuth in the popup → expected: redirected to /dashboard with user avatar visible in top-right
```

Multi-step is acceptable when steps form one logical journey with no useful mid-flow observation. Compare with §4.1's split rule.

### 3.8 Real-time update (multi-client interaction)

```
- [ ] user: Open localhost:3000/chat in two browser tabs, send "hello" from tab A → expected: "hello" appears in tab B within 3s without manual refresh
```

WebSocket / SSE features are hard to verify with `auto:` without elaborate harnesses; the two-tab manual demo is canonical. Always pin the time bound.

### 3.9 Error recovery (resilience demo)

```
- [ ] user: With the dev server running, kill the backend (`pkill -f api-server`) and refresh the page → expected: "Backend unavailable" banner visible; UI remains responsive (no white screen)
```

Mixes a small CLI action with a UI observation. Outcome covers what SHOULD render (banner) and what should NOT (crash white screen).

### 3.10 CLI / TUI user (terminal-as-UI)

```
- [ ] user: Run `insights-cli watch --tail` and observe for 30s → expected: new event lines appear every 5-10s with non-empty payload
```

Terminal UIs are user-facing too. The outcome describes what the human sees on screen during the observation window.

---

## 4. Edge cases

### 4.1 Multi-step actions — break into multiple criteria

If the action description contains "then ... then ... then" or a comma-separated verb list, it's a smell. Split into one criterion per logical step so slice-close failures pinpoint the broken step:

```
WRONG: - [ ] user: Sign in, navigate to settings, change theme to dark, log out → expected: theme persisted

RIGHT:
- [ ] user: Sign in with valid credentials → expected: redirected to /dashboard
- [ ] user: On /settings, change theme to "dark" → expected: page re-renders in dark theme immediately
- [ ] user: Log out and sign in again → expected: dashboard renders in dark theme (preference persisted)
```

The OAuth example in §3.7 is the borderline case — one external popup is acceptable inside one criterion because there's no useful mid-flow observation.

### 4.2 Subjective quality bars — make them measurable

"Fast" and "responsive" are unfalsifiable. Pin a time/count bound, even a rough one:

```
WRONG: → expected: loads fast
RIGHT: → expected: first contentful paint within 2s

WRONG: → expected: feels responsive
RIGHT: → expected: button state changes to "Loading..." within 100ms
```

If you genuinely don't know the budget yet, name a placeholder (`within 5s`) and refine at scaffold-dev top-up time.

### 4.3 User-as-developer vs user-as-end-user

Both audiences are valid. End-users click buttons and navigate pages (§3.1, §3.2); developer-users run CLI commands and inspect lists (§3.4, §3.10). The distinction matters for who runs slice-close — end-user demos need the app running with realistic data; developer-user demos need the dev environment + CLI access. Surface the audience in the action description when it's not obvious.

### 4.4 Outcomes that require setup

Like `auto:` lines, `user:` lines assume the demo environment is provisioned. If the action requires specific test data, either seed via fixture before slice-close, or phrase the outcome around invariants ("at least one card visible") rather than specific counts ("12 cards"). The grammar doesn't carry setup.

### 4.5 Outcomes that need instrumentation are `auto:` in disguise

If verifying requires opening DevTools, attaching a debugger, or reading a log file, re-author as `auto:`:

```
RECONSIDER: - [ ] user: Open DevTools → expected: no console errors after page load
REWRITE TO:  - [ ] auto: `playwright test tests/e2e/no-console-errors.spec.ts` → expected: exit 0
```

Reserve `user:` for outcomes a human can verify with their eyes and the standard product surface.

---

## 5. Anti-patterns

### 5.1 Vague outcomes

```
WRONG: → expected: works correctly | looks good | no errors | behaves as expected
```

These outcomes have no falsifiable shape — every reviewer marks them pass by default. Replace with specific observables: which element, which state, which value, within what bound. See §4.2 for the rewrite pattern.

### 5.2 Mixing `user:` and `auto:` semantics

```
WRONG: - [ ] user: Run pytest tests/ → expected: exit 0
```

CLI command + exit-code expectation is `auto:` shape; SKILL.md §3.3 catches this and prompts a rewrite (do not silently re-classify). Inverse:

```
WRONG: - [ ] auto: `npm start && open http://localhost:3000` → expected: dashboard visible
```

UI observable as `expected:` is `user:` shape; `auto:` requires machine-checkable expectations.

### 5.3 ASCII `->` instead of `→`

```
WRONG: - [ ] user: Click the menu icon -> expected: menu opens
RIGHT: - [ ] user: Click the menu icon → expected: menu opens
```

Same rule as `auto:` (see `auto-grammar.md` §5.1). U+2192 only.

### 5.4 Action descriptions with implicit context

Slice-close walkthroughs may happen days or weeks after authoring; name the element specifically:

```
WRONG: - [ ] user: Click the button → expected: form submits
RIGHT: - [ ] user: On /signup, click the "Create account" submit button → expected: form submits and user redirected to /verify-email
```

### 5.5 Environment-coupled outcomes and placeholders

```
WRONG: → expected: 12 cards visible              (count depends on fixture; pin or use "at least one")
WRONG: - [ ] user: <do the thing> → expected: <it works>
WRONG: - [ ] user: TODO: figure out the user flow → expected: TODO
```

Skeleton authoring during R1.C is permitted, but the SHAPE must be a real instruction even if the feature isn't built yet. Placeholder angle-brackets and TODO markers fail downstream — the walkthrough has no way to present them to a reviewer.

---

## 6. Cross-references

- **scaffold-onboard SPEC §9.1** — grammar definition (verbatim source).
- **scaffold-dev SPEC §14.2** — runtime semantics (how the slice-close skill surfaces user lines to the reviewer).
- **scaffold-onboard SPEC §9.3** — `sf_demo_parse_line` API contract.
- **SKILL.md §3, §7, §11, §15** — form discrimination, validation flow, U+2192 rationale, anti-patterns at the skill-body layer.
- **`auto-grammar.md`** — companion reference for the `auto:` form.
