#!/usr/bin/env bash
# claude-skill-up uninstaller
# Removes all files and unregisters hooks from settings.json

set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILL_INSTALL_DIR="$CLAUDE_DIR/skills/claude-skill-up"
HOOK_INSTALL_DIR="$CLAUDE_DIR/hooks/claude-skill-up"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}Uninstalling claude-skill-up...${NC}"

# Remove hook registrations from settings.json
if [[ -f "$SETTINGS_FILE" ]]; then
  echo "Removing hooks from settings.json..."
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(mktemp)
    jq --arg dir "$HOOK_INSTALL_DIR" '
      .hooks |= (
        if . then
          to_entries | map(
            .value |= [.[] | select(
              (.hooks // []) | all(.command | contains($dir) | not)
            )]
          ) | from_entries
        else .
        end
      )
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  else
    python3 << 'PYEOF'
import json

settings_file = '$SETTINGS_FILE'
hook_dir = '$HOOK_INSTALL_DIR'

with open(settings_file) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
for event in list(hooks.keys()):
    hooks[event] = [
        entry for entry in hooks[event]
        if not any(
            hook_dir in h.get('command', '')
            for h in entry.get('hooks', [])
        )
    ]

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
  fi
fi

# Remove files
echo "Removing skill files..."
rm -rf "$SKILL_INSTALL_DIR"
rm -rf "$HOOK_INSTALL_DIR"

echo ""
echo -e "${GREEN}claude-skill-up uninstalled successfully.${NC}"
echo -e "Settings backup saved at: ${SETTINGS_FILE}.bak"
echo ""
