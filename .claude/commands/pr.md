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
git add -A  # if not already staged
git diff --cached --stat
```

Generate commit message describing changes. End with:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
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

If on main/master: exit with "❌ Cannot create PR from main/master. Make changes first so /pr can auto-create a branch."

Check if branch exists on remote:
```bash
git ls-remote --heads origin <branch-name>
```

If not found, push it:
```bash
git push -u origin <branch-name>
```

## Step 3: Generate PR content

Get diff against main:
```bash
git diff <main-branch>...HEAD --stat
git diff <main-branch>...HEAD --name-only
git log <main-branch>..HEAD --pretty=format:"%s"
```

**PR title:** Concise summary of the change (≤50 chars). Base on overall diff, not individual commits.

**PR body has two sections:**
1. **Summary**: 1-2 sentences (what/why)
2. **Changes**: 3-5 technical bullets

**Guidelines:**
- Never include secrets, credentials, or PII. When in doubt, ask user.
- Describe net changes from main, not commit-by-commit history
- Exclude testing/linting bullets unless that's the PR's focus

## Step 4: Create or update PR

```bash
gh pr create --draft --title "<title>" --body "<body>" 2>&1
```

If "already exists": get URL with `gh pr view <branch-name> --json url --jq .url`, then update description.

Do not use `gh pr edit` - it fails with fine-grained PATs. Always use the API:
```bash
gh api repos/{owner}/{repo}/pulls/{number} -X PATCH -f body="<body>"
```

## Step 5: Monitor CI

```bash
sleep 10
gh run list --branch <branch-name> --limit 10 --json name,status,conclusion,databaseId
```

If no runs, wait 10s and retry once. If still none, skip to Step 6.

For each in-progress run:
```bash
gh run watch <run-id> --exit-status
```

Ignore "403 Forbidden" warnings about annotations - pass/fail status still works.

After completion:
- Any failures: "❌ Failed:" + list, exit with error
- All passed: "✅ Passed:" + list, then mark ready (do not use `gh pr ready` - fails with fine-grained PATs):
  ```bash
  gh api repos/{owner}/{repo}/pulls/{number} -X PATCH -f draft=false
  ```

## Step 6: Slack summaries

Generate two non-technical summaries:

1. **One-line**: Single present-tense sentence about what shipped
2. **Detailed**: One-liner + 2-4 plain-language bullets

Output:
```
---
📱 Slack Summary (one-line):
<summary>

📱 Slack Summary (detailed):
<summary>
• <bullet>

🔗 PR: <url>
```
