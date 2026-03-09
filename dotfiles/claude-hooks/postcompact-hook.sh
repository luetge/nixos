#!/bin/bash
# SessionStart hook (compact matcher): Mark that compaction just happened
# The UserPromptSubmit hook will detect this flag and restore context

set -euo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STATE_FILE="${CONFIG_DIR}/.just-compacted"

# Create the flag file so UserPromptSubmit knows to restore context
touch "$STATE_FILE"

# Exit cleanly
exit 0
