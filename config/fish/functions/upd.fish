function upd
    echo "[upd] updating ~/.dotfiles..."
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
      brew bundle --upgrade
      # echo "[upd] updating brew cask..."
      # brew cu --all --force --yes --quiet --include-mas
      # echo "[upd] upgrading brew packages..."
      # brew upgrade --greedy
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
end
