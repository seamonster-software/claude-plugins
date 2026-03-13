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
- `tea` CLI authenticated (Gitea) OR `gh` CLI authenticated (GitHub)
- `jq` installed

## Step 1: Detect Platform

Determine whether the user is on GitHub or Gitea by checking for CLI tools:

```bash
# Check for tea (Gitea) first, then gh (GitHub)
if command -v tea &>/dev/null && tea login list 2>/dev/null | grep -q .; then
  PLATFORM="gitea"
  GIT_CLI="tea"
  WORKFLOW_DIR=".gitea/workflows"
  GITEA_URL=$(tea login list --output simple 2>/dev/null | head -1 | awk '{print $2}')
elif command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  PLATFORM="github"
  GIT_CLI="gh"
  WORKFLOW_DIR=".github/workflows"
else
  # Ask the user which platform they're using
fi
```

If neither CLI is detected, ask the user which platform they're using and help them authenticate:
- **Gitea:** `tea login add --name <name> --url <gitea-url> --token <token>`
- **GitHub:** `gh auth login`

Do NOT proceed without a working platform connection.

After detection, **confirm with the user** before proceeding:
> Detected **$PLATFORM** via `$GIT_CLI`. Is this correct? (use AskUserQuestion)

## Step 2: Gather Configuration

Ask the user for these values (use AskUserQuestion for each):

| Value | Question | Default | Required |
|-------|----------|---------|----------|
| `ORG` | What's your git org/owner name? | — | Yes |
| `NTFY_URL` | ntfy server URL? (leave blank for ntfy.sh) | `https://ntfy.sh` | No |

Validate the org exists:
- **GitHub:** `gh api /orgs/$ORG` or `gh api /users/$ORG`
- **Gitea:** `tea organizations list 2>/dev/null | grep -q "$ORG"` or `tea repos list --owner "$ORG"`

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
- **Gitea:** `tea repos create --name bridge --owner "$ORG" --description "Sea Monster Bridge — Captain's command center"`, then clone it

Clone the new repo to a temp directory:
```bash
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
# GitHub
gh repo clone "$ORG/bridge" bridge
# Gitea
tea repos clone "$ORG/bridge"
cd bridge
```

## Step 5: Initialize the Bridge

Copy bridge templates from the plugin into the cloned repo. Use the
platform-specific template directory (`.gitea/` or `.github/`):

```bash
# Workflows — copy from the matching platform template
mkdir -p "$WORKFLOW_DIR"
if [[ "$PLATFORM" == "gitea" ]]; then
  cp -r "$PLUGIN_ROOT/templates/bridge/.gitea/workflows/"* "$WORKFLOW_DIR/"
else
  cp -r "$PLUGIN_ROOT/templates/bridge/.github/workflows/"* "$WORKFLOW_DIR/"
fi

# Issue templates
TEMPLATE_DIR=$(dirname "$WORKFLOW_DIR")/ISSUE_TEMPLATE
mkdir -p "$TEMPLATE_DIR"
if [[ "$PLATFORM" == "gitea" ]]; then
  cp -r "$PLUGIN_ROOT/templates/bridge/.gitea/ISSUE_TEMPLATE/"* "$TEMPLATE_DIR/"
else
  cp -r "$PLUGIN_ROOT/templates/bridge/.github/ISSUE_TEMPLATE/"* "$TEMPLATE_DIR/"
fi

# Lib scripts
mkdir -p lib
cp "$PLUGIN_ROOT/lib/"*.sh lib/
chmod +x lib/*.sh

# CLAUDE.md
cp "$PLUGIN_ROOT/templates/bridge/CLAUDE.md" ./CLAUDE.md

# .gitignore
echo ".seamonster/" >> .gitignore
```

## Step 6: Create Labels

Create the scoped labels that drive the issue state machine.

Both CLIs use per-repo label creation. Skip any labels that already exist (ignore duplicate errors).

**Gitea:**
```bash
tea label create --name "approved" --color "#0e8a16" --description "Proposal approved — ready for planning" --repo "$ORG/bridge"
tea label create --name "build-ready" --color "#1d76db" --description "Ready for Builder" --repo "$ORG/bridge"
tea label create --name "deploy-ready" --color "#5319e7" --description "Ready for Deployer" --repo "$ORG/bridge"
tea label create --name "needs-input" --color "#e4e669" --description "Agent blocked — Captain decision needed" --repo "$ORG/bridge"
tea label create --name "live" --color "#0e8a16" --description "Deployed to production" --repo "$ORG/bridge"
tea label create --name "team/scout" --color "#c5def5" --repo "$ORG/bridge"
tea label create --name "team/build" --color "#c5def5" --repo "$ORG/bridge"
tea label create --name "team/ops" --color "#c5def5" --repo "$ORG/bridge"
tea label create --name "team/growth" --color "#c5def5" --repo "$ORG/bridge"
tea label create --name "priority/p0" --color "#b60205" --description "Critical" --repo "$ORG/bridge"
tea label create --name "priority/p1" --color "#d93f0b" --description "High" --repo "$ORG/bridge"
tea label create --name "priority/p2" --color "#fbca04" --description "Normal" --repo "$ORG/bridge"
tea label create --name "size/small" --color "#c2e0c6" --repo "$ORG/bridge"
tea label create --name "size/medium" --color "#c2e0c6" --repo "$ORG/bridge"
tea label create --name "size/large" --color "#c2e0c6" --repo "$ORG/bridge"
tea label create --name "status/blocked" --color "#e4e669" --repo "$ORG/bridge"
tea label create --name "status/waiting" --color "#e4e669" --repo "$ORG/bridge"
tea label create --name "status/active" --color "#0e8a16" --repo "$ORG/bridge"
tea label create --name "type/proposal" --color "#d4c5f9" --repo "$ORG/bridge"
tea label create --name "type/feature" --color "#d4c5f9" --repo "$ORG/bridge"
tea label create --name "type/bug" --color "#d4c5f9" --repo "$ORG/bridge"
tea label create --name "type/deploy" --color "#d4c5f9" --repo "$ORG/bridge"
```

