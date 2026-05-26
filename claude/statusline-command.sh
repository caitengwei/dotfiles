#!/bin/bash

# Read stdin with timeout — prevents hang if pipe isn't closed
input=""
while IFS= read -r -t 2 line; do
    input+="$line"
done

[ -z "$input" ] && exit 0

# Parse all JSON fields in a single jq call
eval "$(echo "$input" | jq -r '
  @sh "remaining=\(.context_window.remaining_percentage // "")",
  @sh "ctx_size=\(.context_window.context_window_size // "")",
  @sh "agent_name=\(.agent.name // "")",
  @sh "model=\(.model.display_name // "")",
  @sh "cost=\(.cost.total_cost_usd // "")",
  @sh "input_tokens=\(.context_window.total_input_tokens // "")",
  @sh "output_tokens=\(.context_window.total_output_tokens // "")",
  @sh "cache_read=\(.context_window.current_usage.cache_read_input_tokens // "")",
  @sh "cache_create=\(.context_window.current_usage.cache_creation_input_tokens // "")",
  @sh "lines_added=\(.cost.total_lines_added // "")",
  @sh "lines_removed=\(.cost.total_lines_removed // "")",
  @sh "duration_ms=\(.cost.total_duration_ms // "")",
  @sh "api_duration_ms=\(.cost.total_api_duration_ms // "")",
  @sh "rate_5h=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "rate_5h_reset=\(.rate_limits.five_hour.resets_at // "")",
  @sh "worktree_name=\(.worktree.name // "")",
  @sh "pr_number=\(.pr.number // "")",
  @sh "pr_state=\(.pr.review_state // "")",
  @sh "session_name=\(.session_name // "")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "project_dir=\(.workspace.project_dir // "")"
' 2>/dev/null | tr '\n' ' ')"

DIM=$'\e[2m'; BOLD=$'\e[1m'; RST=$'\e[0m'
YELLOW=$'\e[93m'; RED=$'\e[91m'; GREEN=$'\e[92m'; CYAN=$'\e[96m'; MAGENTA=$'\e[95m'
SEP="${DIM} ┆ ${RST}"

# Nerd Font detection with cache
if [ -n "$CLAUDE_STATUSLINE_NERD_FONT" ]; then
    _nf="$CLAUDE_STATUSLINE_NERD_FONT"
elif [ -f /tmp/.claude-statusline-nerd-font ]; then
    _nf=$(< /tmp/.claude-statusline-nerd-font)
else
    if fc-list 2>/dev/null | grep -qi "Nerd Font"; then _nf=1; else _nf=0; fi
    printf '%s' "$_nf" > /tmp/.claude-statusline-nerd-font 2>/dev/null
fi

if [ "$_nf" = 1 ]; then
    ICON_AGENT="󰮄 "; ICON_MODEL="󰚩 "; ICON_TOKEN="󰍛 "
    ICON_CTX_OK="󰁹"; ICON_CTX_MID="󰁿"; ICON_CTX_LOW="󰂎"
    ICON_LINES="󰏫 "; ICON_COST="󰇁 "; ICON_TIME="󱑍 "
    ICON_CACHE="󰄀 "; ICON_RATE="󱐌 "; ICON_WT="󰘬 "; ICON_PR="󰊤 "; ICON_DIR="󰉋 "
else
    ICON_AGENT="@"; ICON_MODEL=""; ICON_TOKEN=""
    ICON_CTX_OK=""; ICON_CTX_MID=""; ICON_CTX_LOW=""
    ICON_LINES=""; ICON_COST="\$"; ICON_TIME=""
    ICON_CACHE=""; ICON_RATE="!"; ICON_WT="wt:"; ICON_PR="PR#"; ICON_DIR=""
fi

# --- Build sections ---

# Session/Agent
session_info=""
if [ -n "$session_name" ]; then
    session_info="${DIM}${session_name}${RST}"
elif [ -n "$agent_name" ]; then
    session_info="${ICON_AGENT}${agent_name}"
fi

# Model
model_info=""
[ -n "$model" ] && model_info="${ICON_MODEL}${model}"

# Tokens: used/total format with cache hit rate
token_info=""
if [ -n "$input_tokens" ]; then
    # Format as compact "used/total" (e.g., "45k/200k")
    _fmt_k() { local t=$1; if [ "$t" -ge 1000000 ]; then echo "$((t/1000000)).$(( (t%1000000)/100000 ))M"; elif [ "$t" -ge 1000 ]; then echo "$((t/1000))k"; else echo "$t"; fi; }
    in_fmt=$(_fmt_k "$input_tokens")
    total_fmt=$(_fmt_k "${ctx_size:-200000}")
    token_info="${ICON_TOKEN}${in_fmt}/${total_fmt}"

    # Cache hit rate (cache_read / total_input)
    if [ -n "$cache_read" ] && [ "$input_tokens" -gt 0 ]; then
        cache_pct=$(( cache_read * 100 / input_tokens ))
        if [ "$cache_pct" -gt 0 ]; then
            if [ "$cache_pct" -ge 70 ]; then
                token_info+=" ${GREEN}${ICON_CACHE}${cache_pct}%${RST}"
            elif [ "$cache_pct" -ge 30 ]; then
                token_info+=" ${ICON_CACHE}${cache_pct}%"
            else
                token_info+=" ${DIM}${ICON_CACHE}${cache_pct}%${RST}"
            fi
        fi
    fi
fi

# Context: threshold color + progress bar
context_info=""
if [ -n "$remaining" ]; then
    rem_int=${remaining%.*}
    [ -z "$rem_int" ] && rem_int=0
    if   [ "$rem_int" -lt 10 ]; then ctx_color="${BOLD}${RED}";    ctx_icon="$ICON_CTX_LOW"
    elif [ "$rem_int" -lt 20 ]; then ctx_color="${BOLD}${YELLOW}"; ctx_icon="$ICON_CTX_MID"
    else                             ctx_color="";                 ctx_icon="$ICON_CTX_OK"
    fi

    full=$(( (rem_int + 5) / 10 ))
    (( full > 10 )) && full=10
    (( full < 0 )) && full=0
    _filled="██████████"
    _empty="░░░░░░░░░░"
    bar="${_filled:0:full}${_empty:0:10-full}"

    if [ -n "$ctx_icon" ]; then
        context_info="${ctx_icon} ${bar} ${ctx_color}${rem_int}%${RST}"
    else
        context_info="${bar} ${ctx_color}${rem_int}%${RST}"
    fi
fi

# Lines changed
lines_info=""
if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
    lines_info="${ICON_LINES}${GREEN}+${lines_added:-0}${RST}${DIM}/${RST}${RED}-${lines_removed:-0}${RST}"
fi

# Cost
cost_info=""
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
    cost_info="${ICON_COST}$(printf '%.2f' "$cost")"
fi

# Duration with API time ratio
duration_info=""
if [ -n "$duration_ms" ] && [ "$duration_ms" -gt 0 ]; then
    total_secs=$((duration_ms / 1000))
    if [ "$total_secs" -ge 86400 ]; then
        dur_str="$((total_secs/86400))d$((total_secs%86400/3600))h"
    elif [ "$total_secs" -ge 3600 ]; then
        dur_str="$((total_secs/3600))h$((total_secs%3600/60))m"
    elif [ "$total_secs" -ge 60 ]; then
        dur_str="$((total_secs/60))m"
    else
        dur_str="${total_secs}s"
    fi
    duration_info="${ICON_TIME}${dur_str}"
    # Show API wait percentage if meaningful
    if [ -n "$api_duration_ms" ] && [ "$api_duration_ms" -gt 0 ]; then
        api_pct=$(( api_duration_ms * 100 / duration_ms ))
        duration_info+="${DIM}(${api_pct}%api)${RST}"
    fi
fi

# Rate limit warning (only show when > 50%)
rate_info=""
if [ -n "$rate_5h" ]; then
    rate_int=${rate_5h%.*}
    [ -z "$rate_int" ] && rate_int=0
    if [ "$rate_int" -ge 80 ]; then
        rate_info="${BOLD}${RED}${ICON_RATE}${rate_int}%${RST}"
    elif [ "$rate_int" -ge 50 ]; then
        rate_info="${YELLOW}${ICON_RATE}${rate_int}%${RST}"
    fi
fi

# Worktree indicator
wt_info=""
[ -n "$worktree_name" ] && wt_info="${CYAN}${ICON_WT}${worktree_name}${RST}"

# PR status
pr_info=""
if [ -n "$pr_number" ]; then
    case "$pr_state" in
        approved)          pr_info="${GREEN}${ICON_PR}${pr_number}✓${RST}" ;;
        changes_requested) pr_info="${RED}${ICON_PR}${pr_number}✗${RST}" ;;
        draft)             pr_info="${DIM}${ICON_PR}${pr_number}${RST}" ;;
        *)                 pr_info="${ICON_PR}${pr_number}" ;;
    esac
