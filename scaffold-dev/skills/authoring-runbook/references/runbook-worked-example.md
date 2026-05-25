# Runbook worked example — SRE-style template

The `authoring-runbook` skill produces an SRE-style runbook for an operational scenario (deployment, incident response, recurring maintenance, on-call procedure). This walks through one full runbook for a fictional scenario.

## Trigger and inputs

User invokes:

```
"write runbook for the daily insight pipeline failure recovery"
```

Skill body asks (1-3 quick clarifying questions if needed):
- What's the failure mode this runbook covers? (e.g., pipeline crashed, pipeline stalled, partial output)
- What's the recovery objective? (e.g., re-run successfully, escalate to engineer, mark day as data-incomplete)
- Who's the audience? (on-call engineer, primary maintainer, anyone with shell access)

## Output location

Default: `<canonical>/docs/runbooks/<slug>.md`. Slug derived from the topic — `daily-insight-pipeline-failure-recovery.md` for this example. Path is overridable via manifest if `canonical.runbooks_dir` exists.

## SRE-style template structure

The skill body uses an 8-section template:

1. Title + one-line description
2. When to use this runbook (triggering symptoms)
3. Pre-conditions (what you need before starting)
4. Procedure (numbered steps; each step is a verifiable action with expected output)
5. Decision points (branching: what to do if step N fails)
6. Escalation path (who to ping when self-service fails)
7. Verification of recovery (how to confirm the system is healthy again)
8. Post-incident notes (what to record; backlog items to file)

## Worked output

```markdown
# Daily insight pipeline failure recovery

Recover the daily insight pipeline when the overnight run has crashed or produced
partial output. Target audience: on-call engineer with shell access to the production
host and read access to the canonical repo.

## 1. When to use this runbook

Triggering symptoms (any one):
- `insight-pipeline-daily` cron job exited non-zero in the last 24h (visible in the
  ops dashboard "Cron failures" panel).
- The `insights.action_needed` table has zero rows for today's date even though prior
  days had non-zero rows.
- A user reports "the dashboard is showing yesterday's data."
- Alert: `pipeline-stale-data` PagerDuty alert fired.

If symptoms don't match this runbook, see `docs/runbooks/index.md` for the runbook catalog.

## 2. Pre-conditions

You have:
- SSH access to the production host (`prod-ops-01`).
- Read access to the canonical repo (clone at `~/work/insight-platform` or equivalent).
- Read access to the production database (`psql -h prod-db -U ops_readonly insights`).
- The `ops` CLI installed locally (`pip install -e .[ops]` from canonical repo).

If any of these are missing, escalate (see section 6) — do NOT attempt recovery without them.

## 3. Procedure

### Step 3.1 — Diagnose

```bash
ssh prod-ops-01
journalctl -u insight-pipeline-daily --since "24 hours ago" | tail -50
```

Expected: see the most recent run's stdout/stderr. Identify the failure point — typically
one of: (a) DB connection failure, (b) upstream API timeout, (c) transformation error,
(d) write conflict on `insights.action_needed`.

### Step 3.2 — Check upstream

```bash
ops upstream check
```

Expected: `all upstream sources OK`. If any source is RED -> the failure is upstream-driven;
this runbook does not cover upstream recovery. Escalate.

### Step 3.3 — Check DB state

```bash
psql -h prod-db -U ops_readonly insights -c "SELECT max(created_at), count(*) FROM action_needed WHERE created_at > now() - interval '48 hours';"
```

Expected for healthy: a row count > 0 with `max(created_at)` within the last 24h. If
zero rows or `max(created_at)` > 24h ago -> the table is stale; proceed to step 3.4.

### Step 3.4 — Replay the pipeline

```bash
ssh prod-ops-01
sudo -u pipeline-user /opt/insight-pipeline/bin/run-daily --date $(date -I) --force
```

Expected output: a series of progress messages ending with `pipeline complete: N rows written`.
If `N > 0` -> recovery is likely complete; proceed to step 3.5 (verification).

Runtime: typically 8-12 minutes. Allow up to 25 minutes before declaring stuck.

### Step 3.5 — Verify recovery

Re-run step 3.3. Expected: `max(created_at)` within the last few minutes; count > 0.

Spot-check via dashboard: navigate to `https://insights.example.com/admin/pipeline-health` ->
expected "Last pipeline run: <today's date>, <count> rows."

