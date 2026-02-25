# claude-skill-up

**You're using 20% of Claude Code. This skill shows you the other 80%.**

Gamified discovery of Claude Code's /commands. Daily quests, XP, streaks, and achievements that teach you the features you've been missing.

## Install

```bash
git clone https://github.com/clawdioversace/claude-skill-up.git
cd claude-skill-up
bash install.sh
```

Then restart Claude Code and type `/skill-up`.

## Commands

| Command | What it does |
|---------|-------------|
| `/skill-up` | Today's 3 quests + progress |
| `/skill-up:status` | Full dashboard with achievements |
| `/skill-up:share` | Shareable ASCII stat card |
| `/skill-up:history` | Command usage stats + completed quests |

## How It Works

Three hooks run automatically in the background:

- **Session start**: Generates 3 daily quests targeting commands you haven't used yet
- **Every prompt**: Detects /command usage and completes matching quests
- **Session end**: Shows brief progress summary

All data stays local in `~/.claude/hooks/claude-skill-up/state.json`. No network calls. No telemetry.

## Quest Tiers

| Tier | Commands | XP Range |
|------|----------|----------|
| Basics | /clear, /compact, /help, /status, /vim, /cost | 25-75 |
| Workflow | /fork, /memory, /review, /init, /resume, /model | 75-100 |
| Power User | /install, /permissions, /fast, /config | 100-150 |
| Mastery | Custom commands, hooks, MCP servers, multi-model | 200-300 |

## Levels

```
Newbie     (0 XP)     ░░░░░░░░░░
Explorer   (500 XP)   ███░░░░░░░
Power User (2,000 XP) ██████░░░░
Architect  (5,000 XP) █████████░
Legend     (10,000 XP) ██████████
```

## Achievements

14 achievements including: Quest Accepted, On a Roll (3-day streak), Week Warrior (7-day streak), Speed Run (3 quests in one session), Completionist, and more.

## Configuration

Edit `~/.claude/hooks/claude-skill-up/config.json`:

```json
{
  "quests_per_day": 3,
  "show_session_start_message": true,
  "show_session_end_summary": true
}
```

## Uninstall

```bash
cd claude-skill-up
bash uninstall.sh
```

## Requirements

- Claude Code CLI
- `jq` (recommended) or `python3` (fallback)

## License

MIT
