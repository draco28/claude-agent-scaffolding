#!/usr/bin/env bash
# scaffold-onboard/lib/docs.sh
#
# Governance doc derivation is AGENT-ONLY as of v0.8.0 (SS-7, #56). The
# deterministic template renderer (sf_docs_derive / _docs_args / _write_or_skip)
# was removed along with the `--fast` fallback: /scaffold-docs authors PRD / SRS /
# BACKLOG / PROJECT_PLAN / ADRs (+ the --full set, LLM-gated on 9.3.1) by
# dispatching synthesis sub-agents (scaffolding-governance-docs §11). The doc-set
# catalog + LLM-gate classification + per-doc routing now live in that skill body;
# manifest routing stays in lib/routing.sh and template substitution (for any
# surviving mechanical use) in lib/render.sh (sf_render).
#
# This file is intentionally function-free; it remains so the sf dispatcher's
# lib/*.sh source loop and any historical `source lib/docs.sh` stay valid.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"
