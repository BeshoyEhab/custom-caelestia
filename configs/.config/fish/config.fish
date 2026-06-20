# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                            Fish Shell Config                             ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Sections:
#   1. Initialization & Environment
#   2. Modern CLI Replacements
#   3. File & Directory Operations
#   4. Git
#   5. GitHub CLI
#   6. System & Package Management
#   7. Quick Actions & Shortcuts
#   8. Custom Tools
#   9. Utility Functions
#
# Run `cheat-fish` for a quick reference of all aliases

# ═══════════════════════════════════════════════════════════════════════════
# 1. INITIALIZATION & ENVIRONMENT
# ═══════════════════════════════════════════════════════════════════════════

# Interactive shell setup
if status is-interactive
    set fish_greeting
    starship init fish | source
    zoxide init fish | source
end

# Environment variables
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx LD_LIBRARY_PATH $HOME/.local/lib/arch-mojo $LD_LIBRARY_PATH
set -gx CRYPTOGRAPHY_OPENSSL_NO_LEGACY 1

# PATH is configured in conf.d/paths.fish

# ═══════════════════════════════════════════════════════════════════════════
# 2. MODERN CLI REPLACEMENTS
# ═══════════════════════════════════════════════════════════════════════════

# Better alternatives (--wraps enables completions from original command)
function fnd --wraps fd --description "fd (better find)"; fd $argv; end
function diff --wraps delta --description "delta (better diff)"; delta $argv; end
function top --wraps btop --description "btop (better top)"; btop $argv; end
function cat --wraps bat --description "bat + image support"
    if status is-interactive
        cat-image $argv
    else
        command cat $argv
    end
end
alias ccat='/usr/bin/cat'             # original cat

# Eza (ls replacement) - inherit eza completions
function l --wraps eza --description "list files (long)"; eza -lh --icons=auto $argv; end
function ls --wraps eza --description "list files (compact)"; eza -1 --icons=auto $argv; end
function ll --wraps eza --description "list all files (detailed)"; eza -lha --icons=auto --sort=name --group-directories-first $argv; end
function ld --wraps eza --description "list directories only"; eza -lhD --icons=auto $argv; end
function lt --wraps eza --description "list as tree"; eza --icons=auto --tree $argv; end
function tree --wraps eza --description "tree view"; eza --tree $argv; end
function tre --wraps eza --description "tree view with hidden"; eza --tree --hidden $argv; end

# ═══════════════════════════════════════════════════════════════════════════
# 3. FILE & DIRECTORY OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════

# Safe operations (prevent accidents) - with completions from original
function cp --wraps cp --description "copy (interactive, recursive)"; command cp -ri $argv; end
function mv --wraps mv --description "move (interactive, verbose)"; command mv -iv $argv; end
function ln --wraps ln --description "link (interactive, verbose)"; command ln -iv $argv; end
function rm --wraps rm --description "trash instead of delete"
    if test (id -u) -eq 0
        command rm $argv
    else
        /home/Bisho/.local/share/bin/rem $argv
    end
end
function chown --wraps chown --description "chown (safe, preserve-root)"; command chown --preserve-root $argv; end
function chmod --wraps chmod --description "chmod (safe, preserve-root)"; command chmod --preserve-root $argv; end

# Shortcuts
function mkdir --wraps mkdir --description "create directory (with parents)"; command mkdir -p $argv; end
function md --wraps mkdir --description "mkdir shorthand"; command mkdir -p $argv; end
function less --wraps less --description "less with colors"; command less -R $argv; end

function mkcd --description "Create directory and cd into it"
    if test (count $argv) -eq 0
        echo "Usage: mkcd <directory>"
        return 1
    end
    mkdir -p $argv[1] && cd $argv[1]
end

# Zoxide - smart cd (replace default cd)
function cd --description "cd with zoxide integration"
    if test (count $argv) -eq 0
        z $HOME
    else if test "$argv[1]" = "-"
        z -
    else if test "$argv[1]" = ".."
        z ..
    else if test "$argv[1]" = "..."
        z ../..
    else if string match -qr '^-' -- "$argv[1]"
        builtin cd $argv
    else
        z $argv
    end
end

function za --description "zoxide: add current directory to database"
    zoxide add
end

function zl --description "zoxide: list recent directories"
    zoxide query --list
end

