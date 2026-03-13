# Sea Monster — Plugin Marketplace

This is the core product repo. Full system design is in [`seamonster`](https://github.com/seamonster-software/seamonster)'s `PROJECT.md`.

## Quick Context

Sea Monster is an autonomous AI crew that builds, ships, and markets software 24/7. This repo IS the product — a Claude Code plugin distributed via marketplace. Users install it with `claude plugin add seamonster-software/claude-plugins`.

### Repo Map

| Repo | Purpose |
|------|---------|
| [`seamonster`](https://github.com/seamonster-software/seamonster) | System design (PROJECT.md), docs, website |
| `claude-plugins` (this repo) | Core plugin — agents, skills, commands, hooks, lib, templates |
| [`typhon`](https://github.com/seamonster-software/typhon) | Sovereign-tier installer — Gitea + ntfy + Traefik + act_runner on Ubuntu |

### Key Decisions

- **Distribution:** Free core in public marketplace, paid packs in private marketplace repos
- **Deployment tiers:** Lite (GitHub + laptop), Solo (GitHub + VPS), Sovereign (Typhon)
- **Bridge:** Coordination repo created by `/seamonster:init` — Captain's single point of contact
- **Auth:** Claude Pro/Max subscription (not API keys)
- **Competitive position:** Sea Monster = business-focused 24/7 autonomy via git state machine

## Repo Structure

```
seamonster-software/claude-plugins/
├── .claude-plugin/marketplace.json     # Marketplace manifest
├── seamonster/                         # Core plugin
│   ├── .claude-plugin/plugin.json      # Plugin manifest
│   ├── agents/                         # 4 core agents (13 planned)
│   │   ├── orchestrator.md
│   │   ├── builder.md
│   │   ├── reviewer.md
│   │   └── deployer.md
│   ├── skills/                         # Domain knowledge
│   │   ├── gitea-workflow.md
│   │   ├── github-workflow.md
│   │   ├── ntfy-notify.md
│   │   ├── contract-patterns.md
│   │   └── escalation-protocol.md
│   ├── commands/                       # Slash commands
│   │   ├── init.md                     # /seamonster:init — creates bridge, onboards repos
│   │   ├── crew-status.md
│   │   ├── spawn.md
│   │   ├── orders.md
│   │   └── voyage.md
│   ├── hooks/
│   │   └── session-log.js
│   ├── lib/                            # Shell helpers (copied into user repos by init)
│   │   ├── git-api.sh                 # Unified API — agents source this, not platform-specific files
│   │   ├── claude-runner.sh
│   │   ├── gitea-api.sh               # Gitea backend (sourced by git-api.sh)
│   │   ├── github-api.sh              # GitHub backend (sourced by git-api.sh)
│   │   └── notify.sh
│   └── templates/                      # Repo templates (copied by init)
│       ├── bridge/                     # Bridge repo template
│       │   ├── .gitea/workflows/       # Gitea Actions (Sovereign tier)
│       │   ├── .gitea/ISSUE_TEMPLATE/
│       │   ├── .github/workflows/      # GitHub Actions (Lite/Solo tiers)
│       │   ├── .github/ISSUE_TEMPLATE/
│       │   └── CLAUDE.md
│       └── project/                    # Project repo template
│           ├── .gitea/workflows/
│           ├── .github/workflows/
│           ├── CLAUDE.md
│           └── README.md
```

## Conventions

- Shell scripts: `set -euo pipefail`, idempotent, color output
- Agent prompts use `source ./lib/git-api.sh` for platform-agnostic git operations
- `git-api.sh` auto-detects platform (GITEA_URL → Gitea, GITHUB_TOKEN → GitHub)
- All `sm_*` functions normalize platform differences (labels use names, pagination auto-converted)
- `gitea-api.sh` and `github-api.sh` are backends — agents/commands never source them directly
- Workflow templates remain platform-specific (`.gitea/workflows/` and `.github/workflows/`)
- All agent actions post comments on git issues (audit trail)
- Agents never stall silently — escalate via ntfy
- Reviewer is always read-only (no Edit/Write tools)
- Agent descriptions must include specific trigger patterns, not vague summaries
- Workflows use repo-relative paths (`./lib/`) — no SEAMONSTER_ROOT env var
- Templates exist for both Gitea Actions and GitHub Actions
