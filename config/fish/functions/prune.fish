function prune
    set min_size 3096
    set target_dir .
    set script (basename (status -f))
    set to_delete

    argparse --name=$script m/min-size= -- $argv

    if set -q _flag_min_size
        set min_size $_flag_min_size
    end

    function get_path
        echo $argv[1] | awk '{print $2}'
    end

    function get_size
        echo $argv[1] | awk '{print $1 * 1024}' | numfmt --to=iec
    end

    set candidates (find $target_dir -type d -exec du -sk {} + | awk -v min=$min_size '$1 < min { $1=""; sub(/^ /, ""); print }')

    for path in $candidates
        if test $path = "."; or string match -rq "\.*.(stfolder|git).*" $path
            continue
        end
        set to_delete $to_delete $path
    end

    if test (count $to_delete) = 0
        echo "No directories below $min_size kB in $target_dir"
        return 1
    end

    echo "The following directories are below $min_size kB and would be deleted:"

    for path in $to_delete
        du -hs $path
    end

    read -P "Are you sure you want to delete these directories? [y/N] " confirm

    if string match -i y $confirm
        for path in $to_delete
            if test $path = "."
                continue
            end
            if test -d $path
                echo "Deleting $path"
                rm -rf $path
            end
        end
        echo "Directories deleted."
    else
        echo "Operation canceled."
    end

end
