#!/usr/bin/env fish

function fonts! --description '🎨 Elegant font installer'
    argparse f/force -- $argv || begin
        echo "
╭────────────────────────╮
│ Usage: fonts! URL      │
│        fonts! -f URL   │
╰────────────────────────╯
" && return 1
    end

    set -l tmp (mktemp -d)

    function _status
        printf "\r\33[2K\33[38;5;%dm%s\33[0m %s\n" $argv
    end

    printf "\n\33[38;5;105m%s\33[0m\n" "
     ╭──────────────────────────╮
     │    𝓕𝓸𝓷𝓽 𝓘𝓷𝓼𝓽𝓪𝓵𝓵𝓮𝓻 ✨    │
     ╰──────────────────────────╯"

    # Download with aria2c
    echo -n "  ⚡️ Fetching fonts..."
    command aria2c $argv[1] -d $tmp -q --max-concurrent-downloads=16 \
        --split=16 --min-split-size=1M --file-allocation=none \
        && printf "\r\33[2K  %s\n" "📦 Extracting..." \
        && bsdtar -xf $tmp/*.zip -C $tmp

    # Find fonts
    set -l fonts (fd -t f '\.(otf|ttf)$' $tmp)
    set -l total (count $fonts)

    echo "
  ╭─── Found $total fonts ───╮"

    # Install fonts in parallel
    for font in $fonts
        set -l name (basename $font)
        if test -e ~/Library/Fonts/$name && ! set -q _flag_force
            _status 214 "  │ ⊙" " $name"
        else
            if cp -f $font ~/Library/Fonts/
                _status 82 "  │ ✓" " $name"
            else
                _status 196 "  │ ⊘" " $name"
            end
        end
    end &

    wait
    rm -rf $tmp
    printf "  ╰────────────────────────╯\n\n"

    # Refresh font cache in background
    atsutil databases -remove >/dev/null 2>&1 &

    printf "  🎨 \33[38;5;105mCompleted!\33[0m\n\n"
end
