# Static globals with no tool-specific conf.d file of their own. Anything that
# needs to vary per-directory belongs in mise, not here.

export KERL_BUILD_DOCS=yes
export DD_TOKEN_STORAGE=file  # pup OAuth tokens in ~/.config/pup/ (0600) instead of keychain