fi

# Current directory: show relative to project_dir, or basename if same
dir_info=""
if [ -n "$cwd" ]; then
    if [ -n "$project_dir" ] && [ "$cwd" != "$project_dir" ] && [[ "$cwd" == "$project_dir"* ]]; then
        # Inside project: show project name + relative subpath
        proj_name="${project_dir##*/}"
        rel="${cwd#"$project_dir"/}"
        dir_info="${DIM}${ICON_DIR}${proj_name}/${RST}${rel}"
    else
        dir_info="${ICON_DIR}${cwd##*/}"
    fi
fi

# --- Assemble (ordered by importance/frequency) ---
parts=()
[ -n "$dir_info" ]      && parts+=("$dir_info")
[ -n "$session_info" ]  && parts+=("$session_info")
[ -n "$wt_info" ]       && parts+=("$wt_info")
[ -n "$pr_info" ]       && parts+=("$pr_info")
[ -n "$model_info" ]    && parts+=("$model_info")
[ -n "$token_info" ]    && parts+=("$token_info")
[ -n "$context_info" ]  && parts+=("$context_info")
[ -n "$rate_info" ]     && parts+=("$rate_info")
[ -n "$lines_info" ]    && parts+=("$lines_info")
[ -n "$cost_info" ]     && parts+=("$cost_info")
[ -n "$duration_info" ] && parts+=("$duration_info")

result=""
for i in "${!parts[@]}"; do
    (( i > 0 )) && result+="$SEP"
    result+="${parts[$i]}"
done

printf '%b' "$result"
