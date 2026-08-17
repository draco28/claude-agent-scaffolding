---
scenario_id: 04-spec-with-no-gaps
expected_severity: alternative
expected_principle: n/a
expected_finding: negative control — the spec is complete; the ideal output is alternative-severity observations only (e.g. the caching/ETag choice) closing with the K=0 "0 challenges stood — recap is solid" line. Honest curiosity-framed premise/gap questions anchored to real spec text are tolerable candidates (the rebuttal cycle exists to filter them); fabricated or asserted-as-defect findings are the failure this control exists to catch
---
# SPEC: GET /users/:id — fetch user profile (read-only)

## 1. Goal
Return a single user's public profile data. No mutations. Used by the mobile client and
partner API consumers.

## 2. Request contract
```
GET /users/:id
Authorization: Bearer <token>
```
- `:id` is a UUID v4.
- Caller must be authenticated; no public access. Authentication is the whole
  authorization story for this endpoint: the profile is public-data-only, any
  valid JWT may read any user, nothing is caller-scoped, and there is no 403
  path by design.

## 3. Response contract
```json
{
  "id": "uuid",
  "display_name": "string",
  "avatar_url": "string | null",
  "created_at": "ISO-8601 timestamp",
  "public_bio": "string | null"
}
```
No PII (email, phone) included in response. Fields are stable; additive changes require
a new minor API version.

## 4. Steps
1. Validate JWT (signature, expiry, audience); extract `caller_id`.
2. Parse and validate `:id` as UUID v4; return 400 if malformed.
3. `SELECT id, display_name, avatar_url, created_at, public_bio FROM users WHERE id = $1`.
4. If no row: return 404 `{"error": "user_not_found"}`.
5. Return 200 with response body above.

## 5. Failure modes
- **Malformed ID** (not UUID v4) → 400 `{"error": "invalid_id"}`.
- **User not found** → 404 `{"error": "user_not_found"}`.
- **Expired / invalid JWT** → 401 `{"error": "unauthorized"}` (handled by auth middleware before handler runs).
- **Database unavailable** → 503 `{"error": "service_unavailable"}`; the global error handler catches
  uncaught DB exceptions and returns 503 with no stack trace in the body.
- **Deleted or suspended user** → rows are hard-deleted at this tier (no soft-delete
  or account-lifecycle states exist in this table); a deleted user returns the same
  404 `user_not_found` as a never-existed one.

## 6. Invariants
- Handler is idempotent and side-effect-free; safe to retry.
- Response shape is identical regardless of caller identity (no caller-scoped field filtering).
- `avatar_url` is always an absolute HTTPS URL or null; never a relative path.

## 7. Performance expectations
- p99 latency target: <50ms (DB query is indexed on PK; no joins).
- The DB call carries a 2s timeout; a timeout surfaces as 503 through the global
  error handler in §5 (no telemetry, partial-response, or slow-path exists).
- No caching layer at this tier; upstream API gateway applies a 5s CDN cache for
  anonymous-equivalent reads (not applicable here since auth is required).

## 8. Out of scope
- Editing profile fields (separate PATCH /users/:id spec).
- Listing users or searching by name.
- Rate limiting (handled at gateway layer, outside this spec).
