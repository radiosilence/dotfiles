#!/usr/bin/env fish

function fonts! --description '🎨 Elegant font installer'
    argparse f/force -- $argv || begin
        echo "
╭────────────────────────────╮
│ Usage: fonts! URL1 URL2... │
│        fonts! -f URL...    │
╰────────────────────────────╯
" && return 1
    end

    if test (count $argv) -eq 0
        echo "Error: Please provide at least one URL"
        return 1
    end

    function _status
        printf "\r\33[2K\33[38;5;%dm%s\33[0m %s\n" $argv
    end

    printf "\n\33[38;5;105m%s\33[0m\n" "
     ╭──────────────────────────╮
     │    𝓕𝓸𝓷𝓽 𝓘𝓷𝓼𝓽𝓪𝓵𝓵𝓮𝓻 ✨    │
     ╰──────────────────────────╯"

    set -l installed 0
    set -l skipped 0
    set -l failed 0

    for url in $argv
        # Create temp dir for this package
        set -l tmp (mktemp -d)

        # Download
        echo -n "  ⚡️ Fetching "(basename $url)"..."
        if command aria2c $url -d $tmp -q --max-concurrent-downloads=16 \
                --split=16 --min-split-size=1M --file-allocation=none
            printf "\r\33[2K  %s\n" "📦 Extracting..."
            bsdtar -xf $tmp/*.zip -C $tmp 2>/dev/null

            # Find and install fonts
            set -l fonts (fd -t f '\.(otf|ttf)$' $tmp)
            set -l total (count $fonts)

            echo "  ╭─── Found $total fonts in "(basename $url)" ───╮"

            for font in $fonts
                set -l name (basename $font)
                if test -e ~/Library/Fonts/$name && ! set -q _flag_force
                    _status 214 "  │ ⊙" " $name"
                    set skipped (math $skipped + 1)
                else
                    if cp -f $font ~/Library/Fonts/
                        _status 82 "  │ ✓" " $name"
                        set installed (math $installed + 1)
                    else
                        _status 196 "  │ ⊘" " $name"
                        set failed (math $failed + 1)
                    end
                end
            end
            echo "  ╰────────────────────────╯"
        else
            _status 196 "  │ ⊘" " Failed to download: "(basename $url)
        end
        # Clean up this package's temp dir
        rm -rf $tmp
    end

    # Final stats
    printf "\n  📊 \33[38;5;105mResults:\33[0m\n"
    test $installed -gt 0 && echo "     ✓ Installed: $installed fonts"
    test $skipped -gt 0 && echo "     ⊙ Skipped: $skipped fonts"
    test $failed -gt 0 && echo "     ⊘ Failed: $failed fonts"

    # Refresh font cache in background
    atsutil databases -remove >/dev/null 2>&1 &

    printf "\n  🎨 \33[38;5;105mAll done!\33[0m\n\n"
end
