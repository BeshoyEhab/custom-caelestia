complete -c wine-launcher -f

# --run: Show games only after --run/-r is typed
complete -c wine-launcher -n "__fish_seen_subcommand_from --run -r" \
    -x -a "(
        if test -d ~/.cache/games && count (ls ~/.cache/games/*.json) > /dev/null
            find ~/.cache/games -maxdepth 1 -name '*.json' -exec basename -s .json {} \;
        end
    )" -d "Game to run"

# --edit: Show games only after --edit/-e is typed
complete -c wine-launcher -n "__fish_seen_subcommand_from --edit -e" \
    -x -a "(
        if test -d ~/.cache/games && count (ls ~/.cache/games/*.json) > /dev/null
            find ~/.cache/games -maxdepth 1 -name '*.json' -exec basename -s .json {} \;
        end 
    )" -d "Game to edit"

# Main commands
complete -c wine-launcher -n "not __fish_seen_subcommand_from --run --edit" \
    -a "--add -a" -d "Add new game"
complete -c wine-launcher -n "not __fish_seen_subcommand_from --add --edit" \
    -a "--run -r" -d "Run game"
complete -c wine-launcher -n "not __fish_seen_subcommand_from --add --run" \
    -a "--edit -e" -d "Edit game"
complete -c wine-launcher -n "not __fish_seen_subcommand_from --add --run --edit" \
    -a "--list -l" -d "List games"