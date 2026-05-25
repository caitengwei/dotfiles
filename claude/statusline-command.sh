#!/bin/bash

# Guard: kill entire script if it runs longer than 3 seconds
TIMEOUT_PID=$$
(sleep 3 && kill -9 $TIMEOUT_PID 2>/dev/null) &
WATCHDOG=$!
trap 'kill $WATCHDOG 2>/dev/null' EXIT

# Read stdin with timeout — prevents hang if pipe isn't closed
input=""
while IFS= read -r -t 2 line; do
    input+="$line"
done

[ -z "$input" ] && exit 0

# Parse all JSON fields in a single jq call
eval "$(echo "$input" | jq -r '
  @sh "remaining=\(.context_window.remaining_percentage // "")",
  @sh "agent_name=\(.agent.name // "")",
  @sh "model=\(.model.display_name // "")",
  @sh "cost=\(.cost.total_cost_usd // "")",
  @sh "input_tokens=\(.context_window.total_input_tokens // "")",
  @sh "output_tokens=\(.context_window.total_output_tokens // "")",
  @sh "lines_added=\(.cost.total_lines_added // "")",
  @sh "lines_removed=\(.cost.total_lines_removed // "")",
  @sh "duration_ms=\(.cost.total_duration_ms // "")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")"
' 2>/dev/null | tr '\n' ' ')"

DIM=$'\e[2m'; BOLD=$'\e[1m'; RST=$'\e[0m'
GREEN=$'\e[92m'; YELLOW=$'\e[93m'; RED=$'\e[91m'
SEP="${DIM} ┆ ${RST}"

# Detect Nerd Font: check if any NerdFont family is installed
HAS_NERD_FONT=false
if fc-list 2>/dev/null | grep -qi "Nerd Font"; then
    HAS_NERD_FONT=true
fi

# Icons: Nerd Font or ASCII fallback
if [ "$HAS_NERD_FONT" = true ]; then
    ICON_AGENT="󰮄 "; ICON_MODEL="󰚩 "; ICON_TOKEN="󰍛 "
    ICON_CTX_OK="󰁹"; ICON_CTX_MID="󰁿"; ICON_CTX_LOW="󰂎"
    ICON_LINES="󰏫 "; ICON_COST="󰇁 "; ICON_TIME="󱑍 "
else
    ICON_AGENT="@"; ICON_MODEL=""; ICON_TOKEN=""
    ICON_CTX_OK=""; ICON_CTX_MID=""; ICON_CTX_LOW=""
    ICON_LINES=""; ICON_COST="\$"; ICON_TIME=""
fi

# Agent
agent_indicator=""
[ -n "$agent_name" ] && agent_indicator="${ICON_AGENT}${agent_name}"

# Model
model_info=""
[ -n "$model" ] && model_info="${ICON_MODEL}${model}"

# Tokens
token_info=""
if [ -n "$input_tokens" ]; then
    in_k=$(awk "BEGIN {printf \"%.1f\", $input_tokens / 1000}")
    out_k=$(awk "BEGIN {printf \"%.1f\", ${output_tokens:-0} / 1000}")
    if [ "$HAS_NERD_FONT" = true ]; then
        token_info="${ICON_TOKEN}${in_k}k↓ ${out_k}k↑"
    else
        token_info="${in_k}k/${out_k}k"
    fi
fi

# Context: threshold color + icon + fractional progress bar
context_info=""
if [ -n "$remaining" ]; then
    rem_int=$(printf "%.0f" "$remaining")
    if   [ "$rem_int" -lt 10 ]; then ctx_color="${BOLD}${RED}";    ctx_icon="$ICON_CTX_LOW"
    elif [ "$rem_int" -lt 20 ]; then ctx_color="${BOLD}${YELLOW}"; ctx_icon="$ICON_CTX_MID"
    else                             ctx_color="";                 ctx_icon="$ICON_CTX_OK"
    fi

    bar_width=10
    full_cells=$(( (rem_int + 5) / 10 ))
    [ "$full_cells" -gt "$bar_width" ] && full_cells=$bar_width
    [ "$full_cells" -lt 0 ] && full_cells=0
    empty_cells=$((bar_width - full_cells))

    bar=""
    for ((i=0; i<full_cells; i++)); do bar+="█"; done
    for ((i=0; i<empty_cells; i++)); do bar+="░"; done

    if [ -n "$ctx_icon" ]; then
        context_info="${ctx_icon} ${bar} ${ctx_color}${rem_int}%${RST}"
    else
        context_info="${bar} ${ctx_color}${rem_int}%${RST}"
    fi
fi

# Lines
lines_info=""
if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
    lines_info="${ICON_LINES}+${lines_added:-0}${DIM}/${RST}-${lines_removed:-0}"
fi

# Cost
cost_info=""
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
    cost_info="${ICON_COST}$(printf '%.2f' "$cost")"
fi

# Duration
duration_info=""
if [ -n "$duration_ms" ]; then
    total_secs=$((duration_ms / 1000))
    days=$((total_secs / 86400))
    hours=$(( (total_secs % 86400) / 3600 ))
    mins=$(( (total_secs % 3600) / 60 ))
    if [ "$days" -gt 0 ]; then
        duration_info="${ICON_TIME}${days}d${hours}h"
    elif [ "$hours" -gt 0 ]; then
        duration_info="${ICON_TIME}${hours}h${mins}m"
    else
        duration_info="${ICON_TIME}${mins}m"
    fi
fi

# --- Assemble ---
parts=()
[ -n "$agent_indicator" ] && parts+=("$agent_indicator")
[ -n "$model_info" ]      && parts+=("$model_info")
[ -n "$token_info" ]      && parts+=("$token_info")
[ -n "$context_info" ]    && parts+=("$context_info")
[ -n "$lines_info" ]      && parts+=("$lines_info")
[ -n "$cost_info" ]       && parts+=("$cost_info")
[ -n "$duration_info" ]   && parts+=("$duration_info")

result=""
for i in "${!parts[@]}"; do
    [ "$i" -gt 0 ] && result+="$SEP"
    result+="${parts[$i]}"
done

printf "%b" "$result"
