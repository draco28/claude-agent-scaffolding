# Changelog

All notable changes to the scaffold plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — Phase A: plugin scaffold (2026-04-26)
- File tree at `scaffold/` with valid manifests, command stubs, library stubs, MCP skeleton, templates, and install script skeleton. Plugin loads in Claude Code without errors. No functional behavior yet — subsequent phases (B–J) implement capabilities.

## [0.1.0] — planned

Initial release target. Phases A–J build sequence:

- **A:** plugin scaffold *(this release)*
- **B:** state, repo-detection, CLAUDE.md generator libraries + tests
- **C:** init / audit / status / claude-md-edit / claude-md-rebuild commands (Capabilities 1, 4)
- **D:** slice workflow with phase gates (Capability 2)
- **E:** governance commands — adr-new / changelog / runbook-new (Capability 3)
- **F:** Python MCP server with semantic memory (sqlite + sqlite-vec + Ollama)
- **G:** worktree fork / list commands
- **H:** SessionStart hook (source-aware project context)
- **I:** E2E smoke test on real repos
- **J:** v1.0.0 ship — bump version, register in marketplace, push
