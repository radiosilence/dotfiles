# Example usage of the values in a function
function opts
    # # Initialize default values
    set my_string "default string"
    set my_ints 42 41
    set my_bool false
    set script (basename (status -f))
    set -l options \
        s/my-string= \
        i/my-int=+ \
        b/my-bool \
        h/help

    echo $script
    # Parse command line arguments
    argparse --name=$script $options -- $argv
    or return 1

    function show_help
        echo "\
    Usage: $(basename $script) [OPTIONS] <files>
    Options:
        -s/--my-string=STRING   Set a custom string (default: $my_string)
        -i/--my-int=NUMBER      Set custom integers (default: $my_ints)
        -b/--my-bool            Enable boolean flag
        -h/--help               Show this help message"
    end

    # Show help message if requested
    if set -q _flag_help
        show_help
        return 0
    end

    # Update values based on provided flags
    if set -q _flag_my_string
        set my_string $_flag_my_string
    end

    if set -q _flag_my_ints
        set my_ints $_flag_my_ints
    end

    if set -q _flag_my_bool
        set my_bool true
    end

    if test (count $argv) -eq 0
        printf "Error: No files provided\n\n"
        show_help
        return 1
    end

    set files $argv

    # Use the values in your script
    echo "String value: $my_string"
    echo "Integer value: $my_ints"
    echo "Boolean value: $my_bool"

    echo "Doing something with:"
    echo "- String: $my_string"
    echo "- Integer:"

    for item in $my_ints
        echo "  - $item"
    end

    if test "$my_bool" = true
        echo "- Boolean flag is enabled!"
    else
        echo "- Boolean flag is disabled!"
    end
    echo "- Files:"
    for item in $files
        echo "  - $item"
    end
end
