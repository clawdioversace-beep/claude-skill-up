#!/usr/bin/env bash
# claude-skill-up engine — shared functions for quest tracking, XP, streaks
# All operations are pure file I/O. No network calls. Target: <50ms per operation.

set -euo pipefail

SKILL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-skill-up"
DATA_DIR="$SKILL_DIR/data"
STATE_FILE="$SKILL_DIR/state.json"
CONFIG_FILE="$SKILL_DIR/config.json"

# ─── State Management ─────────────────────────────────────────────

init_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    cat > "$STATE_FILE" << 'EOJSON'
{
  "xp": 0,
  "level": "Newbie",
  "streak": 0,
  "last_active_date": "",
  "quests_completed": [],
  "achievements_unlocked": [],
  "daily_quests": [],
  "daily_quests_date": "",
  "daily_progress": {},
  "session_quests_completed": 0,
  "commands_used": {},
  "total_quests_completed": 0,
  "install_date": ""
}
EOJSON
    # Set install date
    local today
    today=$(date +%Y-%m-%d)
    update_state ".install_date" "\"$today\""
    update_state ".last_active_date" "\"$today\""
  fi
}

init_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOJSON'
{
  "quests_per_day": 3,
  "show_session_start_message": true,
  "show_session_end_summary": true,
  "celebration_style": "ascii"
}
EOJSON
  fi
}

read_state() {
  local key="${1:-.}"
  if command -v jq &>/dev/null; then
    jq -r "$key" "$STATE_FILE" 2>/dev/null || echo ""
  else
    # Fallback: python json
    python3 -c "
import json, sys
with open('$STATE_FILE') as f:
    data = json.load(f)
key = '$key'.lstrip('.')
if key:
    parts = key.split('.')
    for p in parts:
        if isinstance(data, dict):
            data = data.get(p, '')
        else:
            data = ''
            break
print(data if data is not None else '')
" 2>/dev/null || echo ""
  fi
}

update_state() {
  local key="$1"
  local value="$2"
  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(mktemp)
    jq "$key = $value" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  else
    python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
key = '$key'.lstrip('.')
val = json.loads('$value')
parts = key.split('.')
obj = data
for p in parts[:-1]:
    obj = obj.setdefault(p, {})
obj[parts[-1]] = val
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
  fi
}

# ─── Date & Streak ────────────────────────────────────────────────

get_today() {
  date +%Y-%m-%d
}

update_streak() {
  local today last_date streak
  today=$(get_today)
  last_date=$(read_state ".last_active_date")
  streak=$(read_state ".streak")
  streak=${streak:-0}

  if [[ "$last_date" == "$today" ]]; then
    # Already active today, no change
    return
  fi

  # Check if yesterday
  local yesterday
  if [[ "$(uname)" == "Darwin" ]]; then
    yesterday=$(date -v-1d +%Y-%m-%d)
  else
    yesterday=$(date -d "yesterday" +%Y-%m-%d)
  fi

  if [[ "$last_date" == "$yesterday" ]]; then
    streak=$((streak + 1))
  elif [[ -n "$last_date" && "$last_date" != "$today" ]]; then
    streak=1
  else
    streak=1
  fi

  update_state ".streak" "$streak"
  update_state ".last_active_date" "\"$today\""
}

# ─── XP & Level ───────────────────────────────────────────────────

add_xp() {
  local amount="$1"
  local current
  current=$(read_state ".xp")
  current=${current:-0}
  local new_xp=$((current + amount))
  update_state ".xp" "$new_xp"
  compute_level "$new_xp" >/dev/null
}

compute_level() {
  local xp="${1:-0}"
  local level
  if (( xp >= 10000 )); then
    level="Legend"
  elif (( xp >= 5000 )); then
    level="Architect"
  elif (( xp >= 2000 )); then
    level="Power User"
  elif (( xp >= 500 )); then
    level="Explorer"
  else
    level="Newbie"
  fi
  update_state ".level" "\"$level\""
  echo "$level"
}

get_level_progress() {
  local xp
  xp=$(read_state ".xp")
  xp=${xp:-0}
  local next_threshold current_threshold

  if (( xp >= 10000 )); then
    echo "MAX"
    return
  elif (( xp >= 5000 )); then
    current_threshold=5000
    next_threshold=10000
  elif (( xp >= 2000 )); then
    current_threshold=2000
    next_threshold=5000
  elif (( xp >= 500 )); then
    current_threshold=500
    next_threshold=2000
  else
    current_threshold=0
    next_threshold=500
  fi

  local progress=$(( (xp - current_threshold) * 100 / (next_threshold - current_threshold) ))
  echo "$progress"
}

# ─── Quest Selection ──────────────────────────────────────────────

