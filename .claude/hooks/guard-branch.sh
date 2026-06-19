#!/bin/bash
# Block editing implementation files directly on develop or main

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Only check on implementation files (same scope as roadmap gate)
RELATIVE_BRANCH=$(echo "$FILE_PATH" | sed "s|^${CLAUDE_PROJECT_DIR:-$(pwd)}/||")
if echo "$RELATIVE_BRANCH" | grep -qE '^(src/|prisma/schema\.prisma|Dockerfile|start\.sh)'; then
  BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "main" ]; then
    echo "{\"continue\": false, \"stopReason\": \"🚫 BRANCH GATE: You are on '$BRANCH'. Branch from develop first: git switch develop && git switch -c <type>/description — then open a PR to develop when done.\"}"
  fi
fi
