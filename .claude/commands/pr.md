---
description: Create PR and monitor CI. Usage: /pr [commit] to auto-commit changes
---

You are a GitHub PR automation assistant.

## Parse optional instructions

If the user provided additional text after the command (e.g., `/pr "focus on auth changes"`), extract these instructions and use them as guidance throughout the process.

## Step 1: Handle uncommitted changes

If the user invoked this command with "commit" argument (e.g., `/pr commit`), then:

**First, check if we're on main/master and create a branch if needed:**

1. Get current branch:
```bash
git branch --show-current
```

2. If on "main" or "master":
   - Stage all changes first to analyze them:
   ```bash
   git add -A
   ```
   - Get staged changes:
   ```bash
   git diff --cached --stat
   ```
   - **Generate branch name as `update-{largest-filename}`** where largest-filename is the file with the most changes (without extension, e.g., "update-auth" if src/auth.ts has most changes).
   - Create and switch to the new branch:
   ```bash
   git checkout -b <generated-branch-name>
   ```
   - Display: "✓ Created and switched to branch: <branch-name>"

**Then proceed with commit:**

1. If not already staged (because we didn't create a branch above), stage all changes:
```bash
git add -A
```

2. Get the staged changes to analyze:
```bash
git diff --cached --stat
```

3. **Analyze the staged changes and generate a meaningful commit message** describing what was changed (follow normal Claude Code commit style). The message should end with:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

4. Try to commit with the generated message:
```bash
git commit -m "<generated-commit-message>"
```

5. If commit fails and the error contains "gitleaks":
   - Display the full error output
   - Determine if it's a false positive or a legitimate issue. If legitimate, exit immediately and instruct the user to fix the issue manually. When in doubt, ask the user for clarification.
   - If it's a false positive, display: "⚠️  Gitleaks blocked commit - retrying with --no-verify" and retry with:
```bash
git commit --no-verify -m "<generated-commit-message>"
```

6. If commit fails for other reasons:
   - Display: "❌ Commit failed:"
   - Display the full error output
   - Exit with error

If the user did not provide "commit" argument, skip Step 1 entirely.

## Step 2: Get branch info and push

Get the current branch name:
```bash
git branch --show-current
```

Get the main branch name from GitHub:
```bash
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"
```

If the current branch is "main" or "master", exit with error message "❌ Cannot create PR from main/master. Run '/pr commit' to auto-create a branch."

Check if the branch exists on remote:
```bash
git ls-remote --heads origin <branch-name>
```

If the branch doesn't exist on remote, push it:
```bash
git push -u origin <branch-name>
```

If push fails:
- Display: "❌ Push failed (likely GitHub push protection):"
- Display the full error output
- Exit with error

## Step 3: Generate PR title and description

**SECURITY: Never include API keys, credentials, PII, or other sensitive information in PR titles or descriptions.**

**IMPORTANT: Generate intelligent 2-section PR content:**

For the **Changes** section: **Exclude testing/linting changes** (e.g., "added tests", "updated eslint config", "fixed type errors") from bullets UNLESS the entire PR is about testing/linting improvements. Focus on actual feature/bug fix/refactor changes.

**When in Claude Code chat:**
- Analyze conversation history to understand what was implemented
- Generate concise, clear PR with:
  1. **Summary**: Non-technical overview (what/why) - 1-2 sentences
  2. **Changes**: Technical bullet list - 3-5 concise bullets

**When standalone (no chat context):**
- Analyze git diff and commits
- Generate based on code changes
- Keep it concise: Summary 1-2 sentences, Changes 3-5 bullets

Get the diff stats between main branch and current branch:
```bash
git diff <main-branch>...HEAD --stat
```

Get the list of changed files:
```bash
git diff <main-branch>...HEAD --name-only
```

Get the commit messages:
```bash
git log <main-branch>..HEAD --pretty=format:"%s"
```

Analyze the changes and generate:
- **PR title**: Use the first commit message (shortened to 50 chars max). If no commits, use "Update <repo-name>".
- **PR body**: Two sections only (Summary and Changes) following the length guidance above.

## Step 4: Create or get PR

Try to create the PR with the generated title and body:
```bash
gh pr create --title "<title>" --body "<body>" 2>&1
```

If PR creation fails with "already exists" error:
- Get the existing PR URL:
```bash
gh pr view <branch-name> --json url --jq .url
```

If PR creation fails for other reasons:
- Display: "❌ PR creation failed:"
- Display the full error output
- Exit with error

If PR was created successfully, the URL is returned in the output.

Store the PR URL to display at the end.

## Step 4b: Update existing PR description

To update an existing PR's description, use GitHub API:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number> -X PATCH -f body="<new-body>"
```

## Step 5: Monitor CI

**NOTE: You have access to all previous command outputs in conversation history - reference them directly instead of using bash variables.**

**IMPORTANT: Use `gh run watch` to monitor in-progress runs. Don't poll repeatedly with sleep - `gh run watch` blocks until completion.**

First, sleep 10 seconds to allow CI checks to start:
```bash
sleep 10
```

Get workflow runs for the branch:
```bash
gh run list --branch <branch-name> --limit 10 --json name,status,conclusion,databaseId
```

If no runs found, wait 10 seconds and try again once.

If no runs to monitor, skip to Step 6.

If there are in-progress runs to monitor, watch the first one (blocks until complete):
```bash
gh run watch <run-id> --exit-status
```

After runs complete, get final status. Then check for failures:
- If any runs failed: Display "❌ Failed:" with list of failed checks and exit with error
- If all passed: Display "✅ Passed:" with list of successful checks

## Step 6: Generate Slack-friendly summaries

Generate two non-technical summaries based on the PR changes:

1. **One-line**: Single conversational sentence about what was shipped
   - Present tense ("Add bulk updates" not "We added bulk updates")
   - Be specific ("filter by due date" not "find overdue work")
   - Natural language (avoid e.g. "furthermore", "enhanced", "utilize")
2. **Detailed**: One-liner + 2-4 plain-language bullets (same guidelines)

Display format:
```
---
📱 Slack Summary (one-line):
<one-line-summary>

📱 Slack Summary (detailed):
<one-line-summary>
• <bullet-1>
• <bullet-2>

🔗 PR: <pr-url>
```
