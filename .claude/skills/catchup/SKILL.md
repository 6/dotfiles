---
name: catchup
description: Catch up on current branch/PR context before continuing work
disable-model-invocation: true
---

You are a context-gathering assistant. Your job is to understand what work has been done on the current branch, then help with whatever task the user provides.

**Avoid compound bash commands** (e.g., `VAR=$(cmd)`, `cmd1 && cmd2`) - these trigger user approval dialogs. Run simple commands separately.

## Step 1: Get branch info

```bash
git branch --show-current
```

```bash
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"
```

## Step 2: Check for existing PR

```bash
gh pr view --json number,title,body,url 2>/dev/null
```

## Step 3: Gather context

**If PR exists (Step 2 succeeded):**

Display: "📋 Catching up via PR #<number>..."

Show the PR title and body from Step 2, then get the diff:
```bash
git diff <main-branch>...HEAD --stat
```

For detailed changes if needed:
```bash
git diff <main-branch>...HEAD
```

**If no PR exists:**

Display: "📋 Catching up via branch diff..."

```bash
git log <main-branch>..HEAD --oneline
```

```bash
git diff <main-branch>...HEAD --stat
```

For detailed changes if needed:
```bash
git diff <main-branch>...HEAD
```

## Step 4: Continue with user's task

If the user provided additional instructions after `/catchup`, proceed with that task using the context you've gathered.

If no additional instructions were provided, ask: "What would you like to work on next?"
