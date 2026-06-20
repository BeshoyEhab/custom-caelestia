# ─────────────────────────────────────────────────────────────────────────────
# PATH Configuration (loaded early via conf.d)
# ─────────────────────────────────────────────────────────────────────────────

fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/.local/share/bin
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.opencode/bin
fish_add_path /opt/cross/bin
test -d "$HOME/platform-tools" && fish_add_path "$HOME/platform-tools"