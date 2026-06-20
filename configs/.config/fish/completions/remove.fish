# Define the valid remove levels
set -l remove_levels -R -Rs -Rn -Rns -Rc -Rnc -Rsnc -Rsc -Rscn -Rnsc -Rncs -Rcns -Rcsn

# Complete the remove levels - exclusive completion (no files)
complete -c remove -f

# Complete the remove levels with descriptions
complete -c remove -n "not __fish_seen_subcommand_from $remove_levels" -f -a -R -d "Remove package only"
complete -c remove -n "not __fish_seen_subcommand_from $remove_levels" -f -a -Rs -d "Remove package and dependencies"
complete -c remove -n "not __fish_seen_subcommand_from $remove_levels" -f -a -Rn -d "Remove package and system config"
complete -c remove -n "not __fish_seen_subcommand_from $remove_levels" -f -a -Rns -d "Remove package, dependencies, and system config"
complete -c remove -n "not __fish_seen_subcommand_from $remove_levels" -f -a -Rc -d "Remove package and dependencies not required by others"
complete -c remove -n "not __fish_seen_subcommand_from $remove_levels" -f -a -Rnc -d "Remove package, system config, and dependencies not required by others"
complete -c remove -n "not __fish_seen_subcommand_from $remove_levels" -f -a -Rsnc -d "Remove package, dependencies not required by others, and system config"

# Function to get all installed packages (including AUR)
function __get_all_packages
    if type -q yay
        yay -Qq
    else
        pacman -Qq
    end
end

# After the remove level is specified, suggest installed packages (no files)
complete -c remove -n "__fish_seen_subcommand_from $remove_levels" -f -a "(__get_all_packages)"