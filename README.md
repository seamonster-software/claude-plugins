# Sea Monster — Autonomous AI Crew

A Claude Code plugin that gives you a crew of AI agents coordinating via git issues, PRs, and Actions. They build, review, deploy, and ship software — autonomously or on command.

## Install

```
claude plugin add seamonster-software/claude-plugins
```

## What You Get

**4 agents** (13 planned):
- **Orchestrator** — triages issues, delegates to crew, tracks progress
- **Builder** — picks up build tasks, writes code, opens PRs
- **Reviewer** — reviews PRs (read-only, never edits code)
- **Deployer** — handles releases, deployments, rollbacks

**5 skills:** gitea-workflow, github-workflow, ntfy-notify, contract-patterns, escalation-protocol

**5 commands:**
- `/seamonster:init` — onboard your org (creates bridge repo, scans projects, configures workflows)
- `/seamonster:crew-status` — see what the crew is working on
- `/seamonster:orders` — assign work to agents
- `/seamonster:spawn` — launch an agent on a task
- `/seamonster:voyage` — plan and execute a multi-step project

## Deployment Tiers

| Tier | Platform | Trigger | Autonomy |
|------|----------|---------|----------|
| **Lite** | GitHub or Gitea | You run commands | While you're in a session |
| **Solo** | GitHub + VPS | GitHub Actions | 24/7 |
| **Sovereign** | Gitea + VPS | Gitea Actions | 24/7, fully self-hosted |

**Lite** requires no infrastructure — just install the plugin and use the agents interactively.

**Solo** and **Sovereign** add a runner that triggers agents automatically on git events (new issues, PRs, labels). Install via [Typhon](https://github.com/seamonster-software/typhon).

## How It Works

1. `/seamonster:init` creates a **bridge** repo — the Captain's command center
2. Issues filed in the bridge get triaged by the Orchestrator and assigned to agents
3. Agents work via git: create branches, open PRs, post comments, request reviews
4. Everything is auditable — every action is a git comment
5. Agents escalate via [ntfy](https://ntfy.sh) when they need human input

## Architecture

```
bridge repo (coordination)          project repos (code)
  issues → Orchestrator               Builder → branches, PRs
  labels → trigger workflows          Reviewer → PR comments
  PRs    → Reviewer                   Deployer → releases
```

Agents use `lib/git-api.sh` — a platform-agnostic API that auto-detects Gitea vs GitHub and normalizes differences (labels, pagination, auth).

## Related Repos

| Repo | Purpose |
|------|---------|
| [seamonster](https://github.com/seamonster-software/seamonster) | System design, docs, website |
| [claude-plugins](https://github.com/seamonster-software/claude-plugins) | This repo — the plugin |
| [typhon](https://github.com/seamonster-software/typhon) | Solo/Sovereign installer (runner + optional Gitea + ntfy) |

## License

TBD
