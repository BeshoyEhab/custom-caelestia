for mode in default insert
    bind --mode $mode " " __abbr_tips_bind_space
    bind --mode $mode \n __abbr_tips_bind_newline
    bind --mode $mode \r __abbr_tips_bind_newline
end

set -g __abbr_tips_used 0

# Ensure defaults exist (install event only fires once)
test -z "$ABBR_TIPS_COOLDOWN"; and set -Ux ABBR_TIPS_COOLDOWN 300
test -z "$ABBR_TIPS_MIN_LENGTH"; and set -Ux ABBR_TIPS_MIN_LENGTH 8
test -z "$__ABBR_TIPS_SAVED_CHARS"; and set -g __ABBR_TIPS_SAVED_CHARS 0
test -z "$__ABBR_TIPS_FRECENCY_COUNTS"; and set -g __ABBR_TIPS_FRECENCY_COUNTS
test -z "$__ABBR_TIPS_FRECENCY_TIMES"; and set -g __ABBR_TIPS_FRECENCY_TIMES
test -z "$__ABBR_TIPS_LAST_SHOWN"; and set -g __ABBR_TIPS_LAST_SHOWN

# Trim simple/double quotes from args
function trim_value
    echo "$argv" | string trim --left --right --chars '"\'' | string join ' '
end

function __abbr_tips_install --on-event abbr_tips_install
    # Regexes used to find abbreviation inside command
    set -Ux ABBR_TIPS_REGEXES
    set -a ABBR_TIPS_REGEXES '(^(\w+\s+)+(-{1,2})\w+)(\s\S+)'
    set -a ABBR_TIPS_REGEXES '(^(\s?(\w-?)+){3}).*'
    set -a ABBR_TIPS_REGEXES '(^(\s?(\w-?)+){2}).*'
    set -a ABBR_TIPS_REGEXES '(^(\s?(\w-?)+){1}).*'

    set -Ux ABBR_TIPS_PROMPT "\n💡 \e[1m{{ .abbr }}\e[0m => {{ .cmd }} \e[2m({{ .saved }} saved)\e[0m"
    set -gx ABBR_TIPS_AUTO_UPDATE background

    # Cooldown in seconds (default 300 = 5 min)
    set -q ABBR_TIPS_COOLDOWN; or set -Ux ABBR_TIPS_COOLDOWN 300
    # Minimum command length to show tip (default 8)
    set -q ABBR_TIPS_MIN_LENGTH; or set -Ux ABBR_TIPS_MIN_LENGTH 8

    # Frecency tracking: usage counts and last-used timestamps
    set -Ux __ABBR_TIPS_FRECENCY_COUNTS
    set -Ux __ABBR_TIPS_FRECENCY_TIMES
    set -Ux __ABBR_TIPS_LAST_SHOWN
    set -Ux __ABBR_TIPS_SAVED_CHARS 0

    __abbr_tips_init
end

function __abbr_tips_frecency_score -d "Calculate frecency score for an abbreviation"
    set -l key $argv[1]
    set -l count 0
    set -l last_time 0
    # Search through "key:count" entries
    for entry in $__ABBR_TIPS_FRECENCY_COUNTS
        set -l parts (string split ':' -- "$entry")
        if test "$parts[1]" = "$key"
            set count $parts[2]
            break
        end
    end
    for entry in $__ABBR_TIPS_FRECENCY_TIMES
        set -l parts (string split ':' -- "$entry")
        if test "$parts[1]" = "$key"
            set last_time $parts[2]
            break
        end
    end
    if test $count -eq 0
        echo 0
        return
    end
    set -l now (date +%s)
    set -l hours_ago (math "max(1, ($now - $last_time) / 3600)")
    # Score: usage_count / (1 + hours_since_use)
    math "$count / (1 + $hours_ago)"
end

