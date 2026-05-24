---
scenario_id: 02-missing-rollback
expected_severity: gap
expected_principle: ghost-notes
expected_finding: critic should surface the absence of a rollback or compensating-action path for the rename batch when a mid-run failure occurs
---
# SPEC: Bulk media file rename pipeline

## 1. Goal
Rename all user-uploaded media files stored in `/data/media/` to a new canonical format:
`{user_id}/{content_hash}.{ext}` replacing the legacy `{upload_timestamp}_{random}.{ext}` scheme.
This is a one-time migration run during a maintenance window, affecting ~4 million files.

## 2. Prerequisites
- Maintenance window confirmed (2h window, zero live writes during execution)
- Snapshot of `/data/media/` taken before run starts
- Migration script checked into `scripts/migrate-media-names.sh`

## 3. Steps

### Phase 1 — Build rename manifest
1. Walk `/data/media/` recursively.
2. For each file compute `content_hash` (SHA-256, truncated to 16 hex chars).
3. Emit a CSV manifest: `old_path,new_path,user_id` to `/tmp/rename-manifest.csv`.
4. Log total file count and estimated runtime to `/var/log/media-migrate.log`.

### Phase 2 — Execute renames
1. Stream the manifest CSV.
2. For each row:
   a. Create target directory `{user_id}/` if it does not exist.
   b. `mv old_path new_path`.
   c. Append `ok,{new_path}` to `/tmp/rename-progress.csv`.
3. When manifest is exhausted, log `DONE` with elapsed time.

### Phase 3 — Update database references
1. Connect to `mediadb` (Postgres).
2. For each row in manifest, `UPDATE media_assets SET file_path = new_path WHERE file_path = old_path`.
3. Commit in batches of 1000.

## 4. Failure modes
- Disk full during Phase 1 → script exits non-zero; manifest incomplete; no renames have run yet; safe to re-run.
- DB connection failure during Phase 3 → script exits; all files already renamed on disk but DB not updated. Operator must diff manifest against DB and re-run Phase 3 only.

## 5. Validation
After completion, run `scripts/validate-media-names.sh` to assert 0 files still matching legacy pattern.

## 6. Sign-off
Requires infrastructure lead approval before execution.