generate_daily_quests() {
  local today
  today=$(get_today)
  local quest_date
  quest_date=$(read_state ".daily_quests_date")

  if [[ "$quest_date" == "$today" ]]; then
    return 0  # Already generated today
  fi

  # Reset session counter
  update_state ".session_quests_completed" "0"

  # Get completed quests
  local completed
  if command -v jq &>/dev/null; then
    completed=$(jq -r '.quests_completed[]' "$STATE_FILE" 2>/dev/null | tr '\n' '|')
  else
    completed=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
print('|'.join(data.get('quests_completed', [])))
" 2>/dev/null)
  fi

  # Select 3 quests, prioritizing uncompleted ones
  local selected
  if command -v jq &>/dev/null; then
    selected=$(jq -r --arg completed "$completed" '
      [.tiers[].quests[]] |
      [.[] | select(.id as $id | ($completed | split("|") | map(select(. == $id)) | length) == 0)] |
      if length == 0 then [.tiers[].quests[]] | . else . end |
      .[0:3] | .[].id
    ' "$DATA_DIR/quests.json" 2>/dev/null | head -3)
  else
    selected=$(python3 -c "
import json, random
with open('$DATA_DIR/quests.json') as f:
    qdata = json.load(f)
completed = set('$completed'.split('|'))
uncompleted = []
all_quests = []
for tier in qdata['tiers'].values():
    for q in tier['quests']:
        all_quests.append(q['id'])
        if q['id'] not in completed:
            uncompleted.append(q['id'])
pool = uncompleted if uncompleted else all_quests
random.shuffle(pool)
for qid in pool[:3]:
    print(qid)
" 2>/dev/null)
  fi

  # Build JSON array of selected quest IDs
  local quest_array="["
  local first=true
  while IFS= read -r qid; do
    [[ -z "$qid" ]] && continue
    if [[ "$first" == "true" ]]; then
      quest_array+="\"$qid\""
      first=false
    else
      quest_array+=",\"$qid\""
    fi
  done <<< "$selected"
  quest_array+="]"

  update_state ".daily_quests" "$quest_array"
  update_state ".daily_quests_date" "\"$today\""
  update_state ".daily_progress" "{}"

  return 1  # New quests generated
}

# ─── Command Detection ────────────────────────────────────────────

detect_command() {
  local input="$1"
  # Extract the /command from user input
  if [[ "$input" =~ ^/([a-zA-Z_-]+) ]]; then
    echo "/${BASH_REMATCH[1]}"
  fi
}

record_command_use() {
  local command="$1"

  # Increment command counter
  local count
  count=$(read_state ".commands_used.\"$command\"" 2>/dev/null)
  count=${count:-0}
  [[ "$count" == "null" ]] && count=0
  count=$((count + 1))
  update_state ".commands_used.\"$command\"" "$count" 2>/dev/null

  # Check if this completes any daily quest (capture output, only emit QUEST_COMPLETE lines)
  local _output
  _output=$(check_quest_completion "$command" 2>/dev/null) || true
  if [[ -n "$_output" ]]; then
    echo "$_output" | grep "^QUEST_COMPLETE:" || true
  fi
}

check_quest_completion() {
  local command="$1"

  # Get today's quests
  local daily_quests
  if command -v jq &>/dev/null; then
    daily_quests=$(jq -r '.daily_quests[]' "$STATE_FILE" 2>/dev/null)
  else
    daily_quests=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
for q in data.get('daily_quests', []):
    print(q)
" 2>/dev/null)
  fi

  # Check each daily quest
  while IFS= read -r quest_id; do
    [[ -z "$quest_id" ]] && continue

    # Already completed today?
    local already_done
    already_done=$(read_state ".daily_progress.\"$quest_id\"")
    [[ "$already_done" == "true" ]] && continue

    # Get quest command from data
    local quest_command
    if command -v jq &>/dev/null; then
      quest_command=$(jq -r --arg qid "$quest_id" '
        [.tiers[].quests[] | select(.id == $qid)] | .[0].command // ""
      ' "$DATA_DIR/quests.json" 2>/dev/null)
    else
      quest_command=$(python3 -c "
import json
with open('$DATA_DIR/quests.json') as f:
    qdata = json.load(f)
for tier in qdata['tiers'].values():
    for q in tier['quests']:
        if q['id'] == '$quest_id':
            print(q['command'])
            exit()
" 2>/dev/null)
    fi

    if [[ "$command" == "$quest_command" ]]; then
      # Quest completed!
      update_state ".daily_progress.\"$quest_id\"" "true"

      # Add to completed list if first time
      local already_ever
      if command -v jq &>/dev/null; then
        already_ever=$(jq -r --arg qid "$quest_id" '.quests_completed | map(select(. == $qid)) | length' "$STATE_FILE" 2>/dev/null)
      else
        already_ever=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
print(1 if '$quest_id' in data.get('quests_completed', []) else 0)
" 2>/dev/null)
      fi

      local xp_amount=25  # Repeated quest
      if [[ "$already_ever" == "0" ]]; then
        # First time completing this quest
        if command -v jq &>/dev/null; then
          local tmp
          tmp=$(mktemp)
          jq --arg qid "$quest_id" '.quests_completed += [$qid]' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        else
          python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
data.setdefault('quests_completed', []).append('$quest_id')
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
        fi

        # Get quest XP value
        local quest_xp
        if command -v jq &>/dev/null; then
          quest_xp=$(jq -r --arg qid "$quest_id" '
            [.tiers[].quests[] | select(.id == $qid)] | .[0].xp // 50
          ' "$DATA_DIR/quests.json" 2>/dev/null)
        else
          quest_xp=100
        fi
        xp_amount=$quest_xp
      fi

      add_xp "$xp_amount"

      # Increment counters
      local total
      total=$(read_state ".total_quests_completed")
      total=${total:-0}
      update_state ".total_quests_completed" "$((total + 1))"

      local session_count
      session_count=$(read_state ".session_quests_completed")
      session_count=${session_count:-0}
      update_state ".session_quests_completed" "$((session_count + 1))"

      # Update streak
      update_streak

      echo "QUEST_COMPLETE:$quest_id:$xp_amount"
      return 0
    fi
  done <<< "$daily_quests"

  return 1
}

# ─── Rendering ────────────────────────────────────────────────────

render_progress_bar() {
  local percent="${1:-0}"
  local width="${2:-20}"
  local filled=$((percent * width / 100))
  local empty=$((width - filled))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  echo "$bar"
}

render_dashboard() {
  local xp level streak total_quests progress daily_date
  xp=$(read_state ".xp")
  level=$(read_state ".level")
  streak=$(read_state ".streak")
  total_quests=$(read_state ".total_quests_completed")
  progress=$(get_level_progress)
  daily_date=$(read_state ".daily_quests_date")

  xp=${xp:-0}
  level=${level:-Newbie}
  streak=${streak:-0}
  total_quests=${total_quests:-0}

  local bar
  if [[ "$progress" == "MAX" ]]; then
    bar=$(render_progress_bar 100)
  else
    bar=$(render_progress_bar "$progress")
  fi

  cat << EOF

  ╔══════════════════════════════════════╗
  ║        claude-skill-up               ║
  ╠══════════════════════════════════════╣
  ║  Level: $level
  ║  XP: $xp  $bar
  ║  Streak: $streak day(s)
  ║  Quests completed: $total_quests
  ╠══════════════════════════════════════╣
  ║  Today's Quests:
EOF

  # Render daily quests
  local daily_quests
  if command -v jq &>/dev/null; then
    daily_quests=$(jq -r '.daily_quests[]' "$STATE_FILE" 2>/dev/null)
  else
    daily_quests=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
for q in data.get('daily_quests', []):
    print(q)
" 2>/dev/null)
  fi

  while IFS= read -r quest_id; do
    [[ -z "$quest_id" ]] && continue

    local done_today=""
    done_today=$(read_state ".daily_progress.\"$quest_id\"" 2>/dev/null || true)
    [[ "$done_today" == "null" ]] && done_today=""

    local quest_title="" quest_hint=""
    if command -v jq &>/dev/null; then
      quest_title=$(jq -r --arg qid "$quest_id" '
        [.tiers[].quests[] | select(.id == $qid)] | .[0].title // "Unknown"
      ' "$DATA_DIR/quests.json" 2>/dev/null || echo "Unknown")
      quest_hint=$(jq -r --arg qid "$quest_id" '
        [.tiers[].quests[] | select(.id == $qid)] | .[0].hint // ""
      ' "$DATA_DIR/quests.json" 2>/dev/null || echo "")
    else
      quest_title=$(python3 -c "
import json
with open('$DATA_DIR/quests.json') as f:
    qdata = json.load(f)
for tier in qdata['tiers'].values():
    for q in tier['quests']:
        if q['id'] == '$quest_id':
            print(q['title'])
            exit()
print('Unknown')
" 2>/dev/null || echo "Unknown")
      quest_hint=""
    fi

    if [[ "$done_today" == "true" ]]; then
      echo "  ║  [x] $quest_title"
    else
      echo "  ║  [ ] $quest_title — $quest_hint"
    fi
  done <<< "$daily_quests"

  cat << EOF
  ╚══════════════════════════════════════╝

EOF
}

render_share_card() {
  local xp level streak total_quests install_date
  xp=$(read_state ".xp")
  level=$(read_state ".level")
  streak=$(read_state ".streak")
  total_quests=$(read_state ".total_quests_completed")
  install_date=$(read_state ".install_date")

  local completed_count
  if command -v jq &>/dev/null; then
    completed_count=$(jq '.quests_completed | length' "$STATE_FILE" 2>/dev/null)
  else
    completed_count=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
print(len(data.get('quests_completed', [])))
" 2>/dev/null)
  fi

  local total_available=23  # Total quests in pool

  cat << EOF

  ┌─────────────────────────────────────┐
  │  claude-skill-up                    │
  │  ─────────────────────────────────  │
  │  Level: $level                      │
  │  XP: $xp                           │
  │  Streak: $streak days               │
  │  Quests: $completed_count / $total_available unlocked        │
  │  Since: $install_date               │
  │                                     │
  │  github.com/clawdioversace/         │
  │          claude-skill-up            │
  └─────────────────────────────────────┘

EOF
}

render_history() {
  echo ""
  echo "  Command Usage History"
  echo "  ─────────────────────"

  if command -v jq &>/dev/null; then
    jq -r '.commands_used | to_entries | sort_by(-.value) | .[] | "  \(.key): \(.value) times"' "$STATE_FILE" 2>/dev/null
  else
    python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
cmds = data.get('commands_used', {})
for k, v in sorted(cmds.items(), key=lambda x: -x[1]):
    print(f'  {k}: {v} times')
" 2>/dev/null
  fi

  echo ""
  echo "  Completed Quests"
  echo "  ────────────────"

  if command -v jq &>/dev/null; then
    # Use jq to join state + quest data and output formatted lines directly
    jq -r --slurpfile quests "$DATA_DIR/quests.json" '
      .quests_completed[] as $qid |
      ($quests[0].tiers | to_entries[].value.quests[] | select(.id == $qid) | .title) // "Unknown" |
      "  [x] \(.)"
    ' "$STATE_FILE" 2>/dev/null || true
  else
    python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
with open('$DATA_DIR/quests.json') as f:
    qdata = json.load(f)
quest_map = {}
for tier in qdata['tiers'].values():
    for q in tier['quests']:
        quest_map[q['id']] = q['title']
for qid in state.get('quests_completed', []):
    title = quest_map.get(qid, 'Unknown')
    print(f'  [x] {title}')
" 2>/dev/null
  fi

  echo ""
}

# ─── Achievement Checking ─────────────────────────────────────────

check_achievements() {
  local xp streak total_quests session_quests
  xp=$(read_state ".xp")
  streak=$(read_state ".streak")
  total_quests=$(read_state ".total_quests_completed")
  session_quests=$(read_state ".session_quests_completed")

  xp=${xp:-0}; streak=${streak:-0}; total_quests=${total_quests:-0}; session_quests=${session_quests:-0}

  local unlocked
  if command -v jq &>/dev/null; then
    unlocked=$(jq -r '.achievements_unlocked[]' "$STATE_FILE" 2>/dev/null | tr '\n' '|')
  else
    unlocked=""
  fi

  local new_achievements=()

  # Simple achievement checks
  if [[ "$unlocked" != *"first-quest"* ]] && (( total_quests >= 1 )); then new_achievements+=("first-quest"); fi
  if [[ "$unlocked" != *"streak-3"* ]] && (( streak >= 3 )); then new_achievements+=("streak-3"); fi
  if [[ "$unlocked" != *"streak-7"* ]] && (( streak >= 7 )); then new_achievements+=("streak-7"); fi
  if [[ "$unlocked" != *"streak-30"* ]] && (( streak >= 30 )); then new_achievements+=("streak-30"); fi
  if [[ "$unlocked" != *"ten-quests"* ]] && (( total_quests >= 10 )); then new_achievements+=("ten-quests"); fi
  if [[ "$unlocked" != *"speed-run"* ]] && (( session_quests >= 3 )); then new_achievements+=("speed-run"); fi

  # Unlock new achievements
  local ach_tmp ach_bonus ach_title
  for ach_id in "${new_achievements[@]}"; do
    if command -v jq &>/dev/null; then
      ach_tmp=$(mktemp)
      jq --arg aid "$ach_id" '.achievements_unlocked += [$aid]' "$STATE_FILE" > "$ach_tmp" && mv "$ach_tmp" "$STATE_FILE"

      # Get XP bonus and title
      ach_bonus=$(jq -r --arg aid "$ach_id" '.achievements[] | select(.id == $aid) | .xp_bonus' "$DATA_DIR/achievements.json" 2>/dev/null || echo "0")
      ach_title=$(jq -r --arg aid "$ach_id" '.achievements[] | select(.id == $aid) | .title' "$DATA_DIR/achievements.json" 2>/dev/null || echo "Unknown")

      if [[ -n "$ach_bonus" && "$ach_bonus" != "null" && "$ach_bonus" != "0" ]]; then
        add_xp "$ach_bonus"
      fi

      echo "ACHIEVEMENT:$ach_id:$ach_title:${ach_bonus:-0}"
    fi
  done
}
