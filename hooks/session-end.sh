#!/usr/bin/env bash
# claude-skill-up: SessionEnd hook
# Shows brief session summary
# MUST complete in <100ms — pure file I/O only

set -euo pipefail

SKILL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up"

# Source engine (skip if state file doesn't exist — user uninstalled mid-session)
[[ ! -f "$SKILL_DIR/lib/engine.sh" ]] && exit 0
source "$SKILL_DIR/lib/engine.sh"

[[ ! -f "$STATE_FILE" ]] && exit 0

# Check if user wants session end summary
if command -v jq &>/dev/null; then
  SHOW_SUMMARY=$(jq -r '.show_session_end_summary // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
else
  SHOW_SUMMARY="true"
fi

[[ "$SHOW_SUMMARY" != "true" && "$SHOW_SUMMARY" != true ]] && exit 0

SESSION_QUESTS=$(read_state ".session_quests_completed")
SESSION_QUESTS=${SESSION_QUESTS:-0}

if (( SESSION_QUESTS > 0 )); then
  XP=$(read_state ".xp")
  STREAK=$(read_state ".streak")
  echo "skill-up session: $SESSION_QUESTS quest(s) completed | ${XP}xp total | ${STREAK}-day streak"
fi

exit 0
