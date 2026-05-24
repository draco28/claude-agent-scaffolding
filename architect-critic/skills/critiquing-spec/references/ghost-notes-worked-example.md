# Ghost-notes worked example: nightly payment reconciliation job

Ghost-notes is the practice of reading a spec for what is *not on the page* — the implied
dependencies, unenumerated failure modes, unstated invariants, and silent environment assumptions
that the author considered too obvious to write down or simply didn't think of. This document walks
through a single fictional spec audit to show how applying ghost-notes surfaced findings that a
literal reading of the spec would have missed entirely.

---

## The spec under audit

```
Title: Nightly Payment Reconciliation Job — v1.2
Author: @payments-team
Status: Ready for review

### Purpose
Reconcile the previous calendar day's transactions in the internal `orders` database
against the settlement ledger exported by the payment processor. Flag any mismatches for
manual review by the Finance team by 07:00 UTC.

### Trigger
Scheduled via cron at 02:00 UTC daily. No manual trigger is supported.

### Inputs
- `orders` table (PostgreSQL): rows with `settled_at` between 00:00 and 23:59 UTC of the
  previous calendar day.
- Settlement CSV from payment processor: delivered to `s3://payments-exports/YYYY-MM-DD/settlement.csv`
  by 01:30 UTC daily per the processor's SLA.

### Processing steps
1. Download settlement CSV from S3.
2. Query `orders` for the prior day's settled rows.
3. Join on `external_transaction_id`. For each row:
   a. If amounts match: mark `reconciliation_status = 'matched'`.
   b. If amounts differ by more than $0.01: mark `reconciliation_status = 'mismatch'` and
      write a row to `reconciliation_mismatches`.
   c. If a transaction exists in the processor ledger but not in `orders`: write to
      `reconciliation_orphans`.
4. Send a summary email to finance-alerts@company.com with counts: matched, mismatched, orphaned.
5. Mark the job run as complete in `reconciliation_runs`.

### Failure modes
- S3 file not found: job exits with status FAILED; on-call is paged via PagerDuty.
- Database connection failure: job exits with status FAILED; on-call is paged via PagerDuty.

### Output
- Updated `reconciliation_status` on matched `orders` rows.
- Rows in `reconciliation_mismatches` for Finance review.
- Rows in `reconciliation_orphans` for Finance review.
- Summary email to finance-alerts@company.com.

