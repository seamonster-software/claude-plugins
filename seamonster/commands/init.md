---
name: init
description: Create the Sea Monster bridge repo, scan the org for existing repos, and onboard them with workflows and lib scripts. The single entry point for setting up Sea Monster.
user_facing: true
---

# /seamonster:init — Set Up Sea Monster

This is the one-time onboarding command. It creates the bridge (coordination repo), scans the org for existing repos, and pushes workflows + lib scripts to each one.

## Prerequisites

Before running this command, the user needs:
- A git org (GitHub or Gitea) where repos will live
- `gh` CLI authenticated (GitHub) OR `GITEA_URL` + `GITEA_TOKEN` env vars (Gitea)
- `jq` installed

## Step 1: Detect Platform

Determine whether the user is on GitHub or Gitea:

```bash
# Check for Gitea env vars first
if [[ -n "${GITEA_URL:-}" && -n "${GITEA_TOKEN:-}" ]]; then
  PLATFORM="gitea"
  WORKFLOW_DIR=".gitea/workflows"
elif command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  PLATFORM="github"
  WORKFLOW_DIR=".github/workflows"
else
  # Ask the user
fi
```

If neither is detected, ask the user which platform they're using and what credentials they have. Do NOT proceed without a working platform connection.

## Step 2: Gather Configuration

Ask the user for these values (use AskUserQuestion for each):

| Value | Question | Default | Required |
|-------|----------|---------|----------|
| `ORG` | What's your git org/owner name? | — | Yes |
| `NTFY_URL` | ntfy server URL? | `https://ntfy.sh` | Yes |
| `DOMAIN` | Domain for deployed services? | — | For Sovereign tier |

Validate the org exists:
- **GitHub:** `gh api /orgs/$ORG` or `gh api /users/$ORG`
- **Gitea:** `curl -fsSL -H "Authorization: token $GITEA_TOKEN" "$GITEA_URL/api/v1/orgs/$ORG"`

## Step 3: Locate Plugin Templates

Find the Sea Monster plugin root to access templates and lib scripts:

```bash
# CLAUDE_PLUGIN_ROOT is set when running inside the plugin
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

# Fallback: search for the plugin
if [[ -z "$PLUGIN_ROOT" ]]; then
  PLUGIN_ROOT=$(find ~/.claude/plugins -name "plugin.json" -path "*/seamonster/*" 2>/dev/null | head -1 | xargs dirname | xargs dirname 2>/dev/null || echo "")
fi
```

If the plugin root can't be found, tell the user to install the plugin first: `claude plugin add seamonster-software/claude-plugins`

## Step 4: Create the Bridge Repo

Check if a `bridge` repo already exists in the org. If it does, ask the user if they want to use it or pick a different name.

Create the repo:
- **GitHub:** `gh repo create $ORG/bridge --public --description "Sea Monster Bridge — Captain's command center" --clone`
- **Gitea:** Use the gitea_create_repo function from lib/gitea-api.sh, then clone it

Clone the new repo to a temp directory:
```bash
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
git clone <repo_url> bridge
cd bridge
```

## Step 5: Initialize the Bridge

Copy bridge templates from the plugin into the cloned repo:

```bash
# Workflows
mkdir -p "$WORKFLOW_DIR"
cp -r "$PLUGIN_ROOT/templates/bridge/.gitea/workflows/"* "$WORKFLOW_DIR/" 2>/dev/null || true

# Issue templates (Gitea uses .gitea/, GitHub uses .github/)
TEMPLATE_DIR=$(dirname "$WORKFLOW_DIR")/ISSUE_TEMPLATE
mkdir -p "$TEMPLATE_DIR"
cp -r "$PLUGIN_ROOT/templates/bridge/.gitea/ISSUE_TEMPLATE/"* "$TEMPLATE_DIR/"

# Lib scripts
mkdir -p lib
cp "$PLUGIN_ROOT/lib/"*.sh lib/
chmod +x lib/*.sh

# CLAUDE.md
cp "$PLUGIN_ROOT/templates/bridge/CLAUDE.md" ./CLAUDE.md

# .gitignore
echo ".seamonster/" >> .gitignore
```

If the platform is GitHub, rename any `.gitea/` paths in the workflow YAML files to use `github` event syntax. **Note: GitHub workflow templates are not yet available — warn the user that Gitea workflows were copied and may need manual adaptation for GitHub Actions.**

## Step 6: Create Org-Level Labels

Create the scoped labels that drive the issue state machine.

