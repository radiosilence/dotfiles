# 🌐 Browser Schedule

Switch default browser based on work hours. Chrome during work, personal browser otherwise.

## Setup

```sh
cd ~/.dotfiles/packages/browser-schedule
task install
```

This creates `~/.config/browser-schedule/config.toml` with default settings.

## Configuration

Edit `~/.config/browser-schedule/config.toml`:

```toml
[browsers]
work = "Google Chrome"
personal = "Zen"

[urls]
personal = ["reddit.com", "news.ycombinator.com"]
work = ["atlassian.net", "meet.google.com", "figma.com"]

[work_time]
start = "9:00"
end = "18:00"

[work_days]
start = "Mon"
end = "Fri"

# [log]
# enabled = false
```

### Features

- **URL overrides**: Specific URL fragments always open in the specified browser
- **Private overrides**: Create `config.local.toml` with same format (merged with main config)
- **Work schedule**: Time and day ranges for automatic browser selection
- **Night shifts**: Inverse time ranges (e.g., "18:00"-"9:00") span midnight
- **Logging**: Add `[log]` section with `enabled = true` for unified logging

## Commands

- `task status` - Check installation status
- `task config` - Show current config
- `task logs` - View activity logs
