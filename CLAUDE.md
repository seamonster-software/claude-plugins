# Sea Monster — Plugin Marketplace

This is the core product repo. Full system design is in [`seamonster`](https://github.com/seamonster-software/seamonster)'s `PROJECT.md`.

## Quick Context

Sea Monster is an autonomous AI crew that builds, ships, and markets software autonomously. This repo IS the product — a Claude Code plugin distributed via marketplace. Users install it with `claude plugin add seamonster-software/claude-plugins`. The plugin namespace is `x` — commands are `/x:init`, `/x:work`, `/x:spawn`, etc.

### Repo Map

| Repo | Purpose |
|------|---------|
| [`seamonster`](https://github.com/seamonster-software/seamonster) | System design (PROJECT.md), docs, website |
| `claude-plugins` (this repo) | Core plugin — agents, skills, commands, hooks |

### Key Decisions

- **Distribution:** Free core in public marketplace, paid packs in private marketplace repos
- **Dual runtime:** Claude Code (interactive, Max subscription) + Pi/Ollama (autonomous, API key)
- **Plugin namespace:** `x` — commands are `/x:init`, `/x:work`, `/x:spawn`, `/x:order`, `/x:voyage`
- **Bridge:** Coordination via file-based state machine in `.bridge/orders/`
- **Platform:** Git (any host) — file-based state machine, not GitHub-specific
- **Notifications:** ntfy (bidirectional — file orders, receive status, respond to blockers from phone)
- **Competitive position:** Sea Monster = business-focused 24/7 autonomy via git state machine

## Repo Structure

```
seamonster-software/claude-plugins/
├── .claude-plugin/marketplace.json     # Marketplace manifest
├── x/                                  # Core plugin (namespace: x)
│   ├── .claude-plugin/plugin.json      # Plugin manifest
│   ├── agents/                         # 13 core agents
│   │   ├── orchestrator.md
│   │   ├── builder.md
│   │   ├── reviewer.md
│   │   ├── deployer.md
│   │   ├── scout.md
│   │   ├── analyst.md
│   │   ├── proposal-writer.md
│   │   ├── architect.md
│   │   ├── planner.md
│   │   ├── sysadmin.md
│   │   ├── qa.md
│   │   ├── security.md
│   │   └── monitor.md
│   ├── skills/                         # Domain knowledge
│   │   ├── contract-patterns.md
│   │   └── escalation-protocol.md
│   ├── commands/                       # Slash commands
│   │   ├── init.md                     # /x:init — creates bridge, onboards repos
│   │   ├── work.md                     # /x:work — poll queue, dispatch agents
│   │   ├── spawn.md
│   │   ├── order.md
│   │   └── voyage.md
│   └── hooks/
│       └── hooks.json
```

## Conventions

- Shell scripts: `set -euo pipefail`, idempotent, color output
- Agents read/write `.bridge/orders/*.md` files — no GitHub API calls for coordination
- Order files use YAML frontmatter for status, assignee, priority; markdown body for spec and log
- Audit trail: agents append to `## Work Log` section in the order file, not GitHub comments
- Escalation: agents write `## Blocker` section, set `status: needs-input`, send ntfy notification
- Reviewer is always read-only (no Edit/Write tools) but merges approved PRs and runs `semantic-release`
- Agent descriptions must include specific trigger patterns, not vague summaries
- Plugin typeahead requires auto-discovery — no `name` field in command frontmatter, no component arrays in plugin.json
- Agent frontmatter SHOULD have `name` field; command frontmatter should NOT (agents use name for display, commands use filename)
- When dispatching multiple builders to same repo, use `isolation: "worktree"` to avoid branch collisions
- GitHub blocks formal review approvals on own PRs — reviews post as comments instead
- PRs don't auto-close issues — use "Closes #N" in PR body, or close manually after merge
