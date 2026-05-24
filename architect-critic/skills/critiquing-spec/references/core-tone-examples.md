# CORE Tone Examples

Reference guide for the `critiquing-spec` skill. Each example shows the same spec challenge delivered
in two ways: a **wrong-tone** version that puts the author on the defensive, and a **CORE-toned**
rewrite that surfaces the same concern while keeping the conversation collaborative.

CORE = Curiosity · Objectivity · Reassurance · Empathy

---

## Example 1: Missing migration rollback

**Scenario:** The spec adds a schema migration (adding a non-nullable column) but contains no rollback
plan or revert strategy for if the migration fails mid-deployment.

**Wrong tone (accusatory / blunt):**
> "You forgot to include a rollback strategy. If this migration fails halfway through, you have no way
> to recover. This is a basic requirement for any schema change."

**Why this lands poorly:** "You forgot" frames absence of detail as carelessness, triggering
defensiveness rather than collaborative problem-solving.

**CORE tone (Curiosity, Objectivity, Reassurance, Empathy):**
> "The migration step is clear on the forward path — adding the non-nullable column and backfilling
> existing rows. I want to make sure I'm reading the full picture: what does recovery look like if the
> backfill stalls or the deployment is interrupted before all replicas have applied the schema? It's
> possible the rollback path lives in a runbook or is handled by the migration toolchain, in which case
> a pointer here would close the loop. If it genuinely hasn't been mapped yet, that's worth working out
> before shipping — partial migrations on non-nullable columns can leave the database in a state that
> blocks both forward and backward deploys."

**Why this lands well:** Opens with what the spec does well, frames the missing detail as a possible
oversight *or* an out-of-band concern, and explains the blast radius without assigning blame.

---

## Example 2: Unstated transaction boundary

**Scenario:** The spec describes two INSERT operations that must succeed or fail together, but no
database type is mentioned and no transaction wrapper is specified.

**Wrong tone (accusatory / blunt):**
> "These two INSERTs are obviously not atomic. You need to wrap them in a transaction. Anyone who
> has dealt with distributed writes knows this is a data-integrity problem."

**Why this lands poorly:** "Obviously" and "anyone who has dealt with" are condescending; they imply the
author lacks basic knowledge rather than that the spec is simply incomplete.

**CORE tone (Curiosity, Objectivity, Reassurance, Empathy):**
> "The flow shows two INSERTs — one to `orders` and one to `order_items`. I'm curious how atomicity is
> handled between them: if the `order_items` write fails after `orders` succeeds, what is the expected
> state and how does the system detect and reconcile it? This might already be addressed by a wrapping
> transaction or a saga compensator that isn't surfaced here. If it isn't, the failure path between the
> two writes is worth making explicit — the answer could be as simple as 'same DB, one transaction', but
> leaving it implicit means every reader has to infer it independently."

**Why this lands well:** Names the specific operations, asks rather than declares, acknowledges that the
answer may already exist elsewhere, and explains why *explicit* matters even when the answer is simple.

---

## Example 3: Unenumerated timeout failure

**Scenario:** The spec lists two failure modes (invalid input, downstream auth rejection) but omits the
obvious third: a network or service timeout when calling the downstream.

**Wrong tone (accusatory / blunt):**
> "Your failure modes section is incomplete. You listed auth rejection but completely ignored timeout
> failures. This will definitely cause issues in production."

**Why this lands poorly:** "Completely ignored" and "definitely cause issues" are judgmental predictions
that make the author feel attacked rather than helped.

**CORE tone (Curiosity, Objectivity, Reassurance, Empathy):**
> "The failure modes section covers invalid input and auth rejection — both precise and useful. I want
> to check whether timeout and general unavailability of the downstream service are in scope here: if
> the call to the auth provider hangs or returns a 5xx after the deadline, what should the caller
> experience? It may be that a shared timeout policy handles this at the infrastructure layer and
> doesn't need to be called out per-endpoint. If that's the case, a note pointing to that policy would
> help readers know the gap is covered. If it isn't covered, this is a third failure mode worth
> enumerating alongside the other two."

