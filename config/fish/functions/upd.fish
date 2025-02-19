function upd
    echo "[upd] updating ~/.dotfiles..."
    sh ~/.dotfiles/install

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

    if using apt
        echo "[upd] updating apt..."
        sudo apt update
        sudo apt upgrade -y
        sudo apt autoremove -y
    end

    if using dnf
        echo "[upd] updating dnf..."
        sudo dnf update -y
    end

    if using brew
        echo "[upd] updating brew..."
        brew bundle --force
        brew upgrade
        brew cu -af
        mas upgrade
        brew cleanup
        brew doctor
    end
end
