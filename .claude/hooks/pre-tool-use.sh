#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // ""')

if echo "$COMMAND" | grep -qE 'git -C '; then
  echo "Do not use 'git -C'. Current working directory is: $PWD. If you need a different directory, use 'cd' first in a separate Bash call." >&2
  exit 2
fi

exit 0
