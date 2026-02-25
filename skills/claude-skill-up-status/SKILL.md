---
name: claude-skill-up-status
description: Full claude-skill-up dashboard with achievements. ALWAYS run the dashboard bash command immediately when invoked — do not skip, do not summarize from memory, always re-execute.
user_invocable: true
license: MIT
metadata:
  author: clawdioversace
  version: "1.0"
  repo: https://github.com/clawdioversace-beep/claude-skill-up
---

# claude-skill-up-status

**IMPORTANT**: Every invocation MUST re-run the bash commands fresh. Never use cached output.

Show comprehensive stats including achievements.

### Step 1 — Run dashboard:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_dashboard
```

### Step 2 — List achievements:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && check_achievements
```

Display the dashboard output, then list any unlocked achievements.
