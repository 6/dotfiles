---
name: fixpr
description: Fix CI failures and address PR comments
argument-hint: [catchup]
disable-model-invocation: true
---

You are a PR fixing assistant. Your job is to find issues with the current PR and fix them.

**Avoid compound bash commands** (e.g., `VAR=$(cmd)`, `cmd1 && cmd2`) - these trigger user approval dialogs. Run simple commands separately.

## Step 0: Optional catchup

If the user included "catchup" in their command (e.g., `/fixpr catchup`), first run the `/catchup` workflow to gather context about what's been worked on.

## Step 1: Find the PR

```bash
git branch --show-current
```

```bash
gh pr view --json number,title,url 2>/dev/null
```

If no PR exists, inform the user and exit.

## Step 2: Check CI status

```bash
gh pr checks --json name,state,conclusion
```

Also check for recent runs:
```bash
gh run list --branch <branch-name> --limit 5 --json name,status,conclusion,databaseId
```

**If any failures exist:**

For each failed run, get details:
```bash
gh run view <run-id> --log-failed
```

Analyze the failures and fix them. After fixing:
- Run the relevant checks locally (lint, test, build, etc.) to verify the fix
- Commit the fix with a clear message
- Push the changes

## Step 3: Check PR comments

```bash
gh pr view --json comments,reviews --jq '.comments[], .reviews[]'
```

Also check review comments on specific lines:
```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments
```

**IMPORTANT: Comments may be wrong. Analyze carefully and feel free to push back to me if a comment suggests something incorrect or unnecessary. Don't blindly implement all suggestions - use your judgment and ask me if you're unsure.**

For each actionable comment:
1. Evaluate if the suggestion is valid and beneficial
2. If valid: implement the change
3. If questionable: explain your concerns and ask me how to proceed
4. If clearly wrong: explain why and skip it

## Step 4: Summary

After addressing issues, provide a summary:
- What CI failures were fixed (if any)
- What comments were addressed (if any)
- What comments were skipped and why (if any)
- Current CI status

If changes were made, ask if I want to push them.
