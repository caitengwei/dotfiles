#!/bin/bash

input=$(cat)

# --- Claude Code session data ---
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# --- ANSI colors (matching shell theme: yellow prompt, blue git, green time) ---
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

SEP="·"

# --- Shell-theme-derived: directory (like %~ in RPROMPT) ---
dir_info=""
if [ -n "$cwd" ]; then
    # Abbreviate $HOME to ~
    home_escaped=$(printf '%s\n' "$HOME" | sed 's/[[\.*^$()+?{|]/\\&/g')
    short_dir=$(echo "$cwd" | sed "s|^${home_escaped}|~|")
    dir_info=$(printf "${YELLOW}%s${RESET}" "$short_dir")
fi

# --- Shell-theme-derived: git branch (like git_super_status in RPROMPT) ---
git_info=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_info=$(printf "${BLUE}%s${RESET}" "$branch")
    fi
fi

# --- Shell-theme-derived: time (like %* in RPROMPT) ---
time_info=$(printf "${GREEN}%s${RESET}" "$(date +%H:%M:%S)")

# --- Agent name ---
agent_indicator=""
[ -n "$agent_name" ] && agent_indicator=$(printf "${CYAN}[%s]${RESET}" "$agent_name")

# --- Context remaining ---
context_info=""
if [ -n "$remaining" ]; then
    remaining_int=$(printf "%.0f" "$remaining")
    context_info="${remaining_int}%"
fi

# --- Model name ---
model_info=""
[ -n "$model" ] && model_info="$model"

# --- Cost ---
cost_info=""
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
    cost_info=$(printf "\$%.1f" "$cost")
fi

# --- Tokens ---
token_info=""
if [ -n "$input_tokens" ]; then
    in_k=$(awk "BEGIN {printf \"%.1f\", $input_tokens / 1000}")
    out_k=$(awk "BEGIN {printf \"%.1f\", ${output_tokens:-0} / 1000}")
    token_info="${in_k}k/${out_k}k"
fi

# --- Lines changed ---
lines_info=""
if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
    lines_info="+${lines_added:-0}/-${lines_removed:-0}"
fi

# --- Session duration ---
duration_info=""
if [ -n "$duration_ms" ]; then
    total_secs=$((duration_ms / 1000))
    mins=$((total_secs / 60))
    secs=$((total_secs % 60))
    if [ "$mins" -gt 0 ]; then
        duration_info="${mins}m${secs}s"
    else
        duration_info="${secs}s"
    fi
fi

# --- Assemble: shell-theme section first, then Claude session info ---
parts=()
[ -n "$dir_info" ]       && parts+=("$dir_info")
[ -n "$git_info" ]       && parts+=("$git_info")
[ -n "$time_info" ]      && parts+=("$time_info")
[ -n "$agent_indicator" ] && parts+=("$agent_indicator")
[ -n "$model_info" ]     && parts+=("$model_info")
[ -n "$token_info" ]     && parts+=("$token_info")
[ -n "$context_info" ]   && parts+=("$context_info")
[ -n "$lines_info" ]     && parts+=("$lines_info")
[ -n "$cost_info" ]      && parts+=("$cost_info")
[ -n "$duration_info" ]  && parts+=("$duration_info")

result=""
for i in "${!parts[@]}"; do
    [ "$i" -gt 0 ] && result+=" ${SEP} "
    result+="${parts[$i]}"
done

printf "%b" "$result"
