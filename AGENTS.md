# AGENTS.md

This repository stores personal development environment configuration and supporting scripts. Use this file as the repo-specific guide for structure, installation assumptions, and maintenance conventions.

## Project Structure

- **`zsh/`** - Zsh configuration, aliases, functions, completion, and theme files.
- **`nvim/`** - Neovim configuration in Lua.
  - `init.lua` - Entry point.
  - `lua/core/` - Options, keymaps, commands, autocmds, utilities.
  - `lua/plugins/` - lazy.nvim plugin specs and per-plugin configuration.
- **`vim/`** - Vim configuration based on vim-plug.
- **`tmux/`** - Tmux configuration plus helper scripts in `tmux/scripts/`.
- **`git/`** - Git configuration, ignore files, Delta config, and helper scripts.
- **`hammerspoon/`** - macOS-only Hammerspoon automation scripts.
- **`wezterm/`** - WezTerm configuration.
- **`ghostty/`** - Ghostty configuration and themes.
- **`yazi/`** - Yazi file manager configuration.
- **`lsd/`** - `lsd` configuration.
- **`claude/`** - Claude Code / agent-related local configuration files linked into `~/.claude/`.
- **`codex/`** - Codex CLI / TUI configuration linked into `~/.codex/`.
- **`skills/`** - Agent skill library checked out as a Git submodule and installed into both `~/.claude/skills` and `~/.codex/skills`.
- **`installers/`** - Standalone install scripts for individual tools such as `fd`, `fzf`, `tmux`, and `yazi`.
- **`bin/`** - Utility scripts intended to be used from `$PATH`.
- **`CLAUDE.md`** - Claude Code-facing repository guide. Keep cross-agent instructions aligned with this file when conventions change.
- **`README.md`** - Public-facing quick overview and installation note.
- **`setup.sh`** - Interactive bootstrap script that creates symlinks and installs some dependencies/configs.

## Installation And Deployment Conventions

1. **Repository path matters**: `setup.sh` and some shell config assume the repo lives at `~/dotfiles`. The script will symlink the current checkout to `~/dotfiles` when needed.

2. **Clone with submodules**: `skills/` is a Git submodule. Prefer cloning with `--recursive`, or run `git submodule update --init --recursive` before relying on skill content.

3. **Setup is interactive**: `setup.sh` prompts before replacing existing files and supports `replace`, `backup`, or `skip`.

4. **Setup does more than symlinks**:
   - Links top-level configs into `~/.zshrc`, `~/.zshenv`, `~/.vimrc`, `~/.gitconfig`, `~/.gitignore`, `~/.tmux.conf`, `~/.hammerspoon`, and `~/.config/*`.
   - Links files from `claude/` into `~/.claude/`.
   - Links `codex/config.toml` into `~/.codex/config.toml`.
   - Symlinks each directory from `skills/` into both `~/.claude/skills` and `~/.codex/skills`.
   - Runs `vim +PlugInstall +qall` during setup.

5. **Backups stay local**: Choosing the `backup` option in `setup.sh` writes timestamped backups under `.backups.local/`, which is local machine state and should not become tracked source.

## Working Conventions

1. **Keep configs with their owning tool**: Avoid cross-tool dumping grounds. If a helper script is only for tmux or git, keep it under that tool's directory unless it is intentionally global under `bin/`.

2. **Neovim plugin APIs require source verification**: Plugins are managed by lazy.nvim and live under `~/.local/share/nvim/lazy/`. When changing plugin config or calling plugin APIs, inspect the plugin source instead of guessing.

3. **Treat `skills/` as a submodule, not ordinary content**: Parent-repo `git status` will show `skills` as modified when the submodule HEAD changes or contains local edits. Update it intentionally.

4. **Respect local-only overrides**: Gitignored local files include patterns like `*.local`, `*.local.*`, `local.*`, plus explicit files such as `hammerspoon/local.lua`. Do not move machine-specific settings into tracked shared config unless that is the goal.

5. **Do not treat ignored/generated artifacts as source**: Examples include `nvim/lazy-lock.json`, `vim/temp_dirs`, `nvim/temp_dirs`, `vim/installed_plugins/**`, and Hammerspoon annotation files under `hammerspoon/Spoons/EmmyLua.spoon/annotations`.

6. **macOS-specific code stays isolated**: Hammerspoon config is Darwin-only. Do not introduce macOS assumptions into shared shell/editor config unless guarded appropriately.

7. **Keep agent guides aligned**: When changing repository-wide conventions for agents, update both `AGENTS.md` and `CLAUDE.md` or intentionally document why they differ.

## Commit Message Convention

### Title Format

Follow this format for commit message titles:

```text
[component] description
[component] subcomponent: description
[component1][component2] description
```

- **Component prefix**: Use brackets to indicate the affected tool, for example `[nvim]`, `[zsh]`, `[tmux]`, `[claude]`, or `[skills]`.
- **Sub-component**: Optional. Use a colon separator, for example `[nvim] ai-agents: fix keymap`.
- **Description**: Use imperative mood and keep it brief.

### Commit Body

If the changes are non-trivial, include a body with bullets covering:
- What changed
- Why it changed, when that is not obvious
- Any notable implementation detail or migration note
