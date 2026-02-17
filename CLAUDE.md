# Dotfiles

个人开发环境配置仓库，通过符号链接统一管理 zsh、vim、neovim、tmux、git、hammerspoon 等工具的配置。

## 部署

```bash
# 克隆（含子模块）
git clone --recursive <repo-url> ~/dotfiles

# 安装：交互式创建符号链接，已有文件可选 replace/backup/skip
bash setup.sh
```

仓库假定路径为 `~/dotfiles`（硬编码在 setup.sh 和 zshrc 中）。

## 目录结构

| 目录 | 链接目标 | 说明 |
|------|----------|------|
| `zsh/zshrc` | `~/.zshrc` | Zsh 主配置，oh-my-zsh 主题 bira |
| `zsh/oh-my-zsh` | `~/.oh-my-zsh` | oh-my-zsh（Git 子模块） |
| `zsh/oh_my_zsh_custom/` | — | 自定义插件和主题目录 |
| `zsh/alias.zsh` | — | 全局别名（`H`/`L`/`G`/`F`/`C`/`N`） |
| `zsh/functions.zsh` | — | 自定义函数 |
| `git/gitconfig` | `~/.gitconfig` | Git 配置 |
| `git/gitignore_global` | `~/.gitignore` | 全局 gitignore |
| `vim/vimrc` | `~/.vimrc` | Vim 配置 |
| `nvim/` | `~/.config/nvim` | Neovim 配置（Lua） |
| `tmux/tmux.conf` | `~/.tmux.conf` | Tmux 配置 |
| `tmux/tpm/` | — | Tmux Plugin Manager（Git 子模块） |
| `hammerspoon/` | `~/.hammerspoon` | macOS 窗口管理（仅 Darwin） |
| `bin/` | — | 自定义脚本，加入 `$PATH` |

## Git 子模块

- `zsh/oh-my-zsh` — oh-my-zsh
- `zsh/oh_my_zsh_custom/plugins/zsh-syntax-highlighting` — 语法高亮
- `zsh/oh_my_zsh_custom/plugins/async` — zsh-async
- `tmux/tpm` — Tmux Plugin Manager

更新子模块：`git submodule update --remote`

## 关键约定

- **Tmux 前缀键**：`C-l`（非默认 `C-b`）
- **Vi 键位体系**：tmux 复制模式使用 vi 键位；窗格切换 `prefix + h/j/k/l`；vim-tmux-navigator 使用 `C-M-h/j/k/l`
- **本地覆盖**：zsh 在末尾加载 `zsh/zshrc.local`（不入版本控制），用于机器特定配置
- **编辑器**：默认 `EDITOR=vim`
- **Zsh 键绑定**：使用 emacs 模式（`bindkey -e`），非 vi 模式
