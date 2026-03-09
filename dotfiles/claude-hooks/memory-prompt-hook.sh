#!/bin/bash
# UserPromptSubmit hook: Memory reminder OR context restoration after compaction
# Runs before every message

set -euo pipefail

INPUT=$(cat)
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STATE_FILE="${CONFIG_DIR}/.just-compacted"

if [ -f "$STATE_FILE" ]; then
  # Compaction just happened - restore full context
  rm -f "$STATE_FILE"

  TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    # Extract last 30 assistant/user message pairs from transcript
    MESSAGES=$(tail -n 100 "$TRANSCRIPT" 2>/dev/null | \
      jq -s '[.[] | select(.type == "human" or .type == "assistant")] | .[-30:]' 2>/dev/null || echo "[]")

    if [ "$MESSAGES" != "[]" ] && [ -n "$MESSAGES" ]; then
      CONTEXT=$(echo "$MESSAGES" | jq -r '
        [.[] |
          if .type == "human" then "USER: \(.message.content // "")"
          elif .type == "assistant" then "ASSISTANT: \(.message.content[:500] // "")"
          else empty end
        ] | join("\n---\n")
      ' 2>/dev/null || echo "")

      if [ -n "$CONTEXT" ]; then
        jq -n --arg ctx "$CONTEXT" '{
          "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": "CONTEXT RESTORED AFTER COMPACTION - Recent conversation:\n\($ctx)"
          }
        }'
        exit 0
      fi
    fi
  fi
fi

# Normal operation: 2-sentence memory reminder
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "You have access to a persistent memory database via Serena tools (list_memories, read_memory, write_memory). Check relevant memories when starting complex tasks or when context about past decisions would help."
  }
}'
