# {{PROJECT_NAME}}

## Project Overview

{{PROJECT_DESCRIPTION}}

**Repo:** `{{SEAMONSTER_ORG}}/{{PROJECT_NAME}}`
**Live URL:** `https://{{PROJECT_NAME}}.{{DOMAIN}}`
**Bridge Issue:** {{BRIDGE_ISSUE_LINK}}

## Stack

- **Language:** {{LANGUAGE}}
- **Framework:** {{FRAMEWORK}}
- **Database:** {{DATABASE}}
- **Other:** {{OTHER_DEPS}}

## Conventions

### Code Style

- Follow the language's standard formatting (prettier for JS/TS, black for Python, gofmt for Go, rustfmt for Rust)
- Functions under 50 lines. Split if longer.
- Every public function gets a doc comment.
- No magic numbers or strings — use named constants.
- Error handling is mandatory. No silent failures.

### File Structure

```
{{PROJECT_STRUCTURE}}
```

### Naming

- Files: `kebab-case` for JS/TS/Python, `snake_case` for Go/Rust
- Functions: `camelCase` for JS/TS, `snake_case` for Python/Go/Rust
- Constants: `UPPER_SNAKE_CASE`
- Types/Classes: `PascalCase`

### Git

- **Branch from main**: `issue-{number}-{short-description}`
- **Conventional commits**: `feat(scope): description (#issue)`
- **Never commit to main directly** — always via PR
- **Every commit references the issue number**

### PR Format

```
## Summary
Implements #{issue_number}.

## Changes
- [what changed and why]

## Testing
- [how to verify]

## Checklist
- [ ] Tests pass
- [ ] No hardcoded secrets
- [ ] Error handling in place
- [ ] Follows project conventions
```

## Testing

### Running Tests

```bash
{{TEST_COMMAND}}
```

### Test Expectations

- Every feature gets tests covering happy path and error paths
- Edge cases: null, empty, overflow, concurrent access
- Tests assert behavior, not implementation details
- Aim for meaningful coverage, not 100% line coverage

### Linting

```bash
{{LINT_COMMAND}}
```

## Deployment

- **Target:** `https://{{PROJECT_NAME}}.{{DOMAIN}}`
- **Method:** Merge to main triggers Deployer via GitHub Actions
- **Service:** `seamonster-{{PROJECT_NAME}}` (systemd)
- **Deployment config:** Managed by the Deployer agent
- **Env file:** `.env` (gitignored) or via repository secrets

### Environment Variables

| Variable | Description | Required |
|---|---|---|
| `PORT` | Service listen port | Yes |
| `NODE_ENV` / equivalent | Runtime environment | Yes |
| `DATABASE_URL` | Database connection string | If using DB |

## Agent Notes

- The Builder builds features on issue branches and opens PRs
- The Reviewer reviews PRs (read-only) and approves or requests changes
- The Deployer deploys on merge to main
- All agents post progress comments on the relevant GitHub issue
- If blocked, agents escalate via the escalation protocol — never stall silently

## Secrets

Never commit secrets. Reference via environment variables.

- GitHub Actions secrets for CI/CD: `${{ secrets.NAME }}`
- Runtime secrets in env file: `.env` (gitignored, `600` permissions)
- File permissions: env files are `600`, env directory is `700`
