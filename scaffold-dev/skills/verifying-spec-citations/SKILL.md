---
name: verifying-spec-citations
description: Verify that the citations in a draft vertical-slice spec resolve — file paths and quoted function signatures via deterministic checks, REQ-ID and ARCH §-ref denotation via agent judgment. Use this when the user wants to verify spec citations, check a draft spec for citation drift, asks "do the REQ-IDs / file paths / signatures in this spec still resolve?", or before locking a slice spec. Read-only — never edits the spec. Manifest-routed. Skill-only invocation; no dedicated slash command.
---

# verifying-spec-citations

You are scaffold-dev's spec-citation verifier. The user has a draft vertical-slice spec — authored by `planning-vertical-slice` or edited by hand — and wants to confirm that every citation in it still resolves. You run mechanical checks on file paths and quoted function signatures, then apply agent judgment to REQ-IDs and ARCH §-refs where denotation drift can't be detected by `grep`. You are read-only; you report drift, you never edit the spec.

Two legs power this skill: the mechanical leg (`lib/citations.sh` — deterministic `test -f` and `grep -F`) and the agent leg (you, reading the spec against live docs to judge whether a REQ-ID still names the same requirement and whether an ARCH §-ref still points at the right section content). Neither leg substitutes for the other.

---

## 1. Overview

When invoked, you:

1. **Locate** the draft spec path(s) — either the canonical `<ai-workspace>/docs/specs/sprint-N/VS-N.M.K-*/work-N.NN-*/spec.md` location or any path the user names.
2. **Read** the spec with the Read tool; extract the four citation classes (§4).
3. **Run mechanical checks** for file paths and quoted signatures via `lib/citations.sh` (§5).
4. **Apply agent judgment** for REQ-IDs and ARCH §-refs (§6).
5. **Degrade gracefully** when the project has no REQ-ID or ARCH scheme (§7).
6. **Emit one drift report** (§8) with `file:line` precision per finding, then stop.

Validation is read-only. No writes, no auto-fixes, no spec edits — ever.

---

## 2. Mechanical/agent split

| Citation class | How verified | Authority |
|---|---|---|
| File paths (Markdown prose, lists, and code blocks) | `sd_citations_check_file` — manifest-routed `test -f` | mechanical |
| Quoted function signatures | `sd_citations_check_signature` — `grep -F` exact match | mechanical |
| REQ-IDs (e.g. `REQ-OTP-7`) | Agent judges whether the ID still denotes the SAME requirement after renumber | agent |
| ARCH §-refs (e.g. `ARCHITECTURE.md §3`) | Agent judges whether the cited section title/content still matches after rename | agent |

The principle is: **mechanical for facts that a bash test can settle unambiguously; agent for semantics that require reading and comparing prose**. Never use mechanical checks as proxies for semantic judgment (a file can exist while its content is entirely different) and never use agent judgment where a `test -f` is sufficient.

---

## 3. Inputs

The spec path(s) to check. Two resolution patterns:

**Pattern A — canonical location** (after `planning-vertical-slice` has scaffolded the slice):

```
<ai-workspace>/docs/specs/sprint-<sprint_id>/VS-N.M.K-<kebab>/work-N.NN-<kebab>/spec.md
```

Resolve `<ai-workspace>` from the manifest via `sd manifest_get '.ai_workspace.root'`. Use glob to locate the VS directory when the exact kebab is unknown (same glob pattern as `implementation-checking` §3.4).

**Pattern B — user-named path:** use the path the user provides verbatim; resolve it relative to `pwd` if not absolute.

When neither pattern yields a readable file, surface:

> Spec not found at `<resolved-path>`. Has `planning-vertical-slice` authored this slice yet, or did you mean a different path?

Then stop. Do NOT create or stub the spec file.

Read the resolved spec with the Read tool before any extraction step.

---

## 4. Extraction — finding each citation class

After reading the spec text, extract citations as follows:

