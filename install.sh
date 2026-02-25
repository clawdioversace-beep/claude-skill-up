#!/usr/bin/env bash
# claude-skill-up installer
# One-line install: curl -sSL https://raw.githubusercontent.com/clawdioversace/claude-skill-up/main/install.sh | bash

set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILL_INSTALL_DIR="$CLAUDE_DIR/skills/claude-skill-up"
SKILL_INSTALL_DIR_STATUS="$CLAUDE_DIR/skills/claude-skill-up-status"
SKILL_INSTALL_DIR_SHARE="$CLAUDE_DIR/skills/claude-skill-up-share"
SKILL_INSTALL_DIR_HISTORY="$CLAUDE_DIR/skills/claude-skill-up-history"
HOOK_INSTALL_DIR="$CLAUDE_DIR/hooks/claude-skill-up"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║     claude-skill-up installer        ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════╝${NC}"
echo ""

# Check for Claude Code
if [[ ! -d "$CLAUDE_DIR" ]]; then
  echo "Error: Claude Code directory not found at $CLAUDE_DIR"
  echo "Install Claude Code first: https://claude.ai/code"
  exit 1
fi

# Check for jq or python3
if ! command -v jq &>/dev/null && ! command -v python3 &>/dev/null; then
  echo "Error: jq or python3 required. Install jq: brew install jq"
  exit 1
fi

# Determine source directory
SOURCE_DIR=""
if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
  SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# If piped from curl, clone to temp dir
if [[ -z "$SOURCE_DIR" || ! -f "$SOURCE_DIR/lib/engine.sh" ]]; then
  echo "Downloading claude-skill-up..."
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT
  if command -v git &>/dev/null; then
    git clone --depth 1 https://github.com/clawdioversace/claude-skill-up.git "$TEMP_DIR/claude-skill-up" 2>/dev/null
    SOURCE_DIR="$TEMP_DIR/claude-skill-up"
  else
    echo "Error: git is required for remote install"
    exit 1
  fi
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$SKILL_INSTALL_DIR"
mkdir -p "$SKILL_INSTALL_DIR_STATUS"
mkdir -p "$SKILL_INSTALL_DIR_SHARE"
mkdir -p "$SKILL_INSTALL_DIR_HISTORY"
mkdir -p "$HOOK_INSTALL_DIR/data"
mkdir -p "$HOOK_INSTALL_DIR/lib"

# Copy files
echo -e "${YELLOW}Copying files...${NC}"
cp "$SOURCE_DIR/skills/claude-skill-up/SKILL.md" "$SKILL_INSTALL_DIR/SKILL.md"
cp "$SOURCE_DIR/skills/claude-skill-up-status/SKILL.md" "$SKILL_INSTALL_DIR_STATUS/SKILL.md"
cp "$SOURCE_DIR/skills/claude-skill-up-share/SKILL.md" "$SKILL_INSTALL_DIR_SHARE/SKILL.md"
cp "$SOURCE_DIR/skills/claude-skill-up-history/SKILL.md" "$SKILL_INSTALL_DIR_HISTORY/SKILL.md"
cp "$SOURCE_DIR/hooks/tracker.sh" "$HOOK_INSTALL_DIR/tracker.sh"
cp "$SOURCE_DIR/hooks/session-start.sh" "$HOOK_INSTALL_DIR/session-start.sh"
cp "$SOURCE_DIR/hooks/session-end.sh" "$HOOK_INSTALL_DIR/session-end.sh"
cp "$SOURCE_DIR/hooks/precompact.sh" "$HOOK_INSTALL_DIR/precompact.sh"
cp "$SOURCE_DIR/data/quests.json" "$HOOK_INSTALL_DIR/data/quests.json"
cp "$SOURCE_DIR/data/achievements.json" "$HOOK_INSTALL_DIR/data/achievements.json"
cp "$SOURCE_DIR/lib/engine.sh" "$HOOK_INSTALL_DIR/lib/engine.sh"

