---
description: Remove AI-generated code slop from current branch
---

Review the diff against main and remove AI-generated slop:

1. Get changed files:
```bash
git diff $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master)...HEAD --name-only
```

2. For each file, identify and remove:
   - Comments that are excessive or inconsistent with the file's existing style
   - Defensive checks or try/catch blocks abnormal for that area (especially on trusted/validated codepaths)
   - Casts to `any` used to work around type issues
   - Any style inconsistent with the surrounding code

3. Output only a 1-3 sentence summary of what you changed.