function zi --description "zoxide: interactive directory selection"
    zoxide query --interactive
end

# Trash management
alias trash-list='ll --total-size ~/.local/share/Trash/files/'  # list trash contents
alias trash-empty='command rm -rf ~/.local/share/Trash/files/{*,.[!.]*}'  # empty trash permanently

# Archive
alias extract='unp'  # extract any archive

function backup --description "Create a backup of a file"
    if test (count $argv) -eq 0
        echo "Usage: backup <file>"
        return 1
    end
    cp $argv[1] "$argv[1].bak"
end

# ═══════════════════════════════════════════════════════════════════════════
# 4. GIT
# ═══════════════════════════════════════════════════════════════════════════

# Basic (with git completions)
function ga --wraps 'git add'; git add $argv; end
function gaa; git add .; end
function gs --wraps 'git status'; git status $argv; end
function gp --wraps 'git push'; git push $argv; end
function gpull --wraps 'git pull'; git pull $argv; end
function gf --wraps 'git fetch'; git fetch --all --prune $argv; end

# Commit
alias gcm='git commit'  # commit
alias gca='git commit --amend'  # amend last commit
alias gcan='git commit --amend --no-edit'  # amend without editing
alias gwip='git add . && git commit -m "WIP"'  # quick WIP commit

function gc --description "git commit -m"
    git commit -m "$argv"
end

function gcom --description "Add all and commit"
    git add .
    git commit -m "$argv"
end

function lazyg --description "Add, commit, and push"
    git add .
    git commit -m "$argv"
    git push
end

# Branch (with git completions for branch names)
function gco --wraps 'git checkout'; git checkout $argv; end
function gcb --wraps 'git checkout'; git checkout -b $argv; end
function gsw --wraps 'git switch'; git switch $argv; end
function gswc --wraps 'git switch'; git switch -c $argv; end
function gb --wraps 'git branch'; git branch $argv; end
function gba --wraps 'git branch'; git branch -a $argv; end

function gbf --description "Fuzzy switch git branch"
    set branch (git branch -a | fzf | string trim)
    and git checkout (string replace 'remotes/origin/' '' $branch)
end

# Diff & Log
function gd --wraps 'git diff'; git diff $argv; end
function gds --wraps 'git diff'; git diff --staged $argv; end
function gl --wraps 'git log'; git log --oneline --graph --decorate --all $argv; end
function glog --wraps 'git log'; git log --pretty=format:"%C(yellow)%h %C(cyan)%ad %C(green)%an%C(auto)%d %Creset%s" --date=short $argv; end

# Stash
function gst --wraps 'git stash'; git stash $argv; end
function gstp --wraps 'git stash'; git stash pop $argv; end

# Reset & Undo
function grb --wraps 'git rebase'; git rebase $argv; end
function grs; git reset --soft HEAD~1; end
function grh; git reset --hard HEAD~1; end
function gunstage --wraps 'git restore'; git restore --staged $argv; end
function gundo --wraps 'git checkout'; git checkout -- $argv; end
function gclean --wraps 'git clean'; git clean -fd $argv; end
function gcp --wraps 'git cherry-pick'; git cherry-pick $argv; end

# Clone (with completions)
function gcl --wraps 'git clone'; git clone $argv; end

# ═══════════════════════════════════════════════════════════════════════════
# 5. GITHUB CLI
# ═══════════════════════════════════════════════════════════════════════════

function ghi --wraps 'gh issue'; gh issue list $argv; end
function ghpr --wraps 'gh pr'; gh pr list $argv; end
function ghprc --wraps 'gh pr'; gh pr create $argv; end
function ghprv --wraps 'gh pr'; gh pr view --web $argv; end
function ghc --wraps 'gh repo'; gh repo clone $argv; end

function gpr --description "Push and create PR"
    git push -u origin (git branch --show-current) && gh pr create
end

# ═══════════════════════════════════════════════════════════════════════════
# 6. SYSTEM & PACKAGE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════

# System info
function df --wraps df; command df -h $argv; end
function du --wraps du; command du -h $argv; end
function free --wraps free; command free -h $argv; end
alias myip='curl -s ifconfig.me'  # show public IP
alias localip="ip -4 addr show | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}' | head -1"  # show local IP
alias ports='ss -tulanp'  # show open ports
alias envshow='env | sort'  # show environment variables
alias pathshow='echo $PATH | tr ":" "\n"'  # show PATH entries