**GitHub:**
```bash
gh label create "approved" --repo "$ORG/bridge" --color "0e8a16" --description "Proposal approved"
gh label create "build-ready" --repo "$ORG/bridge" --color "1d76db" --description "Ready for Builder"
gh label create "deploy-ready" --repo "$ORG/bridge" --color "5319e7" --description "Ready for Deployer"
gh label create "needs-input" --repo "$ORG/bridge" --color "e4e669" --description "Agent blocked — Captain decision needed"
gh label create "live" --repo "$ORG/bridge" --color "0e8a16" --description "Deployed to production"
gh label create "team/scout" --repo "$ORG/bridge" --color "c5def5"
gh label create "team/build" --repo "$ORG/bridge" --color "c5def5"
gh label create "team/ops" --repo "$ORG/bridge" --color "c5def5"
gh label create "team/growth" --repo "$ORG/bridge" --color "c5def5"
gh label create "priority/p0" --repo "$ORG/bridge" --color "b60205" --description "Critical"
gh label create "priority/p1" --repo "$ORG/bridge" --color "d93f0b" --description "High"
gh label create "priority/p2" --repo "$ORG/bridge" --color "fbca04" --description "Normal"
gh label create "size/small" --repo "$ORG/bridge" --color "c2e0c6"
gh label create "size/medium" --repo "$ORG/bridge" --color "c2e0c6"
gh label create "size/large" --repo "$ORG/bridge" --color "c2e0c6"
gh label create "status/blocked" --repo "$ORG/bridge" --color "e4e669"
gh label create "status/waiting" --repo "$ORG/bridge" --color "e4e669"
gh label create "status/active" --repo "$ORG/bridge" --color "0e8a16"
gh label create "type/proposal" --repo "$ORG/bridge" --color "d4c5f9"
gh label create "type/feature" --repo "$ORG/bridge" --color "d4c5f9"
gh label create "type/bug" --repo "$ORG/bridge" --color "d4c5f9"
gh label create "type/deploy" --repo "$ORG/bridge" --color "d4c5f9"
```

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
- **Gitea:** `tea repos list --owner "$ORG" --output simple`

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
   # GitHub
   gh repo clone "$ORG/$REPO" "$REPO"
   # Gitea
   tea repos clone "$ORG/$REPO"
   cd "$REPO"
   ```

2. **Copy project template files** (skip any that already exist — ask before overwriting):
   ```bash
   # Workflows — use platform-specific templates
   mkdir -p "$WORKFLOW_DIR"
   if [[ "$PLATFORM" == "gitea" ]]; then
     cp -r "$PLUGIN_ROOT/templates/project/.gitea/workflows/"* "$WORKFLOW_DIR/"
   else
     cp -r "$PLUGIN_ROOT/templates/project/.github/workflows/"* "$WORKFLOW_DIR/"
   fi

   # Lib scripts
   mkdir -p lib
   cp "$PLUGIN_ROOT/lib/"*.sh lib/
   chmod +x lib/*.sh

   # .gitignore addition
   grep -q '.seamonster/' .gitignore 2>/dev/null || echo ".seamonster/" >> .gitignore
   ```

3. **Do NOT overwrite existing CLAUDE.md** — if one exists, leave it. If none exists, copy the project template and tell the user to fill in the placeholders.

4. **Create the same labels on this repo** (needed for both platforms — GitHub has no org-level labels, and per-repo labels ensure consistency on Gitea too).

5. **Commit and push:**
   ```bash
   git add -A
   git commit -m "feat: onboard to Sea Monster — add workflows and lib"
   git push origin main
   ```

## Step 10: Configure Secrets

If the user has a runner (self-hosted or planned), tell them which secrets to configure:

**Gitea:** `tea actions secrets create --name SECRET_NAME --value "value" --repo "$ORG/bridge"`
**GitHub:** `gh secret set SECRET_NAME --repo "$ORG/bridge"`

| Secret | Value | Notes |
|--------|-------|-------|
| `NTFY_URL` | e.g. `https://ntfy.sh` | Where notifications go |
| `NTFY_TOKEN` | ntfy auth token | Optional (public ntfy.sh doesn't need it) |
| `SEAMONSTER_ORG` | The org name | Used by workflow scripts |
| `SEAMONSTER_DOMAIN` | e.g. `example.com` | For deploy workflows |
| `GITEA_URL` | e.g. `https://git.example.com` | Gitea only |
| `GITEA_TOKEN` | Gitea API token | Gitea only |

`GITHUB_TOKEN` is provided automatically by GitHub Actions — no setup needed.

If the user has no runner, skip this step. Secrets are only needed for automated workflows.

## Step 11: Print Summary

```
Sea Monster initialized!

  Bridge:     $ORG/bridge
  Platform:   $PLATFORM ($GIT_CLI)
  Onboarded:  N repos
  Labels:     Created on bridge + onboarded repos
  ntfy:       $NTFY_URL

Next steps:
  1. File issues in the bridge repo — use issue templates
  2. Run /seamonster:orders to check for work
  3. Run /seamonster:spawn to assign agents to issues
  4. For 24/7 autonomy, set up a runner on a VPS and configure secrets

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
