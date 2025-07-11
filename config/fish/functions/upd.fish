function upd
    echo "[upd] updating ~/.dotfiles..."
    pushd ~
    sh ~/.dotfiles/install

    if using apt-get
        echo "[upd] updating apt..."
        sudo apt-get update
        sudo apt-get upgrade -y
        sudo apt-get autoremove -y
    end

    if using dnf
        echo "[upd] updating dnf..."
        sudo dnf update -y
    end

    if using brew
        echo "[upd] updating brew bundle..."
        brew bundle --upgrade --verbose
        echo "[upd] upgrading brew dependencies..."
        brew upgrade
        echo "[upd] cleaning up brew..."
        brew cleanup
    end

    if using mise
        echo "[upd] updating mise..."
        mise up
        rm -rf ~/.local/share/mise/shims
        mise reshim
    end

    if using yt-dlp
        echo "[upd] updating yt-dlp..."
        yt-dlp --update-to nightly
    end

    popd
end