function ports-used --description "Show what's using a port"
    sudo lsof -i :$argv
end

# Process management
alias psg='ps aux | grep -v grep | grep'  # search processes
alias kill9='kill -9'  # force kill
alias j='jobs -l'  # list background jobs

# Systemd (completions for service names)
function sc --wraps systemctl; sudo systemctl $argv; end
function scs --wraps systemctl; systemctl status $argv; end
function sce --wraps systemctl; sudo systemctl enable $argv; end
function scd --wraps systemctl; sudo systemctl disable $argv; end
function scr --wraps systemctl; sudo systemctl restart $argv; end

# Package manager (Arch) - completions for package names
function pac --wraps pacman; sudo pacman -S $argv; end
function pacr --wraps pacman; sudo pacman -Rns $argv; end
function pacu --wraps pacman; sudo pacman -Syu $argv; end
function pacs --wraps pacman; pacman -Ss $argv; end
function yays --wraps yay; yay -Ss $argv; end

# ═══════════════════════════════════════════════════════════════════════════
# 7. QUICK ACTIONS & SHORTCUTS
# ═══════════════════════════════════════════════════════════════════════════

# Essentials
alias c='clear'  # clear screen
alias q='exit'  # quit shell
function n --wraps nvim --description "open neovim"; nvim $argv; end
function v --wraps nvim --description "open neovim (quick)"; nvim $argv; end
alias h='history'  # show history
alias hs='history | grep'  # search history
alias reload='source ~/.config/fish/config.fish'  # reload fish config
alias g='git status'  # quick git status
alias lg='lazygit'  # git UI

# Directory navigation
alias ..='cd ..'  # go up one directory
alias ...='cd ../..'  # go up two directories
alias up='cd ..'  # go up one directory
alias up2='cd ../..'  # go up two directories
alias up3='cd ../../..'  # go up three directories
alias take=mkcd  # create and enter directory
alias r='ranger'  # file manager

# Config editing
alias fishconfig='nvim ~/.config/fish/config.fish'  # edit fish config
alias hyprconfig='nvim ~/.config/hypr/hyprland.conf'  # edit hyprland config

# Clipboard (Wayland)
alias copy='wl-copy'  # copy to clipboard
alias paste='wl-paste'  # paste from clipboard

# Date/time
alias now='date +"%Y-%m-%d %H:%M:%S"'  # current datetime
alias week='date +%V'  # current week number

# Network (with completions)
function ping --wraps ping; command ping -c 5 $argv; end
function wget --wraps wget; command wget -c $argv; end
function watch --wraps watch; command watch -n 1 $argv; end

# Path
alias showpath='string join \n $PATH'  # show PATH entries (renamed from 'path' to avoid conflict with fish builtin)

# Misc
alias xwinwrap='xwinwrap -ni -b -fs -ov -nf --'  # animated wallpaper
function docker --wraps podman --description "docker via podman"; podman $argv; end

# ═══════════════════════════════════════════════════════════════════════════
# 8. CUSTOM TOOLS
# ═══════════════════════════════════════════════════════════════════════════

# dot-man (dotfile manager)
alias dm='dot-man'  # dotfile manager
alias dms='dot-man status'  # dotfiles status
alias dmt='dot-man tui'  # dotfiles TUI

# pro-mgr (project manager)
alias pm='pro-mgr'  # project manager
alias pml='pro-mgr project list'  # list projects

# ═══════════════════════════════════════════════════════════════════════════
# 9. UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

# FZF-powered
function fe --description "Fuzzy find and edit file"
    set file (fzf --preview 'bat --color=always {}')
    and $EDITOR $file
end

function fcd --description "Fuzzy find and cd to directory"
    set dir (fd -t d | fzf --preview 'eza --tree --level=2 {}')
    and cd $dir
end

function ff --description "Find file by name"
    find . -type f -iname "*$argv*"
end

# Clipboard utilities
function y --description "Yank current path to clipboard"
    pwd | wl-copy
    echo "Copied to clipboard: "(pwd)
end

function yf --description "Yank file path to clipboard"
    if test (count $argv) -eq 0
        y
    else
        echo (realpath $argv[1]) | wl-copy
        echo "Copied: "(realpath $argv[1])
    end
end

