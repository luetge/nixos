#!/bin/bash
# PreCompact hook: Inject last 30 messages into compaction summary
# This gives the AI more detail to work with during context compression

set -euo pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # Extract recent messages to preserve during compaction
  MESSAGES=$(tail -n 150 "$TRANSCRIPT" 2>/dev/null | \
    jq -s '[.[] | select(.type == "human" or .type == "assistant")] | .[-30:]' 2>/dev/null || echo "[]")

  if [ "$MESSAGES" != "[]" ] && [ -n "$MESSAGES" ]; then
    CONTEXT=$(echo "$MESSAGES" | jq -r '
      [.[] |
        if .type == "human" then
          "USER: \(.message.content // "")"
        elif .type == "assistant" then
          "ASSISTANT: \(.message.content[:1000] // "")"
        else empty end
      ] | join("\n---\n")
    ' 2>/dev/null || echo "")

    if [ -n "$CONTEXT" ]; then
      jq -n --arg ctx "$CONTEXT" '{
        "hookSpecificOutput": {
          "hookEventName": "PreCompact",
          "additionalContext": "IMPORTANT - Preserve these recent conversation details in your summary:\n\($ctx)"
        }
      }'
      exit 0
    fi
  fi
fi

# No transcript or no messages - exit cleanly
exit 0
