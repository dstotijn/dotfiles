#!/usr/bin/env bash
input=$(cat)

eval "$(echo "$input" | jq -r '
  @sh "model=\(.model.display_name)",
  @sh "dir=\(.workspace.current_dir)",
  @sh "used=\(.context_window.used_percentage // empty)",
  @sh "cost=\(.cost.total_cost_usd // empty)"
')"

# Starship handles directory, git branch, dirty state, etc.
# Strip leading clear-screen escape, trailing prompt character (❯), and whitespace
starship_prompt=$(cd "$dir" && starship prompt --status 0 2>/dev/null | tr -d '\n' | sed 's/^\x1b\[J//' | sed 's/\x1b\[[0-9;]*m❯\x1b\[[0-9;]*m *$//' | sed 's/ *$//')

# Context usage with color: green < 50%, yellow < 80%, red >= 80%
ctx=""
if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used")
  if [ "$pct" -ge 80 ]; then
    color="31" # red
  elif [ "$pct" -ge 50 ]; then
    color="33" # yellow
  else
    color="32" # green
  fi
  ctx=" \033[${color}m${pct}%\033[0m"
fi

# Cost
cost_str=""
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
  cost_str=$(printf " \033[2m\$%.2f\033[0m" "$cost")
fi

echo -e "${starship_prompt}${ctx} \033[1m${model}\033[0m${cost_str}"
