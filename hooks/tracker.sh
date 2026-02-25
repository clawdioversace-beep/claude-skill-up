#!/usr/bin/env bash
# claude-skill-up: UserPromptSubmit hook
# Detects /command usage and updates quest state
# MUST complete in <100ms — pure file I/O only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up"

# Source engine
source "$SKILL_DIR/lib/engine.sh"

# Read user input from stdin (Claude Code pipes it as JSON)
INPUT=""
if [[ -p /dev/stdin ]]; then
  INPUT=$(cat)
fi

# Extract the user's prompt from the hook payload
# Claude Code sends JSON: {"sessionId":"...","prompt":"..."}
PROMPT=""
if command -v jq &>/dev/null; then
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
else
  PROMPT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('prompt', ''))
except:
    print('')
" 2>/dev/null || echo "")
fi

[[ -z "$PROMPT" ]] && exit 0

# Detect /command
COMMAND=$(detect_command "$PROMPT")
[[ -z "$COMMAND" ]] && exit 0

# Initialize state if needed
init_state
init_config

# Record command usage
record_command_use "$COMMAND"

# Check achievements after quest completion
check_achievements >/dev/null 2>&1

exit 0
