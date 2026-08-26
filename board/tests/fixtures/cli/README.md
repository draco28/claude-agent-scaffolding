# Recorded CLI shapes — pulse-labs, Huly 0.7.426, @firfi/huly-cli 0.48.2 (2026-08-26)

Every file here is the verbatim stdout of the named CLI command against the live
instance. These are the shapes the fake CLI's fixtures and the sync/setup readers
must model. Facts the spike pinned, keyed to the plan's §9 assumptions:

## Broken or absent tools (drive the workarounds)

- **`spaces types list` and `spaces types get` fail rc 70** ("Tool list_space_types
  produced invalid output") against this workspace. `space-types.list.ERROR.txt`
  holds the error document. **Existence gate replacement:**
  `task-types list --project-type "<name>"` → rc 0 = type exists; rc 1 with
  `INTEGRATION_FAILED` "did not resolve to exactly one project type" = absent.
- **No roles enumeration exists** (`spaces roles` has only create/members/permissions).
  Role presence is create-and-tolerate: duplicate `spaces roles create` → rc 5
  `CONFLICT` (existing role's permissions are NOT overwritten).
- **Typed project creation via CLI is impossible** (assumption 2 = `TYPED_CREATE=ui`):
  `spaces create "<type>" X` → rc 2 INVALID_INPUT ("use that module's purpose-built
  creation tool"); `projects create --input-json '{"type":…}'` silently ignores the
  type and creates a Classic project (verified via `spaces list`: type stayed
  `tracker:ids:ClassingProjectType`). Ossify-typed projects are created by hand in
  Tracker; the sync's bind path must not attempt CLI creation.

## One-time UI step is larger than the spec said

`task-types create` **copies** an existing task type and fails on an empty type
("has no task type to copy"), and `issue-statuses create` needs task types present.
So the one-time UI step is: create the space type **and seed its first task type
(`Spine`)**. After that the CLI drives everything: `task-types create "Work item"`
(copy), all four `issue-statuses create`, `spaces roles create`.

## Semantics

- `issue-statuses create <name> <category>`: categories are exactly
  `UnStarted | ToDo | Active | Won | Lost`; **idempotent** — repeat returns rc 0 with
  `"created": false`, never CONFLICT.
- `issues relations add`: **idempotent** — repeat returns rc 0 with `"added": false`
  (assumption 7: no CONFLICT branch needed).
- `spaces roles create <type> <name> <permissionsJSON>` requires **both** `--confirm`
  and `--yes`. `projects delete <id>` requires `--yes`.
- `milestones create <proj> <label> <ms-epoch>` accepts the ms-epoch date
  (assumption 5 holds). Milestone status vocabulary is lowercase
  (`planned`, `in-progress`, …) — matches map.jq.
- `projects create` identifier must match `^[A-Z][A-Z0-9_]{0,4}$` (max 5 chars).
  PTRD/PBASE/PHIVE/PDB/PGRD all comply; throwaway identifiers in tests/smoke must too.
- `--title-regex` is SQL **SIMILAR TO** (whole-title match, `%` wildcards), not a
  regex: `^r0\.s1 ` matches nothing. Use `--title-search "<key> "` (case-insensitive
  substring) or SIMILAR TO `"<key> %"`; client-side startswith filtering remains the
  correctness guard.
- Model-bootstrap warnings ("no document found, failed to apply model transaction")
  appear on **stderr** routinely; stdout stays clean JSON. The stdout/stderr split in
  `board_cli` is load-bearing.

## Shapes (differ from the plan's hand-written guesses)

- `task-types.list.json`: `{"taskTypes":[{id,name,projectTypeId,projectTypeName,kind,issueClass,statusCount}],"total":N}` — wrapper object, no per-type status names.
- `permissions.list.json`: `{"permissions":[{id,label,scope,objectClass,…}]}` — wrapper
  object; the role is built from exact `.id` values (the listing carries **no Read
  permission ids at all** — substring selection over `id`+`label` was measured to grant
  card/document/drive/training writes plus `core:permission:UpdateSpace`, and no reads).
- `spaces.list.json`: `{"spaces":[{id,name,class,type,private,archived,…}]}`.
- `milestones.list.json`: **bare array** `[{id,label,status,targetDate,modifiedOn}]`.
- `issues.list.json`: **bare array** `[{issueId,identifier,title,status:<string>,priority,creator,labels:[{title,color}],milestone:{id,label}|absent,modifiedOn}]` —
  status is a plain string; labels are objects keyed `title`; **no parent field**.
- `issues list` (and by the same mechanism, any list verb) may instead wrap the same array as
  `{"result":[…]}` — same flags, **data-dependent shape**: it happens when the result set
  contains an issue whose creator has no person record (an agent account created via the API
  that never web-logged-in). Readers must accept both (`.result? // .` — the `?` is
  load-bearing: plain `.result // .` hard-errors on the bare-array shape).
- `relations.list.json`: `{"blockedBy":[{identifier,_id,_class}],"blocks":[],"relations":[],"documents":[]}` —
  existence check reads `.blockedBy[]?.identifier`.
- `projects.statuses.json`: `{"statuses":[{name,category,isDefault}]}`.
- `projects.get.json`: `{identifier,name,archived,defaultStatus,statuses:[<names>]}`;
  missing project → rc 5, stderr `{"code":"NOT_FOUND",…}`.
- **No pagination anywhere** (measured on 0.48.2): every list verb takes `--limit N` only —
  no offset/page/cursor flag (`milestones list` defaults to 50). A listing whose length
  equals the requested limit is treated as possibly truncated and the sync refuses to
  reconcile rather than duplicate what it cannot see.
- Creates return small receipts: issues `{identifier,issueId}`, milestones
  `{id,label}`, mutations `{…,"updated"|"milestoneSet"|"labelAdded"|"added": true}`.
