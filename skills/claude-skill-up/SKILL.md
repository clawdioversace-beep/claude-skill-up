---
name: claude-skill-up
description: Gamified Claude Code command discovery. Daily quests, XP, streaks, and achievements that teach you the /commands you've been missing. Use when user types /skill-up, asks about their progress, or wants to see what Claude Code commands they haven't tried yet.
user_invocable: true
license: MIT
metadata:
  author: clawdioversace
  version: "1.0"
  repo: https://github.com/clawdioversace/claude-skill-up
---

# claude-skill-up

Gamified discovery of Claude Code's /commands. Daily quests, XP, streaks, and achievements that teach you what you've been missing.

## Commands

### `/claude-skill-up` — Today's Quests

Show today's 3 quests and current progress. Run this command:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_dashboard
```

Display the output directly to the user. The dashboard shows:
- Current level and XP with progress bar
- Streak count
- Today's 3 quests with completion status ([x] done, [ ] pending)
- Hints for incomplete quests

### `/claude-skill-up:status` — Full Dashboard

Show comprehensive stats including achievements. Run:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_dashboard
```

Then also list unlocked achievements:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && check_achievements
```

Show the dashboard output, then list any achievements. Include:
- Level, XP, streak
- Today's quests
- All unlocked achievements with titles
- Next achievement the user is closest to

### `/claude-skill-up:share` — Shareable Stat Card

Generate an ASCII stat card the user can copy and share. Run:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_share_card
```

Display the card in a code block so the user can easily copy it.

### `/claude-skill-up:history` — Command Usage History

Show the user's command usage stats and completed quests. Run:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_history
```

Display the output showing:
- Commands sorted by usage frequency
- All completed quests marked with [x]

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
