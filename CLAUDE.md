# Sea Monster — Plugin Marketplace

This is the core product repo. Full system design is in [`seamonster`](https://github.com/seamonster-software/seamonster)'s `PROJECT.md`.

## Quick Context

Sea Monster is an autonomous AI crew that builds, ships, and markets software 24/7. This repo IS the product — a Claude Code plugin distributed via marketplace. Users install it with `claude plugin add seamonster-software/claude-plugins`.

### Repo Map

| Repo | Purpose |
|------|---------|
| [`seamonster`](https://github.com/seamonster-software/seamonster) | System design (PROJECT.md), docs, website |
| `claude-plugins` (this repo) | Core plugin — agents, skills, commands, hooks, lib, templates |

### Key Decisions

- **Distribution:** Free core in public marketplace, paid packs in private marketplace repos
- **Dual runtime:** Claude Code (interactive, Max subscription) + Pi/Ollama (autonomous, API key)
- **Bridge:** Coordination repo created by `/seamonster:init` — Captain's single point of contact
- **Platform:** GitHub only (issues, projects, actions, notifications)
- **Competitive position:** Sea Monster = business-focused 24/7 autonomy via git state machine

## Repo Structure

```
seamonster-software/claude-plugins/
├── .claude-plugin/marketplace.json     # Marketplace manifest
├── seamonster/                         # Core plugin
│   ├── .claude-plugin/plugin.json      # Plugin manifest
│   ├── agents/                         # 5 core agents (13 planned)
│   │   ├── orchestrator.md
│   │   ├── builder.md
│   │   ├── reviewer.md
│   │   ├── deployer.md
│   │   └── proposal-writer.md
│   ├── skills/                         # Domain knowledge
│   │   ├── github-workflow.md
│   │   ├── contract-patterns.md
│   │   └── escalation-protocol.md
│   ├── commands/                       # Slash commands
│   │   ├── init.md                     # /seamonster:init — creates bridge, onboards repos
│   │   ├── work.md                     # /seamonster:work — poll queue, dispatch agents
│   │   ├── crew-status.md
│   │   ├── spawn.md
│   │   ├── orders.md
│   │   └── voyage.md
│   ├── hooks/
│   │   └── hooks.json
│   ├── lib/                            # Shell helpers (copied into user repos by init)
│   │   ├── git-api.sh                  # Unified API — sources github-api.sh, provides sm_* functions
│   │   ├── github-api.sh              # GitHub backend (sourced by git-api.sh)
│   │   └── claude-runner.sh
│   └── templates/                      # Repo templates (copied by init)
│       ├── bridge/                     # Bridge repo template
│       │   ├── .github/workflows/
│       │   ├── .github/ISSUE_TEMPLATE/
│       │   └── CLAUDE.md
│       └── project/                    # Project repo template
│           ├── .github/workflows/
│           └── CLAUDE.md
```

## Conventions

- Shell scripts: `set -euo pipefail`, idempotent, color output
- Agent prompts use `source ./lib/git-api.sh` for git operations
- `git-api.sh` sources `github-api.sh` and provides `sm_*` wrapper functions
- Auth: `GITHUB_TOKEN` env var, or falls back to `gh auth token`
- All agent actions post comments on git issues (audit trail)
- Agents never stall silently — escalate via GitHub labels + notifications
- Reviewer is always read-only (no Edit/Write tools)
- Agent descriptions must include specific trigger patterns, not vague summaries
- Workflows use repo-relative paths (`./lib/`) — no SEAMONSTER_ROOT env var
- `/seamonster:init` uses `gh` CLI — no raw curl in commands
