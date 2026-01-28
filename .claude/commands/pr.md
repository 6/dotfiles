---
description: Create PR and monitor CI
---

You are a GitHub PR automation assistant. If the user provided text after `/pr`, use it as guidance.

**Avoid compound bash commands** (e.g., `VAR=$(cmd)`, `cmd1 && cmd2`) - these trigger user approval dialogs. Run simple commands separately; you can reference previous output from context.

## Step 1: Commit uncommitted changes

```bash
git status --porcelain
```

If empty, skip to Step 2.

**If on main/master, create a branch first:**
```bash
git add -A
git diff --cached --stat
```
Generate branch name as `update-{largest-changed-filename}` (without extension). Create it:
```bash
git checkout -b <branch-name>
```

**Commit:**
```bash
git diff --cached --stat
```

Generate commit message describing changes. End with:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

```bash
git commit -m "<message>"
```

If commit fails with "gitleaks": Show error. Only retry with `--no-verify` if you're certain it's a false positive (e.g., example API key in docs, test fixture). If it could be a real secret, exit and tell user to fix manually. When in doubt, ask the user.

Never use `--amend` or force push after pushing. Make new commits to fix CI failures.

## Step 2: Push branch

Get current branch:
```bash
git branch --show-current
```

Get main branch name:
```bash
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"
```

Push branch:
```bash
git push -u origin <branch-name>
```

## Step 3: Check for existing PR

```bash
gh pr view --json number,body,title,url 2>/dev/null
```

## Step 4: Generate PR content

Get diff against main:
```bash
git diff <main-branch>...HEAD --stat
git diff <main-branch>...HEAD --name-only
```

**IMPORTANT:** Ignore individual commit messages. Only describe the NET diff from main - the final state a reviewer will see. Intermediate fix commits (e.g., "fix typo", "address review") are invisible to reviewers and must not appear in the description.

**For new PRs:**
- **Title:** Concise summary (≤50 chars)
- **Summary**: 1-2 sentences (what/why)
- **Changes**: 2-4 technical bullets (max 4 - consolidate if needed)

**For existing PRs - be conservative:**
1. **First, read the existing body** from Step 3's `gh pr view` output - this is your starting point
2. **PRESERVE all existing content** unless now factually wrong (e.g., a feature was later deleted) - the user may have manually edited the description
3. **Only APPEND new bullets** for features/changes not already covered by existing bullets
4. **Consolidate if >4 bullets** - merge related items rather than exceeding the limit
5. Update title only if meaningfully inaccurate
6. Never describe intermediate fixes as changes - they don't exist from reviewer's perspective

**Guidelines:**
- Never include secrets, credentials, or PII. When in doubt, ask user.
- **Never add testing/linting bullets** unless that's the PR's sole focus - tests are expected, not noteworthy

## Step 5: Create or update PR

```bash
gh pr create --draft --title "<title>" --body "<body>" 2>&1
```

If "already exists", update via API (do not use `gh pr edit` - fails with fine-grained PATs):
```bash
gh api repos/{owner}/{repo}/pulls/{number} -X PATCH -f body="<body>"
```

## Step 6: Monitor CI

```bash
sleep 10
gh run list --branch <branch-name> --limit 10 --json name,status,conclusion,databaseId
```

If no runs, wait 10s and retry once. If still none, skip to Step 7.

For each in-progress run:
```bash
gh run watch <run-id> --exit-status
```

Ignore "403 Forbidden" warnings about annotations - pass/fail status still works.

After completion:
- Any failures: "❌ Failed:" + list, exit with error
- All passed: "✅ Passed:" + list

## Step 7: Slack summary

Output the PR title and description for easy copy/paste:
```
---
📱 Slack Summary:
<PR title>

<PR body>

🔗 PR: <url>
```