# Make scripts executable
chmod +x "$HOOK_INSTALL_DIR/tracker.sh"
chmod +x "$HOOK_INSTALL_DIR/session-start.sh"
chmod +x "$HOOK_INSTALL_DIR/session-end.sh"
chmod +x "$HOOK_INSTALL_DIR/precompact.sh"
chmod +x "$HOOK_INSTALL_DIR/lib/engine.sh"

# Register hooks in settings.json
echo -e "${YELLOW}Registering hooks...${NC}"

register_hooks() {
  if command -v jq &>/dev/null; then
    # Use jq for reliable JSON manipulation
    local tmp
    tmp=$(mktemp)

    # Ensure hooks object exists
    if ! jq -e '.hooks' "$SETTINGS_FILE" &>/dev/null; then
      jq '. + {"hooks": {}}' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
      tmp=$(mktemp)
    fi

    # Add SessionStart hook
    jq --arg cmd "$HOOK_INSTALL_DIR/session-start.sh" '
      .hooks.SessionStart = (.hooks.SessionStart // []) +
      [{"matcher": "", "hooks": [{"type": "command", "command": $cmd, "timeout": 10}]}]
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    tmp=$(mktemp)

    # Add UserPromptSubmit hook (sync — needs to read stdin)
    jq --arg cmd "$HOOK_INSTALL_DIR/tracker.sh" '
      .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // []) +
      [{"matcher": "", "hooks": [{"type": "command", "command": $cmd, "timeout": 10}]}]
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    tmp=$(mktemp)

    # Add PreCompact hook (tracks /compact usage)
    jq --arg cmd "$HOOK_INSTALL_DIR/precompact.sh" '
      .hooks.PreCompact = (.hooks.PreCompact // []) +
      [{"matcher": "", "hooks": [{"type": "command", "command": $cmd, "timeout": 10}]}]
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    tmp=$(mktemp)

    # Add SessionEnd hook
    jq --arg cmd "$HOOK_INSTALL_DIR/session-end.sh" '
      .hooks.SessionEnd = (.hooks.SessionEnd // []) +
      [{"matcher": "", "hooks": [{"type": "command", "command": $cmd, "timeout": 10, "async": true}]}]
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"

  else
    # Fallback: python3
    python3 << PYEOF
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

# SessionStart
hooks.setdefault('SessionStart', []).append({
    "matcher": "",
    "hooks": [{"type": "command", "command": "$HOOK_INSTALL_DIR/session-start.sh", "timeout": 10}]
})

# UserPromptSubmit
hooks.setdefault('UserPromptSubmit', []).append({
    "matcher": "",
    "hooks": [{"type": "command", "command": "$HOOK_INSTALL_DIR/tracker.sh", "timeout": 10, "async": True}]
})

# SessionEnd
hooks.setdefault('SessionEnd', []).append({
    "matcher": "",
    "hooks": [{"type": "command", "command": "$HOOK_INSTALL_DIR/session-end.sh", "timeout": 10, "async": True}]
})

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
  fi
}

# Backup settings first
cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
register_hooks

# Initialize state
echo -e "${YELLOW}Initializing state...${NC}"
source "$HOOK_INSTALL_DIR/lib/engine.sh"
init_state
init_config
generate_daily_quests

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║    Installation complete!            ║${NC}"
echo -e "${GREEN}  ╠══════════════════════════════════════╣${NC}"
echo -e "${GREEN}  ║                                      ║${NC}"
echo -e "${GREEN}  ║  Restart Claude Code, then type:        ║${NC}"
echo -e "${GREEN}  ║    /claude-skill-up  — today's quests  ║${NC}"
echo -e "${GREEN}  ║                                      ║${NC}"
echo -e "${GREEN}  ║  You're using 20% of Claude Code.    ║${NC}"
echo -e "${GREEN}  ║  This skill shows you the other 80%. ║${NC}"
echo -e "${GREEN}  ║                                      ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════╝${NC}"
echo ""
