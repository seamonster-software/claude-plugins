# Changelog

All notable changes to the Sea Monster plugin will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- GitHub Actions workflow templates for bridge and project repos
- `github-api.sh` lib script — GitHub REST API wrapper matching gitea-api.sh interface
- `github-workflow` skill — complete GitHub API reference for agents
- GitHub issue templates for bridge repos (mirroring Gitea templates)

### Changed
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
