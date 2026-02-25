#!/usr/bin/env bash
# claude-skill-up: SessionStart hook
# Generates daily quests and shows brief status message
# MUST complete in <100ms — pure file I/O only

set -euo pipefail

SKILL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up"

# Source engine
source "$SKILL_DIR/lib/engine.sh"

# Initialize state and config
init_state
init_config

# Check if user wants session start messages
SHOW_MSG=$(read_state ".show_session_start_message" < "$CONFIG_FILE" 2>/dev/null || echo "true")
# Actually read from config
if command -v jq &>/dev/null; then
  SHOW_MSG=$(jq -r '.show_session_start_message // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
fi

# Generate daily quests (returns 1 if new quests generated)
generate_daily_quests
NEW_QUESTS=$?

# Update streak
update_streak

if [[ "$SHOW_MSG" == "true" || "$SHOW_MSG" == true ]]; then
  STREAK=$(read_state ".streak")
  LEVEL=$(read_state ".level")
  XP=$(read_state ".xp")
  STREAK=${STREAK:-0}
  LEVEL=${LEVEL:-Newbie}
  XP=${XP:-0}

  # Get today's quests count
  QUEST_COUNT=0
  COMPLETED_COUNT=0
  if command -v jq &>/dev/null; then
    QUEST_COUNT=$(jq '.daily_quests | length' "$STATE_FILE" 2>/dev/null || echo 0)
    COMPLETED_COUNT=$(jq '[.daily_progress | to_entries[] | select(.value == true)] | length' "$STATE_FILE" 2>/dev/null || echo 0)
  fi

  # Brief one-line status (don't spam the user)
  echo "skill-up: $LEVEL | ${XP}xp | ${STREAK}-day streak | quests: ${COMPLETED_COUNT}/${QUEST_COUNT} today — type /skill-up for details"
fi

exit 0
