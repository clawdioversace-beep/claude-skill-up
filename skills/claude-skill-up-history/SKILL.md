---
name: claude-skill-up-history
description: Show claude-skill-up command usage history and completed quests. ALWAYS run the bash command immediately when invoked — do not skip, do not summarize from memory, always re-execute.
user_invocable: true
license: MIT
metadata:
  author: clawdioversace
  version: "1.0"
  repo: https://github.com/clawdioversace-beep/claude-skill-up
---

# claude-skill-up-history

**IMPORTANT**: Every invocation MUST re-run the bash command fresh. Never use cached output.

Show command usage stats and completed quests. Run:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_history
```

Display the output showing commands sorted by usage frequency and all completed quests marked with [x].
