# GitHub Status for Herdr

Reports each agent pane's Git branch and repository status to the Herdr sidebar.
When a pane has no Git branch, its detected agent name is shown instead.
Repository status is shown as one of:

- `dirty`
- `main`
- `committed`
- `PR <number>`
- `merged`

## Requirements

- Herdr 0.8.2 or newer
- macOS or Linux, including WSL2
- `bash`, `git`, and `jq`
- An authenticated `gh` CLI for GitHub repositories
- An authenticated `glab` CLI for GitLab repositories, if needed

## Install

Install the plugin directly from GitHub:

```bash
herdr plugin install OWNER/REPO
```

For local development, clone and link it instead:

```bash
git clone <repo-url> ~/.config/herdr/plugins/github-status
herdr plugin link --enabled ~/.config/herdr/plugins/github-status
```

## Sidebar configuration

Add the following to `~/.config/herdr/config.toml`:

```toml
[ui.sidebar.agents]
rows = [
  ["state_icon", { token = "terminal_title_stripped", fg = "#ffffff", dim = false }],
  [{ token = "$github_branch_or_agent", fg = "#7dcfff", dim = false }],
  [
    { token = "$github_dirty", fg = "#f7768e", bold = true },
    { token = "$github_main", fg = "#abdfa7", bold = true, dim = false },
    { token = "$github_committed", fg = "#9ece6a" },
    { token = "$github_pr", fg = "#7aa2f7", bold = true },
    { token = "$github_merged", fg = "#bb9af7", bold = true },
  ],
]
```

Validate and reload the configuration:

```bash
herdr config check
herdr server reload-config
```
