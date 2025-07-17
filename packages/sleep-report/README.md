# Sleep Report

A lightweight Go package that generates sleep health reports for macOS using `pmset` and other system utilities.

## Features

- Analyzes sleep prevention events from the last 7 days
- Tracks battery charge levels and status
- Provides a health score (0-100) based on sleep patterns
- Identifies problematic processes preventing sleep
- Generates markdown reports with actionable recommendations
- Detects when laptop fails to sleep properly with lid closed

## Installation

```bash
cd packages/sleep-report
go build -o sleep-report
./sleep-report
```

Or install globally:

```bash
go install github.com/james.cleveland/.dotfiles/packages/sleep-report@latest
```

## Usage

Simply run the command to generate a report:

```bash
./sleep-report
```

### Options

- `--days, -d`: Number of days to analyze (default: 7)
- `--cycles, -c`: Maximum number of sleep cycles to show (default: 20)
- `--json`: Output report as JSON instead of markdown

Examples:
```bash
# Generate report for last 3 days, show 10 cycles
./sleep-report --days 3 --cycles 10

# Generate JSON output for last 24 hours
./sleep-report --days 1 --json

# Short form
./sleep-report -d 5 -c 15
```

The output is a markdown-formatted report showing:
- Overall health score with color-coded status
- Battery status and charge level
- Detailed sleep cycles with timestamps, reasons, and battery info
- Recent sleep prevention events grouped by process
- Specific issues found and recommendations

## Health Score

The health score is calculated based on:
- Number of sleep prevention events (lower is better)
- Duration of sleep preventions (shorter is better)
- Frequency of problematic processes
- Overall sleep hygiene patterns

## Common Issues

The tool identifies common macOS sleep issues:
- Audio processes (`coreaudiod`) preventing sleep
- Sharing services (`sharingd`) for AirDrop/Handoff
- Display management (`powerd`) issues
- Third-party applications holding sleep assertions

## Requirements

- macOS (uses `pmset` command)
- Go 1.21 or later
- No additional dependencies required

## Example Output

```markdown
# Sleep Health Report

**Generated:** 2025-07-17 12:07:52
**Period:** Last 7 days

## Health Score

🟢 **100/100**

## Battery Status

- **67%** - discharging

## Recent Sleep Prevention Events

✅ No sleep prevention events detected in the last 7 days.

## Recommendations

✅ Your sleep patterns look healthy! Your laptop should be sleeping properly when the lid is closed.
```