function __abbr_tips_record_use -d "Record abbreviation usage for frecency"
    set -l key $argv[1]
    set -l now (date +%s)
    set -l found 0
    # Update existing entry
    set -l new_counts
    for entry in $__ABBR_TIPS_FRECENCY_COUNTS
        set -l parts (string split ':' -- "$entry")
        if test "$parts[1]" = "$key"
            set -a new_counts "$key:"(math "$parts[2] + 1")
            set found 1
        else
            set -a new_counts "$entry"
        end
    end
    if test $found -eq 0
        set -a new_counts "$key:1"
    end
    set -g __ABBR_TIPS_FRECENCY_COUNTS $new_counts
    # Update timestamp
    set -l new_times
    set -l found_time 0
    for entry in $__ABBR_TIPS_FRECENCY_TIMES
        set -l parts (string split ':' -- "$entry")
        if test "$parts[1]" = "$key"
            set -a new_times "$key:$now"
            set found_time 1
        else
            set -a new_times "$entry"
        end
    end
    if test $found_time -eq 0
        set -a new_times "$key:$now"
    end
    set -g __ABBR_TIPS_FRECENCY_TIMES $new_times
end

function __abbr_tips_in_cooldown -d "Check if abbreviation is in cooldown"
    set -l key $argv[1]
    for entry in $__ABBR_TIPS_LAST_SHOWN
        set -l parts (string split ':' -- "$entry")
        if test "$parts[1]" = "$key"
            set -l now (date +%s)
            set -l elapsed (math "$now - $parts[2]")
            test $elapsed -lt $ABBR_TIPS_COOLDOWN
            return
        end
    end
    return 1
end

function __abbr_tips_mark_shown -d "Mark abbreviation as shown for cooldown"
    set -l key $argv[1]
    set -l now (date +%s)
    set -l found 0
    set -l new_shown
    for entry in $__ABBR_TIPS_LAST_SHOWN
        set -l parts (string split ':' -- "$entry")
        if test "$parts[1]" = "$key"
            set -a new_shown "$key:$now"
            set found 1
        else
            set -a new_shown "$entry"
        end
    end
    if test $found -eq 0
        set -a new_shown "$key:$now"
    end
    set -g __ABBR_TIPS_LAST_SHOWN $new_shown
end