# Terminal utilities
# zellij is the terminal workspace
alias zk='zellij kill-session'  # kill current session
alias zl='zellij list-sessions'  # list sessions

# Quick open
function open --description "Open file or directory with default app"
    if type -q xdg-open
        xdg-open $argv
    else if type -q open
        open $argv
    end
end

function e --description "Explore: fuzzy find and open file"
    fe
end

# Quick notes
function quick-note --description "Quick note to today file"
    set notes ~/Notes/(date +%Y-%m-%d).md
    mkdir -p ~/Notes
    $EDITOR $notes
end

# Notes
function note --description "Quick timestamped note"
    set notes_dir ~/Notes
    mkdir -p $notes_dir
    set filename $notes_dir/(date +%Y-%m-%d).md
    if test (count $argv) -gt 0
        echo "- "(date +%H:%M)" $argv" >> $filename
        echo "Note added to $filename"
    else
        $EDITOR $filename
    end
end

# Web lookups
function weather --description "Get weather for a city"
    curl "wttr.in/$argv"
end

function cheat --description "Get cheat sheet for a command"
    curl "cht.sh/$argv"
end

function gitignore --description "Fetch .gitignore template"
    curl -sL "https://www.toptal.com/developers/gitignore/api/$argv"
end

# Display
function colors --description "Display terminal colors"
    for i in (seq 0 15)
        printf "\e[48;5;%dm %3d \e[0m" $i $i
        test (math "$i % 8") -eq 7 && echo
    end
    echo
    for i in (seq 16 231)
        printf "\e[48;5;%dm %3d \e[0m" $i $i
        test (math "($i - 16) % 12") -eq 11 && echo
    end
end