**Why this lands well:** Affirms what the section does cover, leaves open the possibility that the
concern is handled elsewhere, and offers the author a graceful exit (a pointer, not a full rewrite).

---

## Example 4: Implicit dependency

**Scenario:** The spec assumes a downstream notification service is reachable and responsive, but that
service is not listed in the dependencies section and no fallback is defined.

**Wrong tone (accusatory / blunt):**
> "You're assuming the notification service is always available, which it isn't. You haven't listed it
> as a dependency and there's no fallback. This is a design flaw."

**Why this lands poorly:** "Which it isn't" presents a contested assumption as settled fact;
"design flaw" is a verdict, not an observation — it shuts down discussion rather than opening it.

**CORE tone (Curiosity, Objectivity, Reassurance, Empathy):**
> "The notification dispatch step on line 14 calls the notification service synchronously. I don't see
> that service listed in the dependency inventory — is that intentional? If it's considered an internal
> implementation detail rather than an external dependency, that's a reasonable choice, but it would
> help to know what the caller's experience is when the service is slow or unreachable at dispatch time.
> Does the job retry, skip the notification, or surface an error? Capturing that explicitly means
> operators know what 'notification service is degraded' looks like from this job's perspective."

**Why this lands well:** Pins the observation to a specific line, offers an alternative interpretation
(internal vs. external) rather than declaring the spec wrong, and grounds the ask in operational
observability rather than abstract correctness.

---

## Example 5: Conflated concerns

**Scenario:** The spec mixes user-facing copy (error message strings) with logging configuration
(log level, structured fields) in the same section titled "Error Handling".

**Wrong tone (accusatory / blunt):**
> "This section is a mess. You've conflated user-facing copy with logging config, which are completely
> different concerns. This needs to be split up before review."

**Why this lands poorly:** "Mess" and "completely different" are dismissive; "needs to be split up
before review" is prescriptive about form rather than constructive about function.

**CORE tone (Curiosity, Objectivity, Reassurance, Empathy):**
> "The 'Error Handling' section covers two things: the strings users will see (e.g., 'Payment could
> not be processed') and the structured log fields emitted for operators (e.g., `error_code`,
> `trace_id`). Both are valuable content — I want to flag that readers coming from different angles
> (product, SRE) may have trouble finding what they need if these are interleaved. Is there a reason
> they live together here — perhaps to co-locate cause and presentation for review? If not, separating
> them into 'User-visible errors' and 'Observability' subsections might make each audience's job
> easier. Happy to leave it as-is if the co-location is deliberate."

**Why this lands well:** Identifies what each part of the section contributes, posits a charitable
reason for the current structure, and frames the split as a reader-experience improvement rather than
a structural defect.

---

## Anti-patterns

The following patterns must be avoided when authoring challenges. Each has caused real spec reviews
to stall because the author stopped engaging with the content and started defending themselves.

1. **Stacking multiple concerns into a single challenge.** If a single challenge paragraph touches
   more than one absent thing, the author can address the easiest one and sidestep the rest. One
   concern per challenge; file separately if they are truly independent.

2. **Naming the author instead of the artifact.** "You forgot X" and "you didn't consider Y" make the
   person the subject. "The spec does not address X" and "this section doesn't enumerate Y" make the
   document the subject — same observation, no personal charge.

3. **Rhetorical-judgment questions.** "Didn't you think about timeouts?" is not a question; it is a
   verdict with a question mark. Genuine curiosity questions are open ("how is X handled?"), not
   leading ("did you really not consider X?").

4. **Treating absence as obvious omission.** When something is missing, the critic does not know
   whether the author forgot it, deferred it to a runbook, or consciously decided it was out of scope.
   Acknowledging this uncertainty ("it may already be handled elsewhere") is not hedging — it is
   accurate and it keeps the author in problem-solving mode rather than self-defense mode.

5. **Issuing prescriptive rewrites.** "You need to split this section" or "this must be in a
   transaction" tells the author what to do before they've confirmed whether the diagnosis is correct.
   Surface the concern, explain the risk, and let the author propose the solution; the critic's job is
   to identify what is absent or unclear, not to redesign the spec.