**For Gitea** (org-level labels):
```bash
# State labels
gitea_post "/orgs/$ORG/labels" '{"name":"approved","color":"#0e8a16","description":"Proposal approved — ready for planning"}'
gitea_post "/orgs/$ORG/labels" '{"name":"build-ready","color":"#1d76db","description":"Ready for Builder"}'
gitea_post "/orgs/$ORG/labels" '{"name":"deploy-ready","color":"#5319e7","description":"Ready for Deployer"}'
gitea_post "/orgs/$ORG/labels" '{"name":"needs-input","color":"#e4e669","description":"Agent blocked — Captain decision needed"}'
gitea_post "/orgs/$ORG/labels" '{"name":"live","color":"#0e8a16","description":"Deployed to production"}'

# Team labels
gitea_post "/orgs/$ORG/labels" '{"name":"team/scout","color":"#c5def5"}'
gitea_post "/orgs/$ORG/labels" '{"name":"team/build","color":"#c5def5"}'
gitea_post "/orgs/$ORG/labels" '{"name":"team/ops","color":"#c5def5"}'
gitea_post "/orgs/$ORG/labels" '{"name":"team/growth","color":"#c5def5"}'

# Priority labels
gitea_post "/orgs/$ORG/labels" '{"name":"priority/p0","color":"#b60205","description":"Critical"}'
gitea_post "/orgs/$ORG/labels" '{"name":"priority/p1","color":"#d93f0b","description":"High"}'
gitea_post "/orgs/$ORG/labels" '{"name":"priority/p2","color":"#fbca04","description":"Normal"}'

# Size labels
gitea_post "/orgs/$ORG/labels" '{"name":"size/small","color":"#c2e0c6"}'
gitea_post "/orgs/$ORG/labels" '{"name":"size/medium","color":"#c2e0c6"}'
gitea_post "/orgs/$ORG/labels" '{"name":"size/large","color":"#c2e0c6"}'

# Status labels
gitea_post "/orgs/$ORG/labels" '{"name":"status/blocked","color":"#e4e669"}'
gitea_post "/orgs/$ORG/labels" '{"name":"status/waiting","color":"#e4e669"}'
gitea_post "/orgs/$ORG/labels" '{"name":"status/active","color":"#0e8a16"}'

# Type labels
gitea_post "/orgs/$ORG/labels" '{"name":"type/proposal","color":"#d4c5f9"}'
gitea_post "/orgs/$ORG/labels" '{"name":"type/feature","color":"#d4c5f9"}'
gitea_post "/orgs/$ORG/labels" '{"name":"type/bug","color":"#d4c5f9"}'
gitea_post "/orgs/$ORG/labels" '{"name":"type/deploy","color":"#d4c5f9"}'
```

**For GitHub** (per-repo labels — GitHub doesn't support org-level labels):
```bash
# Create labels on the bridge repo, and later on each onboarded repo
gh label create "approved" --repo "$ORG/bridge" --color "0e8a16" --description "Proposal approved"
gh label create "build-ready" --repo "$ORG/bridge" --color "1d76db" --description "Ready for Builder"
# ... (same set of labels)
```

Skip any labels that already exist (both APIs return errors for duplicates — ignore them).

## Step 7: Commit and Push the Bridge

```bash
cd "$WORK_DIR/bridge"
git add -A
git commit -m "feat: initialize Sea Monster bridge"
git push origin main
```

## Step 8: Scan the Org for Existing Repos

List all repos in the org (excluding the bridge itself and any forks):

- **GitHub:** `gh repo list $ORG --json name,description,isFork --limit 100 --no-archived`
- **Gitea:** `curl ... "$GITEA_URL/api/v1/orgs/$ORG/repos?limit=50&type=sources"`

Filter out:
- The bridge repo itself
- Forks
- Archived repos
- Repos that already have a `lib/claude-runner.sh` (already onboarded)

Present the list to the user and ask which repos to onboard. Default: all of them.

## Step 9: Onboard Selected Repos

For each selected repo:

1. **Clone to temp directory:**
   ```bash
   cd "$WORK_DIR"
   git clone <repo_url> <repo_name>
   cd <repo_name>
   ```

2. **Copy project template files** (skip any that already exist — ask before overwriting):
   ```bash
   # Workflows
   mkdir -p "$WORKFLOW_DIR"
   cp -r "$PLUGIN_ROOT/templates/project/.gitea/workflows/"* "$WORKFLOW_DIR/" 2>/dev/null || true

   # Lib scripts
   mkdir -p lib
   cp "$PLUGIN_ROOT/lib/"*.sh lib/
   chmod +x lib/*.sh

   # .gitignore addition
   grep -q '.seamonster/' .gitignore 2>/dev/null || echo ".seamonster/" >> .gitignore
   ```

3. **Do NOT overwrite existing CLAUDE.md** — if one exists, leave it. If none exists, copy the project template and tell the user to fill in the placeholders.

4. **For GitHub repos, create the same labels** (per-repo, since GitHub has no org-level labels).

5. **Commit and push:**
   ```bash
   git add -A
   git commit -m "feat: onboard to Sea Monster — add workflows and lib"
   git push origin main
   ```

## Step 10: Configure Secrets

Tell the user which secrets to configure. The method depends on platform:

**Gitea:** Repository or org-level secrets in Settings → Actions → Secrets
**GitHub:** `gh secret set` or Settings → Secrets

Required secrets (set at org level if possible, otherwise per-repo):

| Secret | Value | Notes |
|--------|-------|-------|
| `GITEA_URL` | e.g. `https://git.example.com` | Gitea only |
| `GITEA_TOKEN` | Gitea API token | Gitea only |
| `GITHUB_TOKEN` | (automatic) | GitHub provides this |
| `NTFY_URL` | e.g. `https://ntfy.sh` | All tiers |
| `NTFY_TOKEN` | ntfy auth token | Optional (public ntfy.sh doesn't need it) |
| `SEAMONSTER_ORG` | The org name | All tiers |
| `SEAMONSTER_DOMAIN` | e.g. `seamonster.software` | For deploy workflows |

## Step 11: Print Summary

Print a summary of what was done:

```
Sea Monster initialized!

  Bridge:     $ORG/bridge
  Platform:   $PLATFORM
  Onboarded:  N repos
  Labels:     Created (org-level / per-repo)

Next steps:
  1. Configure secrets (see above)
  2. Set up act_runner (connects to your $PLATFORM org)
  3. Authenticate Claude: ssh into the runner machine, run 'claude'
  4. File your first issue in the bridge — the crew handles the rest

Bridge URL: <url>
```

## Important

- Do NOT overwrite existing files without asking the user
- If workflows already exist in a repo, warn and ask before merging
- Skip repos the user doesn't want to onboard
- All operations should be idempotent — safe to re-run
- If any step fails, report the error clearly and continue with the next repo
- Clean up the temp directory when done: `rm -rf "$WORK_DIR"`
- The lib scripts require `curl`, `jq`, and `claude` — no other dependencies
