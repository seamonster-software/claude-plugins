---
name: "Contract Patterns"
description: >
  Interface contracts between build waves. How to define inputs and outputs,
  enforce file ownership boundaries, and pair builders with validators.
---

# Contract Patterns

Contracts define exact interfaces between build waves. They prevent integration
failures by making every dependency explicit before any code is written.

## What Is a Contract

A contract is a specification that says:
- **Inputs**: What this wave receives from previous waves (types, APIs, files)
- **Outputs**: What this wave produces for subsequent waves (exports, schemas, endpoints)
- **File ownership**: Which files this wave may create or modify
- **Acceptance criteria**: How to verify the wave succeeded

Contracts are written during the planning phase by the Planner and Architect,
then enforced during build and review.

## Contract Format

Store contracts as a section in the Gitea issue body or as a dedicated
issue comment. Use this template:

```markdown
## Contract: Wave {N} — {Name}

### Inputs (provided by Wave {N-1})
- `src/db/schema.ts` — exports `UserSchema`, `SessionSchema`
- `src/types/auth.ts` — exports `TokenPayload`, `AuthResult`
- Database migrations applied and tables exist

### Outputs (consumed by Wave {N+1})
- `src/services/auth.ts` — exports:
  - `createToken(userId: string): Promise<TokenPair>`
  - `verifyToken(token: string): Promise<TokenPayload>`
  - `refreshToken(refreshToken: string): Promise<TokenPair>`
  - `revokeToken(userId: string): Promise<void>`
- `src/middleware/requireAuth.ts` — exports:
  - `requireAuth: RequestHandler` (Express middleware)
- Types: `TokenPair = { accessToken: string, refreshToken: string }`

### File Ownership
**May create:**
- `src/services/auth.ts`
- `src/services/auth.test.ts`
- `src/middleware/requireAuth.ts`
- `src/middleware/requireAuth.test.ts`

**May NOT modify:**
- `src/db/*` (owned by Wave 1)
- `src/routes/*` (owned by Wave 3)
- `package.json` (coordinate additions via issue comment)

### Acceptance Criteria
- [ ] All exported functions match signatures above
- [ ] Token creation returns valid JWT with RS256 signing
- [ ] Token verification rejects expired tokens
- [ ] Refresh token rotation invalidates old refresh token
- [ ] Middleware returns 401 for missing/invalid tokens
- [ ] Tests cover happy path and all error cases
- [ ] No hardcoded secrets — keys loaded from environment
```

## Wave Execution Pattern

Large features decompose into waves — groups of tasks that can be parallelized
within a wave but must sequence between waves.

```
Wave 1 (parallel)          Wave 2 (parallel)         Wave 3 (sequential)
├── Database schema         ├── Auth service           ├── API routes
├── Type definitions        ├── User service           │   (depends on all
└── Config setup            └── Email service          │    Wave 2 outputs)
                                                       └── Integration tests
```

### Planning Waves

The Planner creates the wave plan. Each wave becomes a Gitea milestone.
Each task within a wave becomes a Gitea issue linked to that milestone.

```bash
source ./lib/gitea-api.sh

# Create milestones for each wave
gitea_create_milestone "$SEAMONSTER_ORG" "project-alpha" \
  "Wave 1: Foundation" \
  "Database schema, type definitions, config"

gitea_create_milestone "$SEAMONSTER_ORG" "project-alpha" \
  "Wave 2: Services" \
  "Auth, user, email services. Depends on Wave 1."

gitea_create_milestone "$SEAMONSTER_ORG" "project-alpha" \
  "Wave 3: Integration" \
  "API routes, integration tests. Depends on Wave 2."
```

### Executing Waves

Within a wave, independent tasks run in parallel — separate issues, separate
branches, separate Builder sessions. The Builder can spawn sub-agents
for this.

Between waves, wait for all tasks in the current wave to complete (milestone
100%) before starting the next wave. The dispatch workflow checks milestone
completion:

```bash
# Check if Wave 1 milestone is complete
milestone_json=$(gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/milestones" | \
  jq '.[] | select(.title == "Wave 1: Foundation")')
open=$(echo "$milestone_json" | jq '.open_issues')
if [[ "$open" -eq 0 ]]; then
  echo "Wave 1 complete — ready for Wave 2"
fi
```

## File Ownership Boundaries

The most common source of integration failures is two agents editing the same
file. Contracts prevent this.

### Rules

1. Each file is owned by exactly one wave (or one agent within a wave).
2. An agent may only create or modify files listed in its contract's "May create" section.
3. Shared files (like `package.json`, `go.mod`, root config) are coordinated:
   - One wave owns the file
   - Other waves request additions via issue comments
   - The owning wave's agent applies changes
4. If two waves need to modify the same file, the contract is wrong — refactor it.

### Example: Shared Dependency

Wave 2 needs a new npm package that Wave 1 owns `package.json`:

```bash
# Wave 2 Builder posts a comment on Wave 1's issue
gitea_comment "$SEAMONSTER_ORG" "project-alpha" "$WAVE1_ISSUE" \
  "**Builder (Builder)** [Wave 2] — dependency request:

Need \`jsonwebtoken@^9.0.0\` added to package.json for the auth service.

\`\`\`
npm install jsonwebtoken@^9.0.0
\`\`\`"
```

If Wave 1 is already complete, the dependency addition becomes a new issue
assigned to the original wave owner.

## Builder-Validator Pairing

Every builder gets a read-only reviewer. This is not optional.

### How It Works

1. Builder builds on a branch, opens a PR
2. Reviewer reviews the PR (read-only — never modifies files)
3. Reviewer checks against the contract's acceptance criteria
4. If accepted: Reviewer approves, PR is merge-ready
5. If rejected: Reviewer requests changes with specific feedback,
   Builder fixes and updates the PR

### Why Read-Only Matters

The Reviewer must never "help" by fixing issues. If the Reviewer modifies
files:
- The audit trail breaks (who wrote this code?)
- The builder does not learn from the mistake
- The review is no longer independent
- Ownership boundaries are violated

The Reviewer has restricted tools: Read, Glob, Grep, and read-only Bash
commands (git diff, git log, git show). The `claude-runner.sh` wrapper
enforces this via `CLAUDE_ALLOWED_TOOLS`.

### Contract Validation Checklist

The Reviewer verifies each contract item:

```markdown
## Contract Validation — Wave 2: Auth Service

### Outputs Check
- [x] `src/services/auth.ts` exists and exports `createToken`
- [x] `src/services/auth.ts` exports `verifyToken`
- [x] `src/services/auth.ts` exports `refreshToken`
- [x] `src/services/auth.ts` exports `revokeToken`
- [x] `src/middleware/requireAuth.ts` exports `requireAuth`
- [x] `TokenPair` type matches contract

### File Ownership Check
- [x] Only created files listed in contract
- [x] No modifications to Wave 1 files (`src/db/*`)
- [x] No modifications to Wave 3 files (`src/routes/*`)

### Acceptance Criteria
- [x] JWT with RS256 signing
- [x] Expired token rejection
- [x] Refresh rotation invalidates old token
- [x] 401 on missing/invalid tokens
- [x] Tests cover happy and error paths
- [x] No hardcoded secrets
```

## Contract Evolution

Contracts may need to change during build. The protocol:

1. The Builder discovers the contract needs adjustment
2. Posts a comment on the wave issue explaining the proposed change
3. Checks if other waves depend on the affected interface
4. If no downstream dependencies are affected: update the contract in the issue
5. If downstream dependencies are affected: escalate to the Planner to
   re-plan, and notify affected agents via issue comments

Never silently change a contract. The change must be visible in the Gitea
issue history.

## Minimal Contracts

Not every task needs a full contract. Use contracts when:
- Multiple waves or agents depend on each other
- The task produces interfaces consumed by other code
- File ownership conflicts are possible
- The feature is complex enough to warrant parallel work

For simple, isolated tasks (fix a typo, update docs, add a single endpoint),
the issue description and acceptance criteria are sufficient.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| No contract, just "build the auth" | Vague scope, wrong interfaces | Write the contract first |
| Two agents edit same file | Merge conflicts, lost work | Enforce file ownership |
| Contract says X, builder delivers Y | Integration failure | Reviewer validates against contract |
| Changing contracts without notification | Downstream agents break | Comment on issue, notify affected waves |
| Giant single wave | No parallelism, slow | Split into independent sub-tasks |
| Reviewer fixes code | Broken audit trail | Reviewer is read-only, always |
