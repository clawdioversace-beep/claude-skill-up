#!/usr/bin/env bash
# claude-skill-up: PreCompact hook
# Fires when user runs /compact — marks the compact quest complete
# MUST complete in <100ms — pure file I/O only

SKILL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up"

# Source engine
source "$SKILL_DIR/lib/engine.sh"

# Initialize state if needed
init_state
init_config

# Record /compact usage and check quests
record_command_use "/compact"
check_achievements >/dev/null 2>&1

exit 0
