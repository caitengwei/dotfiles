#!/bin/bash
base_dir=$(cd "$(dirname "$0")" && pwd)
backup_dir="$base_dir/.backups.local"
backup_prefix="$backup_dir/$(date '+%Y%m%d%H%M%S')"
is_darwin=false
[[ $OSTYPE == darwin* ]] && is_darwin=true

link_file() {
    local src=$1 dst=$2
    local backup_dst=false delete_dst=false link_dst=true
    if [[ -e $dst ]]; then
        current_link=$(readlink "$dst")
        if [[ "$current_link" != "$src" ]]; then
            while true; do
                printf "File already exists: %s. What do you want?\n" "$dst"
                printf "[r]eplace; [b]ack up; [s]kip: "
                read -r op
                case $op in
                    r )
                        delete_dst=true
                        link_dst=true
                        break;;
                    b )
                        backup_dst=true
                        delete_dst=true
                        link_dst=true
                        break;;
                    s )
                        link_dst=false
                        break;;
                    * )
                       echo "Unrecognized option: $op";;
               esac
            done
        else
            echo "$dst is already linked to $src"
            link_dst=false
        fi
    fi
    if [[ "$backup_dst" == "true" ]]; then
        mkdir -p "$backup_dir"
        local backup_file
        backup_file="$backup_prefix$(basename "$dst")"
        mv "$dst" "$backup_file"
        echo "$dst was backed up to $backup_file"
    fi
    if [[ "$delete_dst" == "true" ]]; then
        rm -rf "$dst"
    fi
    if [[ "$link_dst" == "true" ]]; then
        ln -s "$src" "$dst"
        echo "$dst linked to $src"
        return 0
    fi
    return 1
}

install_skills() {
    local src_root=$1 dst_root=$2
    local skill_repo
    local found_skill_repo=false

    mkdir -p "$dst_root"
    if [[ ! -d "$src_root" ]]; then
        printf "Warning: agent skills source not found at %s; run 'git submodule update --init --recursive' if you want to install skills.\n" "$src_root" >&2
        return 0
    fi

    for skill_repo in "$src_root"/*; do
        [[ -d "$skill_repo" ]] || continue
        found_skill_repo=true
        link_file "$skill_repo" "$dst_root/$(basename "$skill_repo")"
    done

    if [[ "$found_skill_repo" != "true" ]]; then
        printf "Warning: no top-level skill repositories found in %s; hidden directories are skipped. Run 'git submodule update --init --recursive' if skills are missing.\n" "$src_root" >&2
    fi
}

if [[ "$base_dir" != "$HOME/dotfiles" ]]; then
    link_file "$base_dir" ~/dotfiles
fi

link_file "$base_dir/zsh/zshrc" ~/.zshrc
link_file "$base_dir/zsh/zshenv" ~/.zshenv

if which nvim >/dev/null 2>&1 ; then
    echo "Setting up neovim..."
    mkdir -p ~/.config
    link_file "$base_dir/nvim" ~/.config/nvim
fi

echo "Setting up vim..."
link_file "$base_dir/vim/vimrc" ~/.vimrc
vim +PlugInstall +qall

echo "Setting up git..."
if  which git >/dev/null 2>&1 ; then
    link_file "$base_dir/git/gitconfig" ~/.gitconfig
    link_file "$base_dir/git/gitignore_global" ~/.gitignore
fi

echo "Setting up tmux..."
link_file "$base_dir/tmux/tmux.conf" ~/.tmux.conf

if [[ `uname` == "Darwin" ]]; then
    echo "Setting up Hammerspoon..."
    link_file "$base_dir/hammerspoon" ~/.hammerspoon
    "$base_dir/macos/copy_default_key_binding.sh"
fi

install_nerd_font() {
    if fc-list 2>/dev/null | grep -qi "Nerd Font"; then
        echo "Nerd Font already installed, skipping."
        return 0
    fi
    if $is_darwin && command -v brew >/dev/null 2>&1; then
        brew install --cask font-jetbrains-mono-nerd-font
    else
        local font="JetBrainsMono"
        local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.tar.xz"
        local dest="$HOME/.local/share/fonts"
        mkdir -p "$dest"
        local tmp
        tmp=$(mktemp -d)
        echo "Downloading ${font} Nerd Font..."
        if curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$tmp/${font}.tar.xz"; then
            tar -xJf "$tmp/${font}.tar.xz" -C "$tmp"
            find "$tmp" -name "*.ttf" -exec cp {} "$dest/" \;
            fc-cache -f "$dest" 2>/dev/null
            echo "Nerd Font installed to $dest"
        else
            echo "Warning: failed to download Nerd Font, statusline will use ASCII fallback."
        fi
        rm -rf "$tmp"
    fi
    rm -f /tmp/.claude-statusline-nerd-font
}

echo "Setting up Nerd Font..."
install_nerd_font

mkdir -p ~/.claude
for f in "$base_dir"/claude/*; do
    link_file "$f" ~/.claude/"$(basename "$f")"
done

echo "Setting up agent skills..."
install_skills "$base_dir/skills" ~/.claude/skills

mkdir -p ~/.codex
link_file "$base_dir/codex/config.toml" ~/.codex/config.toml
install_skills "$base_dir/skills" ~/.codex/skills

mkdir -p ~/.config
xdg_configs=(nvim tmux git lsd wezterm ghostty yazi)
for name in "${xdg_configs[@]}"; do
    link_file "$base_dir/$name" ~/.config/"$name"
done
