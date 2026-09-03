#!/usr/bin/env bash

set -euo pipefail

readonly HERDR_CLI="${HERDR_BIN_PATH:-herdr}"
readonly SOURCE="plugin:${HERDR_PLUGIN_ID:-shimona.github-status}"
readonly STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}/herdr-github-status}"
readonly LOCK_DIR="$STATE_DIR/report.lock"

mkdir -p "$STATE_DIR"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

agents_json="$($HERDR_CLI agent list)"
readonly STATUSES=(dirty main committed pr merged)

while IFS= read -r agent_json; do
  pane_id="$(jq -er '.pane_id' <<<"$agent_json")"
  cwd="$(jq -er '.foreground_cwd // .cwd' <<<"$agent_json")"
  agent_label="$(jq -r '.display_agent // .agent // "agent"' <<<"$agent_json")"
  pr_number=""

  if ! git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    clear_args=(
      pane report-metadata "$pane_id"
      --source "$SOURCE"
      --clear-token github_status
      --clear-token github_branch
      --token "github_branch_or_agent=$agent_label"
    )
    for candidate in "${STATUSES[@]}"; do
      clear_args+=(--clear-token "github_${candidate}_icon")
      clear_args+=(--clear-token "github_$candidate")
    done
    "$HERDR_CLI" "${clear_args[@]}" >/dev/null 2>&1 || true
    continue
  fi

  branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"

  if [[ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]]; then
    status="dirty"
  else
    origin_url="$(git -C "$cwd" remote get-url origin 2>/dev/null || true)"
    if [[ "$branch" == "main" ]]; then
      pr_state="MAIN"
    elif [[ -n "$branch" ]]; then
      pr_info=""
      case "$origin_url" in
        *github*)
          pr_info="$(
            cd "$cwd" && {
              github_repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" &&
              gh pr list \
                --repo "$github_repo" \
                --head "$branch" \
                --state all \
                --limit 100 \
                --json number,state,headRepository 2>/dev/null |
                jq -r --arg repo "$github_repo" \
                  '[.[] | select(.headRepository.nameWithOwner == $repo)] | if length > 0 then [.[0].state, (.[0].number | tostring)] | @tsv else "" end'
            } || true
          )"
          ;;
        *gitlab*)
          pr_info="$(
            cd "$cwd" &&
              glab mr list \
                --source-branch "$branch" \
                --all \
                --per-page 1 \
                --order updated_at \
                --sort desc \
                --output json 2>/dev/null |
              jq -r 'if length > 0 then [.[0].state, (.[0].iid | tostring)] | @tsv else "" end' || true
          )"
          ;;
      esac

      if [[ -n "$pr_info" ]]; then
        IFS=$'\t' read -r pr_state pr_number <<<"$pr_info"
      else
        pr_state=""
      fi
    else
      pr_state=""
    fi
    case "$pr_state" in
      MAIN)
        status="main"
        ;;
      MERGED|merged)
        status="merged"
        ;;
      OPEN|OPENED|CLOSED|open|opened|closed)
        status="pr"
        ;;
      *)
        status="committed"
        ;;
    esac
  fi

  report_args=(
    pane report-metadata "$pane_id"
    --source "$SOURCE"
    --clear-token github_status
    --clear-token github_branch
    --token "github_branch_or_agent=${branch:-$agent_label}"
  )
  for candidate in "${STATUSES[@]}"; do
    if [[ "$candidate" != "$status" ]]; then
      report_args+=(--clear-token "github_${candidate}_icon")
      report_args+=(--clear-token "github_$candidate")
    fi
  done
  display_status="$status"
  if [[ "$status" == "pr" && -n "$pr_number" ]]; then
    display_status="PR $pr_number"
  fi
  report_args+=(
    --clear-token "github_${status}_icon"
    --token "github_$status= $display_status"
  )
  "$HERDR_CLI" "${report_args[@]}" >/dev/null 2>&1 || true
done < <(jq -c '.result.agents[] | select((.foreground_cwd // .cwd) != null)' <<<"$agents_json")
