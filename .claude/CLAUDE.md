For GitHub URLs, use `gh` CLI commands (e.g., `gh pr view <url>`) instead of WebFetch for authenticated access to private repos.

When in a JS/TS repo, determine preferred package manager by checking for `pnpm-lock.yaml` (pnpm), `yarn.lock` (yarn), or `package-lock.json` (npm).

Do NOT use `git -C` when the working directory is already the target repo (this will be true nearly all the time). Just run git commands directly. Only use `git -C` if you genuinely need to operate on a different repository.

NEVER git amend/force push unless explicitly instructed to do so.
