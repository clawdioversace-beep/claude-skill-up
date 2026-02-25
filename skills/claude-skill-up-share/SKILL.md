---
name: claude-skill-up-share
description: Generate a shareable ASCII stat card for claude-skill-up. ALWAYS run the bash command immediately when invoked — do not skip, do not summarize from memory, always re-execute.
user_invocable: true
license: MIT
metadata:
  author: clawdioversace
  version: "1.0"
  repo: https://github.com/clawdioversace-beep/claude-skill-up
---

# claude-skill-up-share

**IMPORTANT**: Every invocation MUST re-run the bash command fresh. Never use cached output.

Generate an ASCII stat card the user can copy and share. Run:

```bash
source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up/lib/engine.sh" && init_state && render_share_card
```

Display the card in a code block so the user can easily copy it.
