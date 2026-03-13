# Sea Monster Bridge — Coordination Repo

This is the **bridge** — the Captain's command center. All cross-project orchestration, proposals, and crew coordination flows through here.

## The Crew

| Agent | When to Invoke |
|---|---|
| **Orchestrator** | Routing tasks, triaging, checking status, delegating |
| **Sysadmin** | Infrastructure maintenance, tool installation, system health |
| **Scout** | Scanning for opportunities, market research |
| **Analyst** | Evaluating viability, competitive analysis |
| **Proposal Writer** | Structuring proposals as issues |
| **Architect** | System design, stack selection, architecture decisions |
| **Planner** | Roadmaps, milestones, phased execution plans |
| **Builder** | Writing code, building features, fixing bugs |
| **Reviewer** | Code review (read-only), PR validation |
| **QA** | Testing, load testing, verification |
| **Deployer** | Deployment, routing, services |
| **Security** | Hardening, vulnerability scanning, secrets |
| **Monitor** | Uptime monitoring, log analysis, alerting |

## Issue State Machine

Labels drive the workflow. Adding a label triggers a workflow that spawns the appropriate agent.

```
[proposal] ──Captain approves──► [approved] ──► [planning]
                                                    │
                                            Architect + Planner
                                                    │
                                                    ▼
                                          [build-ready] ──► Builder builds
                                                                  │
                                                           Reviewer reviews PR
                                                                  │
                                                          [deploy-ready] ──► Deployer deploys
                                                                                    │
                                                                                 [live]
```

### State Transition Labels

| Label | Triggers | What Happens |
|---|---|---|
| `approved` | `on-approved.yml` | Architect designs, Planner plans |
| `build-ready` | `on-build-ready.yml` | Builder builds on issue branch, opens PR |
| `needs-input` | `on-needs-input.yml` | GitHub notification to Captain |
| `deploy-ready` | `on-deploy-ready.yml` | Deployer deploys to production |
| `incident` | `on-incident.yml` | Post-mortem analysis |

### Scoped Labels

```
team/scout       team/build       team/ops         team/growth
priority/p0      priority/p1      priority/p2
size/small       size/medium      size/large
status/blocked   status/waiting   status/active
type/proposal    type/feature     type/bug         type/deploy
```

## PR Workflow

Every build follows: **Issue --> Branch --> Build --> PR --> Review --> Merge --> Deploy**

1. Issue labeled `build-ready` triggers the Builder
2. Builder creates branch `issue-{number}`, builds, opens PR
3. PR triggers the Reviewer for read-only code review
4. Reviewer approves or requests changes
5. On merge, Deployer deploys the changes

## Conventions

### Commits

Use conventional commits referencing the issue number:

```
feat(auth): add JWT token generation (#47)
fix(api): handle empty response body (#52)
refactor(db): extract connection pooling (#55)
```

### Agent Comments

Every agent action posts a comment on the relevant issue. Format:

```
**{Agent}** — {action summary}

{details}
```

### Branching

- `main` — always deployable
- `issue-{number}` — work branches, one per issue
- Never commit directly to main

### PR Format

```
## Summary
Implements #{issue_number}.

## Changes
- [list of changes]

## Testing
- [how to verify]

## Checklist
- [ ] Tests pass
- [ ] No hardcoded secrets
- [ ] Follows project conventions
```

## Rules

1. **Agents post comments on issues** — the issue timeline is the audit trail. If it is not in git, it did not happen.
2. **Never stall silently** — if blocked, escalate immediately. Add `needs-input` and `status/blocked` labels, then move to other work.
3. **Escalate with options** — always present 2-3 options with trade-offs and a recommendation. Never ask open-ended questions.
4. **Read-only reviewers** — the Reviewer never modifies code. Report, never fix.
5. **No secrets in code** — use environment variables. Never commit credentials, tokens, or API keys.
6. **Reference the issue** — every commit, every PR, every comment links back to the issue.
7. **Delegate, don't hoard** — the Orchestrator never does implementation. Agents stick to their role.

## Environment Variables

Available to all workflows and agents via repository secrets:

| Variable | Description |
|---|---|
| `GITHUB_TOKEN` | GitHub API token (automatic in GitHub Actions) |
| `SEAMONSTER_ORG` | Git organization name |
| `SEAMONSTER_DOMAIN` | Domain for deployed services |

## Lib Scripts

Source `git-api.sh` for GitHub API operations. It provides unified `sm_*` functions:

```bash
source "./lib/git-api.sh"          # GitHub API — use sm_* functions
source "./lib/claude-runner.sh"    # Claude invocation wrapper
```
