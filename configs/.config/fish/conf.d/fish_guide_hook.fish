# ─────────────────────────────────────────────────────────────────────────────
# fish-guide suggestion hook
# Place this file at: ~/.config/fish/conf.d/fish_guide_hook.fish
#
# After every command, fish-guide checks if there's a shorter alias for it
# and prints a subtle tip if so.
# ─────────────────────────────────────────────────────────────────────────────

function __fish_guide_suggest --on-event fish_postexec
    # $argv[1] is the command string that was just executed
    set -l cmd_tokens (string split ' ' -- $argv[1])

    # Skip empty, skip if it's fish-guide itself, skip builtins cd/exit/clear
    if test (count $cmd_tokens) -eq 0
        return
    end
    set -l first $cmd_tokens[1]
    if contains -- $first fish-guide please '' cd exit clear q c reload
        return
    end

    # Call fish-guide suggest (runs fast, no TUI startup)
    set -l tip (fish-guide suggest $cmd_tokens 2>/dev/null)
    if test -n "$tip"
        echo $tip
    end
end
