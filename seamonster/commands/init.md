---
name: init
description: Initialize a repo with Sea Monster workflows, lib scripts, and CLAUDE.md. Sets up the autonomous loop for a hub or project repo.
user_facing: true
---

# /seamonster:init — Set Up Sea Monster in a Repo

Initialize the current repository with Sea Monster workflow templates, lib scripts, and configuration.

## Steps

1. **Determine repo type.** Ask the user:
   - **Hub repo** — coordination repo (`_hub`). Gets issue-triggered workflows (build-ready, pr-opened, pr-merged, needs-input), issue templates, and CLAUDE.md.
   - **Project repo** — a software project. Gets CI/CD workflows (build, test, review, deploy) and CLAUDE.md.

2. **Determine git platform.** Ask the user:
   - **Gitea** — uses `.gitea/workflows/` directory
   - **GitHub** — uses `.github/workflows/` directory
   (For now, only Gitea templates are available. GitHub templates are coming.)

3. **Copy files from the plugin's templates directory.** The templates live in the Sea Monster plugin at `${CLAUDE_PLUGIN_ROOT}/templates/`. Use the Bash tool to find the plugin root:
   ```bash
   # The plugin root is where this command's plugin.json lives
   PLUGIN_ROOT=$(dirname "$(dirname "$(readlink -f "$0")")" 2>/dev/null || echo "")
   ```

   If `CLAUDE_PLUGIN_ROOT` is not available, search for the seamonster plugin:
   ```bash
   find ~/.claude/plugins -name "plugin.json" -path "*/seamonster/*" 2>/dev/null | head -1 | xargs dirname | xargs dirname
   ```

4. **Copy the template files into the repo:**

   For a **hub repo**:
   ```bash
   # From the plugin's templates/hub-repo/ directory, copy:
   cp -r $PLUGIN_ROOT/templates/hub-repo/.gitea ./ 2>/dev/null  # workflows + issue templates
   cp -r $PLUGIN_ROOT/templates/hub-repo/CLAUDE.md ./           # hub CLAUDE.md
   mkdir -p ./lib
   cp $PLUGIN_ROOT/lib/*.sh ./lib/                               # gitea-api.sh, notify.sh, claude-runner.sh
   chmod +x ./lib/*.sh
   ```

   For a **project repo**:
   ```bash
   cp -r $PLUGIN_ROOT/templates/project/.gitea ./ 2>/dev/null   # workflows
   cp -r $PLUGIN_ROOT/templates/project/CLAUDE.md ./            # project CLAUDE.md template
   cp -r $PLUGIN_ROOT/templates/project/README.md ./ 2>/dev/null
   mkdir -p ./lib
   cp $PLUGIN_ROOT/lib/*.sh ./lib/                               # gitea-api.sh, notify.sh, claude-runner.sh
   chmod +x ./lib/*.sh
   ```

5. **Add `.seamonster/` to `.gitignore`** (for logs and lock files):
   ```
   .seamonster/
   ```

6. **Print required secrets.** Tell the user which repository secrets they need to configure:

   | Secret | Description | Required |
   |---|---|---|
   | `GITEA_URL` | Base URL of Gitea server (e.g., `https://git.example.com`) | Yes (Gitea) |
   | `GITEA_TOKEN` | Gitea API token | Yes (Gitea) |
   | `NTFY_URL` | ntfy server URL (e.g., `https://ntfy.sh` or self-hosted) | Yes |
   | `NTFY_TOKEN` | ntfy auth token | Optional |
   | `SEAMONSTER_ORG` | Git organization name | Yes |
   | `SEAMONSTER_DOMAIN` | Domain for deployed services | For deploy workflows |

7. **For hub repos, prompt about CLAUDE.md customization.** The template has placeholder values. Ask if the user wants to fill in project-specific details now.

8. **Commit the changes** with message: `feat: initialize Sea Monster workflows and lib`

## Important

- Do NOT overwrite existing files without asking
- If `.gitea/workflows/` or `.github/workflows/` already exists, warn and ask before merging
- The lib scripts are self-contained — no external dependencies beyond `curl`, `jq`, and `claude`
- Workflows use `runs-on: self-hosted` — requires act_runner to be configured
