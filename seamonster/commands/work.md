---
name: "work"
description: "Poll the bridge for actionable issues and spawn agents to work them. The Captain's 'go work' button."
user_facing: true
---

# /seamonster:work — Work the Queue

Poll all repos in the org for actionable issues and spawn the right crew member for each one. This is how you kick off the autonomous loop from an interactive session.

## What to Do

### Step 1: Detect the Org

```bash
# Use SEAMONSTER_ORG if set, otherwise detect from gh
ORG="${SEAMONSTER_ORG:-}"
if [[ -z "$ORG" ]]; then
  # Try to detect from the current repo's remote
  ORG=$(gh repo view --json owner -q '.owner.login' 2>/dev/null || echo "")
fi
```

If ORG is still empty, ask the user with AskUserQuestion: "What's your GitHub org/owner name?"

### Step 2: Gather Actionable Issues

Query all repos in the org for open issues. Categorize them:

```bash
# Get all repos
repos=$(gh repo list "$ORG" --json name --limit 100 -q '.[].name')

# For each repo, get open issues with their labels
for repo in $repos; do
  gh api "/repos/${ORG}/${repo}/issues?state=open&per_page=50" \
    --jq '.[] | select(.pull_request == null) | {repo: "'"$repo"'", number: .number, title: .title, labels: [.labels[].name]}'
done
```

### Step 3: Build the Work Queue

Sort issues into actionable categories, in priority order:

**1. Deploy Ready** — issues with `deploy-ready` label. Ship first.
- Agent: **Deployer**

**2. PRs to Review** — open pull requests without a review.
- Agent: **Reviewer**
- Query: `gh api "/repos/${ORG}/${repo}/pulls?state=open&per_page=50"`

**3. Build Ready** — issues with `build-ready` label, NOT `status/active`.
- Agent: **Builder**
- Sort by priority label (p0 > p1 > p2), then issue number

**4. Needs Input** — issues with `needs-input` label. Show these to the Captain but do NOT spawn agents.

Skip issues with `status/active` (already being worked).

### Step 4: Present the Queue

Show the Captain what's actionable:

```
## Work Queue

### Deploy Ready (1)
  1. project-gamma #2  Static site build        deploy-ready

### PRs to Review (1)
  2. project-alpha PR #15  Auth middleware       awaiting review

### Build Ready (3)
  3. project-alpha #50  Admin dashboard          priority/p1  size/medium
  4. project-alpha #51  API rate limiting        priority/p2  size/small
  5. project-beta  #15  User onboarding flow     priority/p1  size/large

### Blocked — needs your input (2)
  - project-alpha #47  Auth: JWT vs sessions?   waiting 3h
  - project-beta  #12  Database choice needed   waiting 1d

Ready to dispatch 5 tasks. Work all, or pick specific numbers?
```

### Step 5: Get Confirmation

Use AskUserQuestion to ask the Captain:

> "Ready to dispatch N tasks. Work all, pick specific numbers (e.g. 1,3,5), or skip?"

Options:
- **all** — dispatch every actionable item
- **1,3,5** — dispatch specific numbered items
- **skip** — show the queue but don't dispatch

If there is only 1 actionable item, skip confirmation and dispatch it directly.

### Step 6: Dispatch Agents

For each selected item, spawn the appropriate agent as a subagent using the Agent tool.

**For Builder tasks:**
Spawn a Builder subagent with this context:
```
You are the Builder working on {ORG}/{repo}.

## Issue #{number}: {title}

{issue body}

## Instructions

1. Create a branch: issue-{number}
2. Build the feature/fix described in the issue
3. Commit with conventional commits referencing #{number}
4. Open a PR back to main
5. Post a comment on issue #{number} with what you built
6. Add label status/active when you start, remove it when you open the PR
```

**For Reviewer tasks:**
Spawn a Reviewer subagent:
```
You are the Reviewer. Review PR #{pr_number} in {ORG}/{repo}.

Read the diff, check for bugs, security issues, edge cases, and code quality.
Post your review. Approve if it meets standards, or request changes.
You are READ-ONLY — do not modify any files.
```

**For Deployer tasks:**
Spawn a Deployer subagent:
```
You are the Deployer working on {ORG}/{repo}.

## Issue #{number}: {title}

{issue body}

Deploy the changes described. Follow the project's deploy conventions.
Post a comment on issue #{number} with deploy status.
```

### Step 7: Report

After dispatching, summarize:

```
## Dispatched

- Builder → project-alpha #50 (Admin dashboard)
- Builder → project-beta #15 (User onboarding flow)
- Reviewer → project-alpha PR #15 (Auth middleware)

3 agents working. Run /seamonster:crew-status to check progress.
```

## Dispatch Rules

1. **One agent per issue.** Don't spawn two Builders for the same issue.
2. **Respect priority order.** Deploy first, then review, then build.
3. **Skip active work.** If an issue has `status/active`, someone is on it.
4. **Clone first.** The spawned agent needs the repo cloned locally. If the repo isn't already cloned, clone it to a temp directory or the workspace.
5. **Parallel is fine.** Independent tasks can be dispatched as parallel subagents. Use multiple Agent tool calls in a single response.
6. **Cap concurrent work.** Don't dispatch more than 3 agents at once unless the Captain explicitly asks for more. Session context and rate limits matter.
7. **Show blocked items.** Always show `needs-input` issues so the Captain can unblock them, but never auto-dispatch agents for blocked work.

## Notes

- This command replaces the autonomous workflow trigger. Instead of GitHub Actions firing on label changes, the Captain runs `/seamonster:work` and agents work within their interactive session.
- The spawned agents should use the Agent tool with the appropriate `subagent_type` (seamonster:Builder, seamonster:Reviewer, seamonster:Deployer).
- If no actionable work is found, say so: "No actionable work in the queue. File issues in the bridge or run /seamonster:orders for the full picture."
