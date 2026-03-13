# Changelog

All notable changes to the Sea Monster plugin will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- `README.md` — project overview, install instructions, tier descriptions, architecture
- `TODO.md` — tracked backlog (phase 2 remaining, agents, decisions, improvements)
- `git-api.sh` — unified platform-agnostic git API (`sm_*` functions)
  - Auto-detects Gitea vs GitHub from environment variables
  - Normalizes labels (always use names, Gitea ID resolution handled internally)
  - Auto-converts pagination params (`limit=` ↔ `per_page=`)
  - High-level functions: `sm_list_issues`, `sm_list_prs`, `sm_list_repos`
- GitHub Actions workflow templates for bridge and project repos
- `github-api.sh` lib script — GitHub REST API wrapper matching gitea-api.sh interface
- `github-workflow` skill — complete GitHub API reference for agents
- GitHub issue templates for bridge repos (mirroring Gitea templates)

### Changed
- `/seamonster:init` now uses `tea` CLI (Gitea) and `gh` CLI (GitHub) symmetrically — no raw curl
- `/seamonster:init` no longer mentions deployment tiers — detects platform and ntfy preference instead
- `/seamonster:init` confirms detected platform with user before proceeding
- `/seamonster:init` secrets step is conditional — skipped when no runner is configured
- All agents now source `git-api.sh` and use `sm_*` functions (platform-agnostic)
- All commands (crew-status, orders, voyage, spawn) consolidated from dual Gitea/GitHub examples to unified API
- Skills (contract-patterns, escalation-protocol) updated to use `sm_*` functions
- `claude-runner.sh` sources `git-api.sh` instead of platform-specific backends
- Bridge CLAUDE.md template updated with unified API documentation
- `/seamonster:init` uses platform-specific template directories for bridge/project setup
- Rewrote `/seamonster:init` command — full 11-step onboarding flow (platform detection, bridge creation, org scan, repo onboarding, secrets config)
- All lib paths changed from `/opt/seamonster/lib/` to `./lib/` (repo-relative)
- Deployer paths made configurable via env vars with Sovereign-tier defaults
- Session log hook uses `$CWD/.seamonster/logs/` instead of `/opt/seamonster/logs/`
- Renamed hub-repo to bridge across all templates and commands

### Fixed
- Stale `_hub` references in commands, skills, and templates

## [0.1.0] - 2026-03-11

### Added
- Initial marketplace plugin structure
- Core agents: Orchestrator, Builder, Reviewer, Deployer
- Skills: gitea-workflow, ntfy-notify, contract-patterns, escalation-protocol
- Commands: crew-status, spawn, orders, voyage, init
- Hooks: session-log
- Lib scripts: claude-runner.sh, gitea-api.sh, notify.sh
- Templates: bridge and project repo templates (Gitea Actions)
