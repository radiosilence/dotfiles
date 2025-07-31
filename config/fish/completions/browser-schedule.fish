function __browser-schedule_should_offer_completions_for -a expected_commands -a expected_positional_index
    set -l unparsed_tokens (__browser-schedule_tokens -pc)
    set -l positional_index 0
    set -l commands

    switch $unparsed_tokens[1]
    case 'browser-schedule'
        __browser-schedule_parse_subcommand 0 'h/help'
        switch $unparsed_tokens[1]
        case 'config'
            __browser-schedule_parse_subcommand 0 'h/help'
        case 'set-default'
            __browser-schedule_parse_subcommand 0 'h/help'
        case 'run'
            __browser-schedule_parse_subcommand 1 'h/help'
        case 'help'
            __browser-schedule_parse_subcommand -r 1 
        end
    end

    test "$commands" = "$expected_commands" -a \( -z "$expected_positional_index" -o "$expected_positional_index" -eq "$positional_index" \)
end

function __browser-schedule_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __browser-schedule_parse_subcommand -S
    argparse -s r -- $argv
    set -l positional_count $argv[1]
    set -l option_specs $argv[2..]

    set -a commands $unparsed_tokens[1]
    set -e unparsed_tokens[1]

    set positional_index 0

    while true
        argparse -sn "$commands" $option_specs -- $unparsed_tokens 2> /dev/null
        set unparsed_tokens $argv
        set positional_index (math $positional_index + 1)
        if test (count $unparsed_tokens) -eq 0 -o \( -z "$_flag_r" -a "$positional_index" -gt "$positional_count" \)
            return 0
        end
        set -e unparsed_tokens[1]
    end
end

function __browser-schedule_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf '%s\n' $subdirs
end

function __browser-schedule_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION

    set -l tokens (__browser-schedule_tokens -p)
    if test -z (__browser-schedule_tokens -t)
        set -l index (count (__browser-schedule_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'browser-schedule' -f
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule" 1' -fa 'config' -d 'Display current configuration and status'
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule" 1' -fa 'set-default' -d 'Set BrowserSchedule as the default browser'
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule" 1' -fa 'run' -d 'Run as background app (default mode)'
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule" 1' -fa 'help' -d 'Show subcommand help information.'
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule config"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule set-default"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'browser-schedule' -n '__browser-schedule_should_offer_completions_for "browser-schedule run"' -s 'h' -l 'help' -d 'Show help information.'
