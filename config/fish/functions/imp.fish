function imp
    for url in $argv
        set -l dst (mktemp -d)
        echo [dir] $dst

        echo [dl] $url...
        curl $url -o $dst/dl.zip

        unzip -d $dst/album $dst/dl.zip

        echo [import] $dst...
        beet import $dst/album -I
    end
end
