---
name: claude-skill-up
description: Gamified Claude Code command discovery. ALWAYS run the dashboard bash command immediately every time the user invokes /claude-skill-up — do not skip, do not summarize from memory, always re-execute. See also /claude-skill-up-status, /claude-skill-up-share, /claude-skill-up-history.
user_invocable: true
license: MIT
metadata:
  author: clawdioversace
  version: "1.0"
  repo: https://github.com/clawdioversace/claude-skill-up
---

# claude-skill-up

Gamified discovery of Claude Code's /commands. Daily quests, XP, streaks, and achievements that teach you what you've been missing.

**IMPORTANT**: Every invocation MUST re-run the bash command fresh. Never use cached output from a previous run — the state file changes between calls (quests get completed, XP changes). Always execute the bash command and display the live output.

## Commands

### `/claude-skill-up` — Today's Quests

ALWAYS run this bash command immediately, every single time:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_dashboard
```

Display the raw output directly to the user. Never skip this step or show previous output. The dashboard reads live from state.json each time so it always reflects current progress.

### Other commands (each is a separate skill):

- `/claude-skill-up-status` — Full dashboard with achievements
- `/claude-skill-up-share` — Shareable ASCII stat card
- `/claude-skill-up-history` — Command usage history + completed quests

## How It Works

claude-skill-up uses Claude Code hooks to passively track which /commands you use:

- **SessionStart hook**: Generates 3 daily quests from a weighted pool (prioritizes commands you haven't tried)
- **UserPromptSubmit hook**: Detects when you use a /command and checks if it completes a quest
- **SessionEnd hook**: Shows a brief session summary

All data is stored locally in `~/.claude/hooks/claude-skill-up/state.json`. No network calls. No telemetry.

## Quest Tiers

- **Basics**: /clear, /compact, /help, /status, /vim, /cost
- **Workflow**: /fork, /memory, /review, /init, /resume, /model
- **Power User**: /install, /permissions, /fast, /terminal-setup, /config
- **Mastery**: Custom commands, hooks, MCP servers, multi-model workflows, skill publishing

## Levels

| Level | XP Required |
|-------|-------------|
| Newbie | 0 |
| Explorer | 500 |
| Power User | 2,000 |
| Architect | 5,000 |
| Legend | 10,000 |

## Configuration

Edit `~/.claude/hooks/claude-skill-up/config.json`:

```json
{
  "quests_per_day": 3,
  "show_session_start_message": true,
  "show_session_end_summary": true,
  "celebration_style": "ascii"
}
```

Set `show_session_start_message` to `false` to disable the session start notification.
