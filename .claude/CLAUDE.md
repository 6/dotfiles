For GitHub URLs, use `gh` CLI commands (e.g., `gh pr view <url>`) instead of WebFetch for authenticated access to private repos.

When in a JS/TS repo, determine preferred package manager by checking for `pnpm-lock.yaml` (pnpm), `yarn.lock` (yarn), or `package-lock.json` (npm).

Prefer simple git commands without `-C` flag when already in the working directory.

NEVER git amend/force push unless explicitly instructed to do so.