function cheat-fish --description "Show fish aliases cheat sheet (auto-generated)"
    set -l config ~/.config/fish/config.fish
    set -l col1_width 14  # Width of first column
    
    # Colors
    set -l c_reset (set_color normal)
    set -l c_header (set_color --bold bryellow)
    set -l c_section (set_color --bold brmagenta)
    set -l c_name (set_color --bold brcyan)
    set -l c_cmd (set_color brblue)
    set -l c_desc (set_color white)
    set -l c_dim (set_color brblack)
    
    # Collect items per section, then only print sections with content
    set -l current_section ""
    set -l section_items
    set -l first_output 1
    
    printf "%s# 🐟 Fish Shell Cheat Sheet%s\n\n" "$c_header" "$c_reset"
    printf "%s> Auto-generated from config.fish | Run 'cheat-fish' anytime%s\n" "$c_dim" "$c_reset"
    
    while read -l line
        # Detect section headers (lines starting with # followed by number. TITLE)
        if string match -qr '^# [0-9]+\.' -- "$line"
            # Print previous section if it had items
            if test (count $section_items) -gt 0
                if test $first_output -eq 0
                    printf "\n"
                end
                set first_output 0
                printf "\n%s━━ %s ━━%s\n\n" "$c_section" "$current_section" "$c_reset"
                for item in $section_items
                    echo "$item"
                end
            end
            # Start new section
            set current_section (string replace -r '^# [0-9]+\. ' '' -- "$line")
            set section_items
        
        # Parse: alias name='command' or alias name="command" or alias name=command
        else if string match -qr "^alias [a-zA-Z0-9_-]+=" -- "$line"
            set -l name (string match -r "^alias ([a-zA-Z0-9_-]+)=" -- "$line")[2]
            
            # Check for inline comment (description)
            set -l desc (string match -r '#\\s*(.+)$' -- "$line")[2]
            set -l is_description 1
            
            if test -z "$desc"
                set is_description 0
                # No comment, use command as description
                set desc (string match -r "='([^']*)'" -- "$line")[2]
                if test -z "$desc"
                    set desc (string match -r '="([^"]*)"' -- "$line")[2]
                end
                if test -z "$desc"
                    set desc (string match -r "^alias [a-zA-Z0-9_-]+=([^ #]+)" -- "$line")[2]
                end
            end
            
            if test -n "$desc"
                # Clean up escape sequences for display
                set desc (string replace -a '\\\\' '\\' -- "$desc")
                set desc (string replace -a '\\n' '⏎' -- "$desc")
                if test $is_description -eq 1
                    set -a section_items (printf "  %s%-"$col1_width"s%s %s%s%s" "$c_name" "$name" "$c_reset" "$c_desc" "$desc" "$c_reset")
                else
                    set -a section_items (printf "  %s%-"$col1_width"s%s %s%s%s" "$c_name" "$name" "$c_reset" "$c_cmd" "$desc" "$c_reset")
                end
            end
        
        # Parse: function name --wraps X --description "desc"
        else if string match -qr '^function [a-zA-Z0-9_-]+ --wraps .* --description' -- "$line"
            set -l name (string match -r '^function ([a-zA-Z0-9_-]+)' -- "$line")[2]
            set -l desc (string match -r -- '-{2}description "([^"]*)"' "$line")[2]
            if test -n "$name" -a -n "$desc"
                set -a section_items (printf "  %s%-"$col1_width"s%s %s%s%s" "$c_name" "$name" "$c_reset" "$c_desc" "$desc" "$c_reset")
            end
        
        # Parse: function name --description "desc"
        else if string match -qr '^function [a-zA-Z0-9_-]+ --description' -- "$line"
            set -l parts (string match -r '^function ([a-zA-Z0-9_-]+) --description "([^"]*)"' -- "$line")
            if test (count $parts) -ge 3
                set -a section_items (printf "  %s%-"$col1_width"s%s %s%s%s" "$c_name" "$parts[2]" "$c_reset" "$c_desc" "$parts[3]" "$c_reset")
            end
        
        # Parse: function name --wraps 'cmd'; actual-cmd $argv; end (use command as desc)
        else if string match -qr "^function [a-zA-Z0-9_-]+ --wraps" -- "$line"
            set -l name (string match -r "^function ([a-zA-Z0-9_-]+)" -- "$line")[2]
            set -l cmd (string match -r "; (.*) \\\$argv" -- "$line")[2]
            if test -n "$cmd"
                set -a section_items (printf "  %s%-"$col1_width"s%s %s%s%s" "$c_name" "$name" "$c_reset" "$c_cmd" "$cmd" "$c_reset")
            end
        
        # Parse: function name; command; end (simple one-liners, use command as desc)
        else if string match -qr '^function [a-zA-Z0-9_-]+;' -- "$line"
            set -l name (string match -r "^function ([a-zA-Z0-9_-]+);" -- "$line")[2]
            set -l cmd (string match -r "; (.*); end" -- "$line")[2]
            if test -n "$cmd"
                set cmd (string replace -a '\\\\' '\\' -- "$cmd")
                set -a section_items (printf "  %s%-"$col1_width"s%s %s%s%s" "$c_name" "$name" "$c_reset" "$c_cmd" "$cmd" "$c_reset")
            end
        end
    end < $config
    
    # Print last section if it had items
    if test (count $section_items) -gt 0
        printf "\n%s━━ %s ━━%s\n\n" "$c_section" "$current_section" "$c_reset"
        for item in $section_items
            echo "$item"
        end
    end
end

# Cloud
function gdrive --description "Mount Google Drive on demand"
    if not mountpoint -q ~/GoogleDrive
        echo "Mounting Google Drive..."
        rclone mount Drive: ~/GoogleDrive --vfs-cache-mode writes --daemon
        sleep 2
    end
    cd ~/GoogleDrive
end

# Re-run last command with sudo
function please --description "Re-run last command with sudo"
    set -l last_cmd (history --max 1)[1]
    if test -z "$last_cmd"
        echo "No previous command found."
        return 1
    end
    echo "Please: sudo $last_cmd"
    eval sudo $last_cmd
end

# Sudo wrapper (expand aliases and functions)
function sudo --wraps sudo --description "Run command as root, expanding aliases/functions"
    # Parse arguments to separate sudo options from the command
    set -l sudo_args
    set -l i 1
    while test $i -le (count $argv)
        if string match -q -- '-*' $argv[$i]
            set sudo_args $sudo_args $argv[$i]
            set i (math $i + 1)
        else
            break
        end
    end
    set -l cmd $argv[$i]
    set -l cmd_args $argv[(math $i + 1)..-1]

    if functions -q -- $cmd
        set -l user (whoami)
        set -l config_path /home/$user/.config/fish/config.fish
        set -l cmd_str (string join ' ' -- $cmd $cmd_args)
        command sudo $sudo_args fish -c "source $config_path; $cmd_str"
    else
        command sudo $argv
    end
end
