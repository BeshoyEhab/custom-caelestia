function __abbr_tips_clean -d "Clean plugin variables and functions"
    bind --erase \n
    bind --erase \r
    bind --erase " "
    set --erase __abbr_tips_used
    set --erase __abbr_tips_run_once
    set --erase __ABBR_TIPS_VALUES
    set --erase __ABBR_TIPS_KEYS
    set --erase __ABBR_TIPS_FRECENCY_COUNTS
    set --erase __ABBR_TIPS_FRECENCY_TIMES
    set --erase __ABBR_TIPS_LAST_SHOWN
    set --erase __ABBR_TIPS_SAVED_CHARS
    set --erase ABBR_TIPS_PROMPT
    set --erase ABBR_TIPS_AUTO_UPDATE
    set --erase ABBR_TIPS_ALIAS_WHITELIST
    set --erase ABBR_TIPS_REGEXES
    set --erase ABBR_TIPS_COOLDOWN
    set --erase ABBR_TIPS_MIN_LENGTH
    functions --erase __abbr_tips_bind_newline
    functions --erase __abbr_tips_bind_space
    functions --erase __abbr_tips
    functions --erase __abbr_tips_frecency_score
    functions --erase __abbr_tips_record_use
    functions --erase __abbr_tips_in_cooldown
    functions --erase __abbr_tips_mark_shown
end