function __abbr_tips --on-event fish_postexec -d "Abbreviation reminder for the current command"
    set -l command (string split ' ' -- "$argv")
    set -l cmd (string replace -r -a '\\s+' ' ' -- "$argv" )

    # Update abbreviations lists when adding/removing abbreviations
    if test "$command[1]" = abbr
        argparse --name abbr --ignore-unknown a/add e/erase g/global U/universal -- $command

        if set -q _flag_a
            and not contains -- "$argv[2]" $__ABBR_TIPS_KEYS
            set -a __ABBR_TIPS_KEYS "$argv[2]"
            set -a __ABBR_TIPS_VALUES (trim_value "$argv[3..-1]")
        else if set -q _flag_e
            and set -l abb (contains -i -- "$argv[2]" $__ABBR_TIPS_KEYS)
            set -e __ABBR_TIPS_KEYS[$abb]
            set -e __ABBR_TIPS_VALUES[$abb]
        end
    else if test "$command[1]" = alias
        set -l alias_key
        set -l alias_value

        argparse --name alias --ignore-unknown s/save -- $command

        if string match -q '*=*' -- "$argv[2]"
            set command_split (string split '=' -- $argv[2])
            set alias_key "a__$command_split[1]"
            set alias_value $command_split[2..-1]
        else
            set alias_key "a__$argv[2]"
            set alias_value $argv[3..-1]
        end

        set alias_value (trim_value "$alias_value")

        if set -l abb (contains -i -- "$argv[3..-1]" $__ABBR_TIPS_KEYS)
            set __ABBR_TIPS_KEYS[$abb] $alias_key
            set __ABBR_TIPS_VALUES[$abb] $alias_value
        else
            set -a __ABBR_TIPS_KEYS $alias_key
            set -a __ABBR_TIPS_VALUES $alias_value
        end
    else if test "$command[1]" = functions
        argparse --name functions e/erase -- $command

        if set -q _flag_e
            and set -l abb (contains -i -- a__{$argv[2]} $__ABBR_TIPS_KEYS)
            set -e __ABBR_TIPS_KEYS[$abb]
            set -e __ABBR_TIPS_VALUES[$abb]
        end
    end

    # Exit if abbreviation was used, command is already abbreviated, or not found
    if test $__abbr_tips_used = 1
        set -g __abbr_tips_used 0
        return
    else if abbr -q "$cmd"
        or not type -q "$command[1]"
        return
    else if string match -q -- "alias $cmd *" (alias)
        return
    else if test (type -t "$command[1]") = function
        and count $ABBR_TIPS_ALIAS_WHITELIST >/dev/null
        and not contains "$command[1]" $ABBR_TIPS_ALIAS_WHITELIST
        return
    end

    # Smart filtering: skip short commands
    if test (string length -- "$cmd") -lt $ABBR_TIPS_MIN_LENGTH
        return
    end

    # Find matching abbreviation(s)
    set -l candidates
    set -l abb
    if set abb (contains -i -- "$cmd" $__ABBR_TIPS_VALUES)
        set -a candidates "$abb"
    else
        for r in $ABBR_TIPS_REGEXES
            if set abb (contains -i -- (string replace -r -a -- "$r" '$1' "$cmd") $__ABBR_TIPS_VALUES)
                set -a candidates $abb
            end
        end
    end

    if test (count $candidates) -eq 0
        return
    end

    # Pick best candidate by frecency score
    set -l best_idx $candidates[1]
    set -l best_score -1
    for c in $candidates
        set -l key $__ABBR_TIPS_KEYS[$c]
        set -l score (__abbr_tips_frecency_score "$key")
        if math "$score > $best_score" >/dev/null 2>&1
            set best_idx $c
            set best_score $score
        end
    end

    # Cooldown check
    set -l best_key $__ABBR_TIPS_KEYS[$best_idx]
    if __abbr_tips_in_cooldown "$best_key"
        return
    end

    # Calculate savings
    set -l full_cmd $__ABBR_TIPS_VALUES[$best_idx]
    set -l abbr_cmd $__ABBR_TIPS_KEYS[$best_idx]
    set -l saved (math "(string length -- '$full_cmd') - (string length -- '$abbr_cmd')")

    # Record usage and mark shown
    __abbr_tips_record_use "$best_key"
    __abbr_tips_mark_shown "$best_key"

    # Update savings counter
    set -l total_saved $__ABBR_TIPS_SAVED_CHARS
    set -g __ABBR_TIPS_SAVED_CHARS (math "$total_saved + $saved")

    # Show the tip
    if string match -q "a__*" -- "$best_key"
        set -l alias (string sub -s 4 -- "$best_key")
        if functions -q "$alias"
            echo -e (string replace -a '{{ .saved }}' -- "$saved" \
                    (string replace -a '{{ .cmd }}' -- "$full_cmd" \
                    (string replace -a '{{ .abbr }}' -- "$alias" "$ABBR_TIPS_PROMPT")))
        else
            set -e __ABBR_TIPS_KEYS[$best_idx]
            set -e __ABBR_TIPS_VALUES[$best_idx]
        end
    else
        echo -e (string replace -a '{{ .saved }}' -- "$saved" \
                (string replace -a '{{ .cmd }}' -- "$full_cmd" \
                (string replace -a '{{ .abbr }}' -- "$best_key" "$ABBR_TIPS_PROMPT")))
    end

    # Show cumulative savings periodically (every 10 tips)
    if test (math "$__ABBR_TIPS_SAVED_CHARS % 50") -lt $saved
        and test $__ABBR_TIPS_SAVED_CHARS -gt 0
        echo -e "📊 \e[2mTotal keystrokes saved: $__ABBR_TIPS_SAVED_CHARS\e[0m"
    end

    return
end

function __abbr_tips_update --on-event abbr_tips_update
    __abbr_tips_clean
    __abbr_tips_install
end

function __abbr_tips_uninstall --on-event abbr_tips_uninstall
    __abbr_tips_clean
    functions --erase __abbr_tips_init
end
