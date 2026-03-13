/**
 * session-log.js — Sea Monster session activity logger
 *
 * Hook type: Stop
 * Fires after each Claude Code session ends.
 *
 * Logs agent activity (who, what, when, which project) to a local
 * log file for audit trail. If a Gitea issue is being worked on,
 * posts a summary comment to that issue.
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const SEAMONSTER_ROOT = process.env.SEAMONSTER_ROOT || "/opt/seamonster";
const LOG_DIR = process.env.SEAMONSTER_LOG_DIR || path.join(SEAMONSTER_ROOT, "logs", "sessions");
const GITEA_URL = process.env.GITEA_URL;
const GITEA_TOKEN = process.env.GITEA_TOKEN;
const SEAMONSTER_ORG = process.env.SEAMONSTER_ORG || "seamonster";

/**
 * Extract agent identity from the session transcript.
 * Looks for "You are the {Name}" patterns in the conversation.
 */
function detectAgent(transcript) {
  if (!transcript || !Array.isArray(transcript)) return "Unknown";

  for (const message of transcript) {
    const content =
      typeof message === "string"
        ? message
        : message.content || message.text || "";
    const match = content.match(
      /You are the (\w[\w\s]*?\([\w\s]+\))/
    );
    if (match) return match[1];
  }

  return "Unknown";
}

/**
 * Extract issue number from session context.
 * Checks for #N patterns, issue-N branch names, or ISSUE_NUMBER env.
 */
function detectIssue(transcript, cwd) {
  // Check environment variable first
  if (process.env.ISSUE_NUMBER) {
    return process.env.ISSUE_NUMBER;
  }

  // Check current branch name for issue-N pattern
  try {
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      cwd: cwd || process.cwd(),
      encoding: "utf8",
      timeout: 5000,
    }).trim();
    const branchMatch = branch.match(/issue-(\d+)/);
    if (branchMatch) return branchMatch[1];
  } catch {
    // Not a git repo or git not available — continue
  }

  // Scan transcript for issue references
  if (transcript && Array.isArray(transcript)) {
    for (const message of transcript) {
      const content =
        typeof message === "string"
          ? message
          : message.content || message.text || "";
      const issueMatch = content.match(/[Ii]ssue #(\d+)/);
      if (issueMatch) return issueMatch[1];
    }
  }

  return null;
}

/**
 * Extract repo name from the working directory path.
 * Expects: /opt/seamonster/repos/{org}/{repo}
 */
function detectRepo(cwd) {
  if (process.env.REPO) return process.env.REPO;

  const repoPath = cwd || process.cwd();
  const repoMatch = repoPath.match(/repos\/[^/]+\/([^/]+)/);
  if (repoMatch) return repoMatch[1];

  // Fall back to directory name
  return path.basename(repoPath);
}

/**
 * Summarize tool usage from the session.
 */
function summarizeTools(toolResults) {
  if (!toolResults || !Array.isArray(toolResults)) return {};

  const counts = {};
  for (const result of toolResults) {
    const tool = result.tool || result.name || "unknown";
    counts[tool] = (counts[tool] || 0) + 1;
  }
  return counts;
}

/**
 * Build a human-readable activity summary.
 */
function buildSummary(agent, repo, issue, toolCounts, durationMs) {
  const lines = [];

  lines.push(`**${agent}** — session summary`);
  lines.push(`**Repo:** ${repo} | **Issue:** #${issue}`);
  lines.push("");

  if (durationMs) {
    const mins = Math.round(durationMs / 60000);
    lines.push(`**Duration:** ${mins} minute${mins !== 1 ? "s" : ""}`);
  }

  if (Object.keys(toolCounts).length > 0) {
    lines.push("**Tool usage:**");
    for (const [tool, count] of Object.entries(toolCounts).sort(
      (a, b) => b[1] - a[1]
    )) {
      lines.push(`- ${tool}: ${count}`);
    }
  }

  return lines.join("\n");
}

/**
 * Write the log entry to a local file.
 */
function writeLogFile(entry) {
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const agent = (entry.agent || "unknown")
      .replace(/[^a-zA-Z0-9-]/g, "-")
      .toLowerCase();
    const filename = `${timestamp}_${agent}_${entry.repo || "general"}.json`;
    const filepath = path.join(LOG_DIR, filename);

    fs.writeFileSync(filepath, JSON.stringify(entry, null, 2) + "\n", "utf8");
    return filepath;
  } catch (err) {
    console.error(`[session-log] Failed to write log: ${err.message}`);
    return null;
  }
}

/**
 * Post a summary comment to the Gitea issue.
 */
function postGiteaComment(repo, issue, body) {
  if (!GITEA_URL || !GITEA_TOKEN || !repo || !issue) return;

  try {
    const url = `${GITEA_URL}/api/v1/repos/${SEAMONSTER_ORG}/${repo}/issues/${issue}/comments`;
    const payload = JSON.stringify({ body });

    execSync(
      `curl -fsSL -X POST \
        -H "Authorization: token ${GITEA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d ${JSON.stringify(payload)} \
        "${url}"`,
      {
        encoding: "utf8",
        timeout: 10000,
        stdio: ["pipe", "pipe", "pipe"],
      }
    );
  } catch (err) {
    console.error(
      `[session-log] Failed to post Gitea comment: ${err.message}`
    );
  }
}

// --- Hook entry point ---

module.exports = async function sessionLog({ session, transcript, toolResults }) {
  const startTime = session?.startTime || Date.now();
  const endTime = Date.now();
  const durationMs = endTime - startTime;
  const cwd = session?.cwd || process.cwd();

  const agent = detectAgent(transcript);
  const repo = detectRepo(cwd);
  const issue = detectIssue(transcript, cwd);
  const toolCounts = summarizeTools(toolResults);

  // Build log entry
  const entry = {
    timestamp: new Date().toISOString(),
    agent,
    repo,
    issue: issue || null,
    durationMs,
    toolCounts,
    cwd,
    exitCode: session?.exitCode ?? 0,
  };

  // Write to local log file
  const logFile = writeLogFile(entry);

  // Post summary to Gitea issue if we know which one
  if (issue && repo) {
    const summary = buildSummary(agent, repo, issue, toolCounts, durationMs);
    postGiteaComment(repo, issue, summary);
  }

  return { logFile, entry };
}
