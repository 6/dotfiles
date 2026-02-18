#!/bin/bash
input=$(cat)

# Colors
reset="\033[0m"
dim="\033[38;5;245m"  # Gray for separators
blue="\033[34m"
cyan="\033[36m"
magenta="\033[35m"

# Parse JSON fields
model=$(echo "$input" | jq -r '.model.display_name | sub("^Claude "; "")')
compact_model=$(echo "$model" | sed 's/Sonnet/S/;s/Opus/O/;s/Haiku/H/;s/ //g')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
dir_name=$(basename "$project_dir")
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // "0"')
formatted_cost=$(printf "%.2f" "$cost")

# Context window calculation
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
usage=$(echo "$input" | jq '.context_window.current_usage // null')

if [ "$usage" != "null" ]; then
    current_tokens=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    pct=$((current_tokens * 100 / context_size))
else
    current_tokens=0
    pct=0
fi

# Format tokens as "Xk" (thousands)
if [ "$current_tokens" -lt 1000 ]; then
    token_display="${current_tokens}"
elif [ "$current_tokens" -lt 10000 ]; then
    token_display=$(awk "BEGIN {printf \"%.1fk\", $current_tokens/1000}")
else
    token_display="$((current_tokens / 1000))k"
fi

# Color based on percentage (green/yellow/orange)
if [ "$pct" -lt 70 ]; then
    color="38;5;29"    # Green
elif [ "$pct" -lt 85 ]; then
    color="38;5;220"   # Yellow
else
    color="38;5;208"   # Orange
fi
gray="38;5;240"

# Tmux
if [ -n "$TMUX" ]; then
    tmux_session=$(tmux display-message -p '#S' 2>/dev/null)
    is_remote=$(tmux show-environment CC_REMOTE 2>/dev/null | grep -v '^-' | cut -d= -f2)
    tmux_prefix=$(printf "${magenta}📺 %s${reset} ${dim}|${reset} " "$tmux_session")
    compact_tmux_prefix=$(printf "${magenta}%s${reset} ${dim}|${reset} " "$tmux_session")
else
    is_remote=""
    tmux_prefix=""
    compact_tmux_prefix=""
fi

# Build progress bar (5 chars)
bar_width=5
filled=$((pct * bar_width / 100))
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
empty=$((bar_width - filled))

bar=""
for ((i=0; i<filled; i++)); do bar+="█"; done
for ((i=0; i<empty; i++)); do bar+="░"; done

progress_bar=$(printf "\033[%sm%s\033[0m\033[%sm%s\033[0m %s" \
    "$color" "${bar:0:$filled}" "$gray" "${bar:$filled}" "$token_display")

# Git branch
git_part=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        git_part=$(printf " \033[38;5;245m|\033[0m \033[32m🌿 %s\033[0m" "$branch")
    fi
fi

if [ -n "$is_remote" ]; then
  # Compact version for remote:
  printf "${reset}%s%s ${dim}|${reset} ${blue}%s${reset}%s ${dim}|${reset} %s ${dim}|${reset} ${cyan}\$%s${reset}" \
      "$compact_tmux_prefix" "$compact_model" "$dir_name" "$git_part" "$token_display" "$formatted_cost"
else
  # Output: Model | Dir | Git | Progress | Cost
  printf "${reset}%s🤖 %s ${dim}|${reset} ${blue}📁 %s${reset}%s ${dim}|${reset} %s ${dim}|${reset} ${cyan}\$%s${reset}" \
      "$tmux_prefix" "$model" "$dir_name" "$git_part" "$progress_bar" "$formatted_cost"
fi