**File paths** — any path token appearing in Markdown prose, list items, inline code, fenced code blocks (` ``` `), or indented blocks. Most work-item specs cite files in sections like `Files to modify`, `Reference index`, or AC prose; do not restrict extraction to code blocks. Patterns to match:

- Absolute paths: `/` prefix
- Relative paths from canonical or ai-workspace root: paths containing `/` that do not start with `http`
- Commonly cited: `src/`, `lib/`, `tests/`, `docs/`, `scripts/` subtrees

Collect each distinct path token and the line number where it appears.

**Quoted function signatures** — any token matching one of these shapes inside or adjacent to a code fence:

- `function_name(` — bare invocation shape
- `sd_<name>`, `sf_<name>` — scaffold plugin function names
- Any quoted literal the spec calls out as "signature", "function", or "method"

Collect `(path-to-host-file, exact-signature-string, line-number)` triples. The host file is the file the spec asserts this signature lives in (usually cited in the same sentence or fence).

**REQ-IDs** — tokens matching a configurable pattern. The default regex is:

```
[A-Z]{2,8}-[A-Z]{1,4}-[0-9]+
```

(e.g. `REQ-OTP-7`, `FR-AUTH-12`). If the project's `MASTER-SPEC.md` or memory bank defines a different REQ-ID scheme, use that pattern. Collect `(req_id, line_number)` pairs.

**ARCH §-refs** — tokens of the form `<DOC-NAME>.md §<N>` or `<DOC-NAME>.md §<section-title>` (e.g. `ARCHITECTURE.md §3`, `ARCHITECTURE.md §Authentication`). Collect `(doc_path, section_ref, cited_title_if_given, line_number)` tuples. The cited title is any quoted text the spec places after the §-ref (e.g., `ARCHITECTURE.md §3 "Token Lifecycle"` — the quoted title is what you'll compare against the live heading in §6).

---

## 5. Mechanical run

Source both libs via the `sd` dispatcher (bash shebang on the dispatcher forces a bash runtime, which is required because Claude Code's Bash tool runs zsh on macOS by default):

```bash
canonical="$(sd manifest_get '.canonical.root')"
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
```

For each extracted **file path**, resolve it against the manifest. Absolute paths are checked verbatim. Relative paths use deterministic prefix routing first: `docs/` routes to the ai_workspace root; `src/`, `lib/`, `tests/`, and `scripts/` route to the canonical root. If no prefix rule applies, probe both roots. When both roots contain a file at the same relative path, do not silently choose one: if the files differ, emit an ambiguity finding; if they are byte-identical, either path is acceptable but report the resolved path you checked.

```bash
# Example: check a cited file path
if [[ "$cited_path" = /* ]]; then
  sd citations_check_file "$cited_path"
elif [[ "$cited_path" == docs/* ]]; then
  sd citations_check_file "${ai_workspace}/${cited_path}"
elif [[ "$cited_path" == src/* || "$cited_path" == lib/* || "$cited_path" == tests/* || "$cited_path" == scripts/* ]]; then
  sd citations_check_file "${canonical}/${cited_path}"
else
  canonical_path="${canonical}/${cited_path}"
  workspace_path="${ai_workspace}/${cited_path}"
  if [[ -f "$canonical_path" && -f "$workspace_path" ]]; then
    if cmp -s "$canonical_path" "$workspace_path"; then
      sd citations_check_file "$canonical_path"
    else
      echo "[file-path ambiguity] ${cited_path} exists under both canonical and ai_workspace with different contents"
    fi
  elif [[ -f "$canonical_path" ]]; then
    sd citations_check_file "$canonical_path"
  else
    sd citations_check_file "$workspace_path"
  fi
fi
```

`sd_citations_check_file` returns 0 if the file exists, 1 and logs a warning if not.

For each extracted **quoted signature** `(host_file, sig, line)`:

```bash
resolved_host="${canonical}/${host_file}"   # or ai_workspace root per above
sd citations_check_signature "$resolved_host" "$sig"
```

`sd_citations_check_signature` runs `grep -F` for the exact literal string — catches paraphrase drift and parameter-list changes. Returns 0 on match, 1 on miss.

Collect all failing `(citation, resolved_path, line_number)` pairs; they become `[file-path]` and `[signature]` findings in the drift report (§8).

---

## 6. Agent judgment — REQ-IDs and ARCH §-refs

This section is the semantic core the skill's design assigns to the agent. Mechanical checks cannot detect denotation drift: an ID can resolve syntactically while pointing at an entirely different requirement after a renumber, and a section can still exist under the same number while having been renamed or repurposed.

### 6.1 REQ-ID denotation

For each collected REQ-ID:

1. **Locate the requirements source** — read the project's requirements doc (typically `MASTER-SPEC.md` Phase 3 / FR section, or the memory bank's `01-project-brief.md`). Use Read or Grep to find the block carrying that ID.
2. **Check existence:** if the ID is absent from the requirements doc entirely, record a `[req-id]` finding: the ID is dangling.
3. **Check denotation:** read the requirement text the ID currently labels. Compare it to the context in which the spec cites the ID (the sentence or AC the spec wrote around it). Ask: does the live requirement still match the spec's intent? Common drift patterns:
   - The project renumbered requirements (`REQ-OTP-7` became `REQ-OTP-9` and the old `REQ-OTP-7` slot now carries a different requirement).
   - The requirement was split: `REQ-AUTH-3` now covers only half of what the spec assumed.
   - The requirement was deleted and its ID retired.

Record a `[req-id]` finding when the live requirement's text no longer matches the spec's evident assumption about what that ID means. Quote both the live text and the spec's usage so the user can judge without re-searching.

### 6.2 ARCH §-ref denotation

For each collected ARCH §-ref `(doc_path, section_ref, cited_title, line)`:

1. **Locate the architecture doc** — resolve `doc_path` via the canonical root; read it with the Read tool.
2. **Check existence of the section:** search for heading `## <N>` or `## <section-title>` (whichever the ref uses). You may mechanize this existence probe via dispatcher command `sd citations_check_anchor "<doc_path>" "<section_ref>"` — it returns 0 iff a heading resolves the ref token (structured tokens are boundary-aware; title fragments are literal; you still judge denotation in step 3). If absent, record a `[arch-ref]` finding: section not found.
3. **Check denotation:** read the live section heading. If the spec cited a quoted title (e.g., `§3 "Token Lifecycle"`), compare the quoted title to the live heading text. If they differ, record a `[arch-ref]` finding: title mismatch (the section may have been renamed or its scope changed).
4. **Spot-check content relevance:** skim the first paragraph of the live section. If the content is clearly unrelated to the spec's usage context (e.g., the spec cites `§3 "Token Lifecycle"` for authentication logic, but the live `§3` now covers database schema), record a `[arch-ref]` finding: content mismatch.

Quote the live heading and the cited title side-by-side in the finding so the user can assess without re-reading the arch doc.

---

## 7. Graceful degradation — no REQ-ID or ARCH scheme

Some projects have no REQ-ID scheme (no `REQ-` prefixes in MASTER-SPEC, no FR section with IDs) or no ARCHITECTURE.md. In those cases:

1. **Run the mechanical legs (§5) regardless** — file-path and signature checks always apply.
2. **Skip the agent judgment legs (§6)** for the missing class.
3. **Note the skip in the report** with this advisory (adapt for whichever class was absent):

> Advisory: no REQ-ID scheme detected in this project — REQ-ID denotation judgment was skipped. If the project uses requirement IDs, ensure they are defined in `MASTER-SPEC.md` or the memory bank so this check can run.

> Advisory: `ARCHITECTURE.md` not found at `<resolved-path>` — ARCH §-ref denotation judgment was skipped.

Never fail the run for absence of a scheme. Mechanical checks may still surface findings; the report is still authoritative for what it covers.

---

## 8. Report format

Emit **one authoritative drift report** after all checks complete. Use `file:line` notation for every finding so the user can locate and fix without re-grepping the spec.

### 8.1 Clean report (no drift)

> Citation check: all N citations resolve.
>
> - File paths checked: M (all present)
> - Signatures checked: K (all match verbatim)
> - REQ-IDs checked: J (all denote the same requirement)
> - ARCH §-refs checked: L (all titles + content match)
>
> Spec is citation-clean.

### 8.2 Drift report (findings present)

Tag each finding by class using square-bracket source tags. The tags are `[file-path]`, `[signature]`, `[req-id]`, and `[arch-ref]`.

Example with two drift findings — one missing file path and one REQ-ID drift:

> Citation drift detected: 2 finding(s).
>
> **[file-path]** `spec.md:47` — `src/auth/token_store.py` not found at `<canonical>/src/auth/token_store.py`. The file may have been moved or renamed. Check `git log --follow` or search for the new path.
>
> **[req-id]** `spec.md:83` — `REQ-AUTH-3` now reads: *"The system shall enforce a 15-minute session idle timeout."* But the spec uses it to assert multi-factor authentication behaviour. This ID likely pointed at a different requirement before the most recent renumber; verify against the current FR list and update the citation.
>
> Spec has 2 open citation(s). Fix and re-run to confirm clean.

Surface ALL findings in one pass (do not halt on first finding the way `implementation-checking` halts on first AC fail — the user needs the full picture to decide how many changes are needed before re-running).

---

## 9. Read-only guarantee

This skill NEVER edits, patches, or auto-fixes the spec. It NEVER:

- Writes to `spec.md`, `report.md`, `handoff.md`, or any other file.
- Rewrites a citation inline (e.g., updating `REQ-OTP-7` → `REQ-OTP-9` in-place).
- Resolves ambiguous paths by picking one silently and proceeding.
- Suppresses a finding because a fix seems obvious.

You surface; the user fixes. After fixing, the user re-runs this skill to confirm clean. This matches the contract of `validating-master-spec` and `implementation-checking`: read-only gates surface errors with precise location info; the edit decision belongs to the user.

---

## 10. When to use / not

**Trigger phrases (description-match):**

- "verify spec citations", "check citations in the spec", "do the citations in this spec resolve?"
- "citation drift check", "check for citation drift"
- "do the REQ-IDs / file paths / signatures in this spec still resolve?"
- "before locking the spec", "pre-lock citation check"

**Invoke before:**

- Locking a slice spec for implementer-agent dispatch (between `planning-vertical-slice` gate 2 and architect-critic in §7 of that skill).
- Re-checking a spec after a renumber or architecture rename has landed.
- Reviewing any manually-edited spec where citations may have gone stale.

**Do NOT invoke when:**

- The user wants to *verify work-item ACs* — that is `implementation-checking`.
- The user wants to *validate MASTER-SPEC structure* — that is `scaffold-onboard:validating-master-spec`.
- The spec does not yet exist — route the user to `planning-vertical-slice` or the authoring step first.
- The user wants to *fix* the spec — this skill surfaces; the user edits; then re-run.

---

## 11. Bash bookkeeping helpers

This skill never bash-orchestrates judgment work (REQ-ID denotation, ARCH §-ref title comparison, whether a path-miss is a rename vs. deletion). It calls helpers for mechanical I/O only.

**Citations (`scaffold-dev/lib/citations.sh`):** `sd_citations_check_file <resolved-path>` — returns 0 if file exists, 1 with warning if not; `sd_citations_check_signature <resolved-file> <exact-sig>` — returns 0 if `grep -F` finds the literal string, 1 with warning if not. Two further legs (added for the #48 lean-index pointer channels, reused here as mechanical pre-checks for the §6 agent legs): `sd_citations_check_anchor <doc-file> <anchor>` — returns 0 if a Markdown heading in `<doc-file>` resolves the anchor (boundary-aware section/id tokens, literal title fragments, optional matching quote stripping), 1 with warning if not; `sd_citations_check_adr <adr-id> <adr-dir>...` — returns 0 if any dir holds `adr-<NNNN>-*.md` or scaffold-onboard's seeded `<NNNN>-*.md` form for the id's number (zero-pad-tolerant), 1 if not. In skill prose, invoke them through the dispatcher as `sd citations_check_anchor ...` / `sd citations_check_adr ...`.

**Manifest (`scaffold-dev/lib/manifest.sh`):** `sd_manifest_get '.canonical.root'`, `sd_manifest_get '.ai_workspace.root'` — resolve the two repo roots for manifest-routed path checks. `sd_manifest_require` for pre-flight (refuse fail-fast if manifest absent, same pattern as `implementation-checking` §3.1).

**Read tool:** used for all spec reads, requirements doc reads, and ARCHITECTURE.md reads — never `cat`. Grep tool used for REQ-ID and heading searches.

macOS-portable patterns required for any inline bash (BSD grep, bash 3.2 via dispatcher).

---

## 12. Anti-patterns (do not do these)

- **Editing the spec.** This skill is read-only. Not even a "trivial" path fix. Surface the finding; the user edits.
- **Halting on first finding.** Unlike AC verification, citation checking surfaces ALL findings in one pass so the user can assess the full repair scope.
- **Skipping mechanical checks when the agent judgment legs are absent.** File-path and signature checks run regardless of whether the project has a REQ scheme or ARCHITECTURE.md.
- **Hardcoding `$(pwd)` for path resolution.** Always route file paths through the manifest (`sd_manifest_get '.canonical.root'` / `'.ai_workspace.root'`). Single-repo users will have identical roots, but dual-repo users won't.
- **Using regex for `grep` in `sd_citations_check_signature`.** The function uses `grep -F` (fixed string) — no regex interpretation. The caller must pass the exact literal signature, not a pattern.
- **Inventing a "pass" when the REQ-ID scheme is absent.** When no scheme is detected, skip and note the skip — do NOT silently declare all REQ-IDs resolved.
- **Paraphrasing source-tag tokens.** The literal tags `[file-path]`, `[signature]`, `[req-id]`, `[arch-ref]` are the class identifiers. Do not substitute `(file-path)`, `**file-path**`, or `[filepath]`.
- **Invoking architect-critic from this skill.** Citation verification is not an architect-critic moment. Surface findings; stop.

---

## 13. Notes on tool boundaries

You (Claude reading this skill body) make every judgment call: whether a REQ-ID has drifted in denotation, whether an ARCH §-ref title still matches, how to phrase the `[req-id]` finding to make the drift legible, which root to try first for an ambiguous path.

Bash helpers (`lib/citations.sh`, `lib/manifest.sh`) handle pure mechanics: file existence, verbatim signature presence, manifest field reads.

The user is the editor — this skill never writes to `spec.md` or any other file. On any finding: surface with `file:line` precision, advise, stop. The user fixes and optionally re-runs.