## 4. Decision points

- **Step 3.4 exits non-zero with `transformation error`:** capture the full stack trace
  from `journalctl -u insight-pipeline-daily --since "5 minutes ago"`; create a bug ticket
  with the trace; escalate (see section 6).

- **Step 3.4 runs > 25 minutes:** likely stuck on upstream. Cancel via `sudo systemctl
  stop insight-pipeline-daily`; verify upstream again; escalate if upstream is fine.

- **Step 3.4 succeeds but step 3.5 still shows stale data:** check whether a different
  date column was written; the pipeline may have run for the wrong date. Run with
  `--date <yesterday>` instead.

- **All steps succeed but user-facing dashboard still shows stale data:** likely a frontend
  cache; instruct user to hard-refresh OR clear the CDN cache via `ops cdn purge insights`.

## 5. Escalation path

Tier 1 (own this for 30 min): you, the on-call engineer.
Tier 2 (30-60 min): the platform team lead (`@platform-lead` in Slack `#oncall`).
Tier 3 (60+ min): the engineering manager (`@eng-mgr`).

Out-of-hours: PagerDuty escalation policy `insight-platform-p1` handles auto-page.

## 6. Verification of recovery

Recovery is complete when ALL of:
- Step 3.5 passes (DB shows fresh data).
- The PagerDuty alert `pipeline-stale-data` auto-resolves (or you resolve it manually).
- A spot-check of `https://insights.example.com/` shows action-needed cards rendering
  with today's data for at least one test user.
- The `insight-pipeline-daily` next scheduled run (typically 02:00 next day) is on
  schedule (verify via `systemctl list-timers insight-pipeline-daily.timer`).

## 7. Post-incident notes

After recovery, file:
- A backlog ticket for any root cause that caused the original failure (do NOT skip this
  even if recovery was fast — root-cause backlog is how we prevent next time).
- A note in the on-call log: time of failure, time of recovery, procedure followed,
  any deviations from this runbook (which inform runbook updates).
- If this runbook had to be deviated significantly: open a follow-up PR updating the
  runbook with the new procedure.
```

## Anti-patterns

- **Runbook as prose narrative.** Runbooks are NOT incident write-ups. They're imperative
  procedures. Use numbered steps, verifiable expected output, explicit decision points.
- **Missing pre-conditions.** A runbook that doesn't list the access/tooling pre-conditions
  forces the on-call to discover them at 2am. Always section 2.
- **Mixing diagnosis and recovery.** Diagnosis (step 3.1-3.3) and recovery (step 3.4) are
  separate phases. Diagnosis can be done without making any changes; recovery requires
  authority + caution. Keep them visually distinct.
- **No verification step.** "Run X" without "and confirm Y" leaves the on-call uncertain
  whether the fix landed. Always section 7 (or step 3.5 in the procedure).
- **Escalation without contact info.** "Escalate to platform team" with no Slack channel,
  phone number, or PagerDuty policy is useless at 2am. Be specific.

## When NOT to write a runbook

- **One-off operations.** A migration that runs once needs a deployment plan, not a runbook.
- **Pure code questions.** "How does the auth dependency work?" belongs in code comments
  + memory bank, not a runbook.
- **Decision rationale.** That's an ADR, not a runbook.

Runbooks earn their keep when an operation is RECURRING and the recurrence is in production
operations (deploys, on-call, scheduled maintenance, incident response).