### Dependencies
- PostgreSQL (orders database)
- AWS S3 (settlement CSV delivery)
```

---

## Step 1: Literal reading (what the spec says)

- **Goal:** Reconcile yesterday's payments between the internal DB and the processor's settlement CSV
  by 07:00 UTC.
- **Trigger:** Cron at 02:00 UTC. No manual trigger.
- **Inputs:** Two sources — `orders` table (PostgreSQL) and a CSV from S3, expected by 01:30 UTC.
- **Processing:** Download CSV, query DB, join on `external_transaction_id`, classify each row as
  matched / mismatch / orphaned.
- **Notifications:** Summary email to Finance on every run.
- **Explicit failure modes:** S3 file missing; DB connection failure — both page on-call.
- **Outputs:** Status updates to `orders`, rows to two mismatch tables, run record, email.
- **Listed dependencies:** PostgreSQL, AWS S3.

---

## Step 2: Ghost-notes scan (what is absent?)

Apply the heuristics: implied dependencies, unenumerated failure modes, missing rollback paths,
unstated invariants, undefined state-change boundaries, hidden concurrency assumptions, silent
environment dependencies, undefined partial-success paths.

- **Implied dependency — SMTP / email relay:** Step 4 sends email to finance-alerts@company.com.
  No email service is listed in the dependencies section. If the SMTP relay or SES quota is
  exhausted, does the job record FAILED or SUCCEEDED? The Finance team may not know the job ran
  at all.

- **Implied dependency — IAM / S3 credentials:** The spec lists S3 as a dependency but not the
  credential or role that grants read access. If the IAM role expires or the bucket policy is
  rotated, the error will look like "S3 file not found" rather than a permissions failure —
  masking the root cause from the operator.

- **Unenumerated failure mode — processor SLA slip:** The CSV is expected by 01:30 UTC per the
  processor's SLA, but the job starts at 02:00 UTC. The spec handles "S3 file not found" but not
  "S3 file is present but incomplete or still being written." A CSV that is mid-upload at 02:00 UTC
  will parse without error and produce silently wrong reconciliation results.

- **Unenumerated failure mode — email delivery failure:** Step 4 fails silently if the email cannot
  be sent. The job will mark itself SUCCEEDED in `reconciliation_runs` even if Finance never receives
  the summary. The absence of a notification is not itself paged.

- **Missing rollback / idempotency path:** If the job crashes between steps 3 and 5 (after writing
  mismatches but before marking the run complete), re-running the job will produce duplicate rows in
  `reconciliation_mismatches` and `reconciliation_orphans`. The spec does not state whether the job
  is idempotent or how a partial run is detected and cleaned up.

- **Unstated invariant — exactly-once settlement file:** The spec assumes one CSV per day. The
  processor's SLA language does not preclude amended or supplemental files (common for chargebacks
  processed after close-of-day). If a second file appears, the job will not see it and will silently
  under-reconcile.

- **Undefined state-change boundary — transaction scope:** Step 3 writes to three tables
  (`orders`, `reconciliation_mismatches`, `reconciliation_orphans`). The spec does not state whether
  these writes are wrapped in a transaction. A crash mid-step-3 could leave `orders.reconciliation_status`
  partially updated with no corresponding mismatch rows, creating a permanently inconsistent view.

- **Silent environment dependency — timezone handling:** The spec says "prior calendar day" and
  "00:00 to 23:59 UTC". The cron fires at 02:00 UTC. If the PostgreSQL server is configured in a
  non-UTC timezone (common in legacy setups), the `settled_at` range query will silently shift,
  causing rows from the wrong day to be included or excluded.

---

## Step 3: Severity triage

Classifying the ghost-notes findings by type:

- **`premise`** (assumption-invalidating — the spec cannot ship as-written without resolving this):
  - *Incomplete-file ingestion:* A mid-upload CSV produces wrong results with no error signal.
    This invalidates the core correctness guarantee of the job.
  - *Transaction scope undefined:* Partial writes to three tables with no rollback leaves the
    system in an undetectable inconsistent state.

- **`gap`** (something the spec needs that is missing, but does not invalidate the core design):
  - *Email relay not in dependencies:* Finance's only notification path has no failure handling.
  - *IAM credentials not in dependencies:* Permissions errors are masked as file-not-found.
  - *Idempotency on re-run not specified:* Duplicate mismatch rows are a Finance workflow problem,
    not a data-corruption problem, but still need a fix path.

- **`alternative`** (different framing the author should consider — valid as-is but worth raising):
  - *Supplemental CSV files:* Depends on the processor contract; the author may have confirmed this
    is not an issue. Worth one question.
  - *Timezone configuration:* Most likely already UTC, but worth one explicit confirmation given
    how invisible the failure mode is.

---

## Step 4: CORE-toned surfacing

The two `premise`-severity findings and one `gap`-severity finding, rewritten for delivery in the
rebuttal cycle:

**Finding 1 — Incomplete-file ingestion (premise)**
> "Step 1 downloads the settlement CSV from S3. The spec handles the case where the file is absent,
> but I want to check how partial delivery is detected: if the processor's upload is still in progress
> at 02:00 UTC, the file will be readable but incomplete. Standard S3 uploads don't expose an
> in-progress state to readers — the object will appear as a valid (but truncated) CSV. Is there a
> sentinel file, a row-count check, or a delivery receipt from the processor that confirms the file is
> complete before the job begins reading it? If not, the job could produce reconciliation results that
> are technically consistent but silently missing a tail of transactions."

**Finding 2 — Transaction scope (premise)**
> "Step 3 writes to three tables in sequence: it updates `orders.reconciliation_status`, inserts into
> `reconciliation_mismatches`, and inserts into `reconciliation_orphans`. I don't see a statement
> about whether these writes are wrapped in a single database transaction. If the job crashes between
> the first and second write — or between any two of the three — the resulting state would show some
> orders as 'matched' with no corresponding mismatch row, and vice versa. Is the three-table write
> intended to be atomic? If so, a note about the transaction boundary here would make that explicit
> for the implementation team."

**Finding 3 — Email relay not in dependencies (gap)**
> "The summary email in step 4 is the Finance team's only notification that the job ran. I don't see
> the email relay or SES listed in the dependencies section — is that intentional? If the email
> delivery fails silently, the job will mark itself SUCCEEDED in `reconciliation_runs` and Finance
> will have no indication the prior day's reconciliation is ready for review. It may be worth deciding
> whether email delivery failure should set the job to PARTIAL rather than SUCCEEDED, and whether the
> email relay should be listed as a dependency with its own failure-mode entry."

---

## Step 5: What the literal reading would have caught

A literal-reading critic — one who reads only what is on the page — would still have caught the
following problems without ghost-notes:

- **Missing status for the 'orphan' case:** Step 3c writes orphaned transactions to
  `reconciliation_orphans` but does not update `orders.reconciliation_status`. Is the status left
  as its previous value? Should it be `'orphaned'`? The spec's output table lists
  `reconciliation_orphans` rows but does not mention a status update.

- **Email content is unspecified:** Step 4 says "send a summary email with counts: matched,
  mismatched, orphaned" but does not specify what Finance is expected to do with that email, whether
  it includes links to the mismatch tables, or what the subject line looks like. For a Finance-SLA
  artifact, presentation matters.

- **`reconciliation_runs` schema is unspecified:** Step 5 marks the job complete in
  `reconciliation_runs` but the spec never defines the schema of that table or what "complete" vs.
  "FAILED" looks like in it. This is a straightforward gap visible on first read.

The literal reading catches omissions *within* the spec's stated scope. Ghost-notes catches the
assumptions that hold the spec's stated scope together.

---

## Why this matters

The findings that took down production systems in the payment-reconciliation class of jobs are almost
never the ones that appear on the failure-mode list. They are the ones that didn't make the list:
the silent partial ingestion that produced a reconciliation report that passed all automated checks
and was signed off by Finance before anyone noticed the tail was missing; the mid-job crash that left
the database in a state that subsequent runs treated as already-processed; the timezone mismatch that
caused a one-day lag that compounded for three weeks before the audit caught it. Abraham Wald's
insight applies directly: the spec shows you the failure modes the author thought of; the ghost-notes
scan is the practice of asking what the surviving spec is *not* showing you. The issues that make
production incidents are disproportionately absent from spec failure-mode lists — not because the
authors were careless, but because the assumptions that cause them felt too obvious to write down.
The ghost-notes heuristics systematically surface those assumptions before the spec ships.
