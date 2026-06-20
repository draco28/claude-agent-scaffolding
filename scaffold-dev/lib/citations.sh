#!/usr/bin/env bash
# scaffold-dev/lib/citations.sh
# Mechanical legs of verifying-spec-citations (#7). Semantic legs (REQ-ID denotes
# the same requirement? ARCH §-ref still points at the right content?) are the
# agent's — they are NOT in this file.

set -u

_SD_CIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_CIT_DIR/_helpers.sh"
fi

# sd_citations_check_file <path>
# Return 0 if the file exists, else 1 (logs a warning). Callers use exit status.
sd_citations_check_file() {
  local p="$1"
  if [[ -f "$p" ]]; then return 0; fi
  sd_log_warn "citation: file not found: $p"
  return 1
}

# sd_citations_check_signature <file> <signature>
# Return 0 if <file> contains the exact <signature> literal (grep -F — fixed string,
# no regex interpretation), else 1 (logs a warning). Catches paraphrase / parameter drift.
sd_citations_check_signature() {
  local file="$1" sig="$2"
  if [[ ! -f "$file" ]]; then
    sd_log_warn "citation: signature host missing: $file"
    return 1
  fi
  if grep -Fq -- "$sig" "$file"; then return 0; fi
  sd_log_warn "citation: signature not found verbatim in $file: $sig"
  return 1
}

# sd_citations_check_anchor <doc-file> <anchor>
# Part C (#48): mechanical doc-anchor resolution leg for lean-index pointers
# (`DOC §anchor`). Return 0 iff <doc-file> exists AND a Markdown heading
# (`^#{1,6} …`) resolves <anchor>: structured section/id tokens (`5.2`,
# `FR-5`, `NFR-10`) require token boundaries, while title fragments remain
# literal substring matches. Pass the token WITHOUT the `§` sigil; optional
# matching quotes around title anchors are ignored. Heading-only by design: a
# token that appears only in body prose does NOT resolve (it is not an anchor).
# Return 1 + warning otherwise. SEMANTIC drift — whether the heading still denotes
# what the citing memory entry claims — is the AGENT's leg, NOT in this file (same
# boundary as the ARCH §-ref leg in verifying-spec-citations §6.2).
_sd_citations_normalize_anchor() {
  local anchor="$1"
  if [[ ${#anchor} -ge 2 ]]; then
    local first="${anchor:0:1}" last="${anchor: -1}"
    if [[ "$first" == "$last" && ( "$first" == "\"" || "$first" == "'" ) ]]; then
      anchor="${anchor:1:$((${#anchor}-2))}"
    fi
  fi
  printf '%s' "$anchor"
}

_sd_citations_anchor_is_structured() {
  local anchor="$1"
  [[ "$anchor" =~ ^[0-9]+([.][0-9]+)*$ || "$anchor" =~ ^[A-Za-z][A-Za-z0-9_]*-[0-9]+([.][0-9]+)*$ ]]
}

_sd_citations_anchor_char_is_boundary() {
  local ch="$1"
  [[ -z "$ch" || ! "$ch" =~ [[:alnum:]_.-] ]]
}

_sd_citations_heading_has_structured_anchor() {
  local heading="$1" anchor="$2" rest="$1" prefix suffix before after
  while [[ "$rest" == *"$anchor"* ]]; do
    prefix="${rest%%"$anchor"*}"
    suffix="${rest#*"$anchor"}"
    before=""
    after="${suffix:0:1}"
    if [[ -n "$prefix" ]]; then before="${prefix: -1}"; fi
    if _sd_citations_anchor_char_is_boundary "$before" && _sd_citations_anchor_char_is_boundary "$after"; then
      return 0
    fi
    rest="$suffix"
  done
  return 1
}

_sd_citations_heading_matches_anchor() {
  local heading="$1" anchor="$2"
  if _sd_citations_anchor_is_structured "$anchor"; then
    _sd_citations_heading_has_structured_anchor "$heading" "$anchor"
  else
    [[ "$heading" == *"$anchor"* ]]
  fi
}

sd_citations_check_anchor() {
  local doc="$1" anchor="$2" heading
  if [[ ! -f "$doc" ]]; then
    sd_log_warn "citation: anchor host doc not found: $doc"
    return 1
  fi
  anchor="$(_sd_citations_normalize_anchor "$anchor")"
  if [[ -z "$anchor" ]]; then
    sd_log_warn "citation: malformed anchor token (empty) for doc: $doc"
    return 1
  fi
  while IFS= read -r heading || [[ -n "$heading" ]]; do
    if [[ "$heading" =~ ^#{1,6}[[:space:]] ]] && _sd_citations_heading_matches_anchor "$heading" "$anchor"; then
      return 0
    fi
  done < "$doc"
  sd_log_warn "citation: anchor not found in any heading of $doc: $anchor"
  return 1
}

# sd_citations_check_adr <adr-id> <adr-dir> [<adr-dir>...]
# Part D (#48): mechanical ADR-pointer resolution leg. Return 0 iff any <adr-dir>
# contains a file matching `adr-<NNNN>-*.md` or scaffold-onboard's seeded
# `<NNNN>-*.md` form for <adr-id>'s number, zero-padded to 4 (so `ADR-3`
# resolves `adr-0003-*.md` and `0003-*.md`); case of the cited id is irrelevant
# (the filename patterns are rebuilt lowercase/numeric). Return 1 + warning
# otherwise, including a malformed id carrying no digits. The CALLER resolves the
# product + process ADR dirs from the manifest (independent series → pass BOTH)
# so this leg stays manifest-free and fixture-testable.
sd_citations_check_adr() {
  local adr_id="$1"; shift
  local num padded d f
  if [[ "$adr_id" =~ ([0-9]+) ]]; then
    num="${BASH_REMATCH[1]}"
  else
    sd_log_warn "citation: malformed ADR id (no number): $adr_id"
    return 1
  fi
  padded="$(printf '%04d' "$((10#$num))")"
  for d in "$@"; do
    [[ -d "$d" ]] || continue
    for f in "$d"/adr-"$padded"-*.md "$d"/"$padded"-*.md; do
      [[ -f "$f" ]] && return 0
    done
  done
  sd_log_warn "citation: ADR $adr_id (adr-$padded-*.md or $padded-*.md) not found in: $*"
  return 1
}
