#!/bin/bash
# guard-test-files.sh — Warns when a test or spec file is written.
# /test-writer is the only agent authorised to write these files.
# /coder must never modify test files — it makes tests pass by changing implementation.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if ! echo "$FILE_PATH" | grep -qE '\.(test|spec)\.(ts|tsx|js|jsx)$'; then
  exit 0
fi

RELATIVE=$(echo "$FILE_PATH" | sed "s|^${CLAUDE_PROJECT_DIR:-/workspaces/ldbwebstudio}/||")

echo "⚠️  TEST FILE WRITTEN: ${RELATIVE}"
echo ""
echo "Only /test-writer may create or modify test files."
echo ""
echo "  If you are /coder        → STOP. Your CANNOT rule prohibits touching test files."
echo "                               Make the tests pass by fixing the implementation."
echo "  If you are /test-writer  → This warning is expected. Continue."
