package main

import (
	"bufio"
	"fmt"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

type SleepEvent struct {
	Timestamp time.Time     `json:"timestamp"`
	Event     string        `json:"event"`
	Process   string        `json:"process"`
	Duration  time.Duration `json:"duration"`
	Details   string        `json:"details"`
}

type SleepCycle struct {
	SleepTime     time.Time     `json:"sleep_time"`
	WakeTime      time.Time     `json:"wake_time"`
	SleepReason   string        `json:"sleep_reason"`
	WakeReason    string        `json:"wake_reason"`
	SleepBattery  int           `json:"sleep_battery"`
	WakeBattery   int           `json:"wake_battery"`
	SleepPower    string        `json:"sleep_power"` // "AC" or "BATT"
	WakePower     string        `json:"wake_power"`
	Duration      time.Duration `json:"duration"`
}

type BatteryEvent struct {
	Timestamp time.Time `json:"timestamp"`
	Level     int       `json:"level"`
	Status    string    `json:"status"`
}

type SleepReport struct {
	Events        []SleepEvent   `json:"events"`
	BatteryEvents []BatteryEvent `json:"battery_events"`
	SleepCycles   []SleepCycle   `json:"sleep_cycles"`
	HealthScore   int            `json:"health_score"`
	Issues        []string       `json:"issues"`
	Summary       string         `json:"summary"`
	Days          int            `json:"days"`
	MaxCycles     int            `json:"max_cycles"`
	GeneratedAt   time.Time      `json:"generated_at"`
}

func GetSleepEvents(days int) ([]SleepEvent, error) {
	cmd := exec.Command("pmset", "-g", "log")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get pmset log: %w", err)
	}

	var events []SleepEvent
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	
	// Regex patterns for different event types
	preventSleepPattern := regexp.MustCompile(`(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) .* PID (\d+)\((.+?)\) .*(PreventUserIdleSystemSleep|PreventUserIdleDisplaySleep).*?"(.+?)".*?(\d{2}:\d{2}:\d{2})`)
	
	for scanner.Scan() {
		line := scanner.Text()
		
		// Parse prevent sleep events
		if matches := preventSleepPattern.FindStringSubmatch(line); matches != nil {
			timestamp, err := time.Parse("2006-01-02 15:04:05", matches[1])
			if err != nil {
				continue
			}
			
			duration, err := time.ParseDuration(strings.ReplaceAll(matches[6], ":", "h") + "m0s")
			if err != nil {
				duration = 0
			}
			
			event := SleepEvent{
				Timestamp: timestamp,
				Event:     matches[4],
				Process:   matches[3],
				Duration:  duration,
				Details:   matches[5],
			}
			
			// Only include events from the specified number of days
			if time.Since(timestamp) <= time.Duration(days)*24*time.Hour {
				events = append(events, event)
			}
		}
	}
	
	return events, nil
}

func GetSleepCycles(days int) ([]SleepCycle, error) {
	cmd := exec.Command("pmset", "-g", "log")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get pmset log: %w", err)
	}

	var cycles []SleepCycle
	var currentSleep *SleepCycle
	
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	
	// Regex patterns for sleep and wake events
	sleepPattern := regexp.MustCompile(`(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) .* Sleep.*Entering Sleep state due to '(.+?)':.*Using (AC|Batt) \(Charge:(\d+)%\)`)
	wakePattern := regexp.MustCompile(`(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) .* (Wake|DarkWake).*due to (.+?) Using (AC|BATT) \(Charge:(\d+)%\)`)
	
	for scanner.Scan() {
		line := scanner.Text()
		
		// Parse sleep events
		if matches := sleepPattern.FindStringSubmatch(line); matches != nil {
			timestamp, err := time.Parse("2006-01-02 15:04:05", matches[1])
			if err != nil {
				continue
			}
			
			// Only include events from the specified number of days
			if time.Since(timestamp) > time.Duration(days)*24*time.Hour {
				continue
			}
			
			battery, err := strconv.Atoi(matches[4])
			if err != nil {
				battery = 0
			}
			
			// Complete previous cycle if exists
			if currentSleep != nil {
				cycles = append(cycles, *currentSleep)
			}
			
			// Start new cycle
			currentSleep = &SleepCycle{
				SleepTime:    timestamp,
				SleepReason:  matches[2],
				SleepBattery: battery,
				SleepPower:   matches[3],
			}
		}
		
		// Parse wake events
		if matches := wakePattern.FindStringSubmatch(line); matches != nil && currentSleep != nil {
			timestamp, err := time.Parse("2006-01-02 15:04:05", matches[1])
			if err != nil {
				continue
			}
			
			battery, err := strconv.Atoi(matches[5])
			if err != nil {
				battery = 0
			}
			
			// Complete current cycle
			currentSleep.WakeTime = timestamp
			currentSleep.WakeReason = matches[3]
			currentSleep.WakeBattery = battery
			currentSleep.WakePower = matches[4]
			currentSleep.Duration = timestamp.Sub(currentSleep.SleepTime)
			
			// Only include cycles that lasted more than 1 minute or are clamshell/idle sleep
			if currentSleep.Duration > time.Minute || 
			   strings.Contains(currentSleep.SleepReason, "Clamshell") ||
			   strings.Contains(currentSleep.SleepReason, "Idle") {
				cycles = append(cycles, *currentSleep)
			}
			currentSleep = nil
		}
	}
	
	// Handle incomplete cycle (laptop might still be asleep)
	if currentSleep != nil {
		cycles = append(cycles, *currentSleep)
	}
	
	return cycles, nil
}

func GetBatteryHistory() ([]BatteryEvent, error) {
	cmd := exec.Command("pmset", "-g", "batt")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get battery status: %w", err)
	}
	
	var events []BatteryEvent
	lines := strings.Split(string(output), "\n")
	
	batteryPattern := regexp.MustCompile(`(\d+)%; (charging|discharging|charged)`)
	
	for _, line := range lines {
		if matches := batteryPattern.FindStringSubmatch(line); matches != nil {
			level, err := strconv.Atoi(matches[1])
			if err != nil {
				continue
			}
			
			event := BatteryEvent{
				Timestamp: time.Now(),
				Level:     level,
				Status:    matches[2],
			}
			events = append(events, event)
		}
	}
	
	return events, nil
}

func CalculateHealthScore(events []SleepEvent) (int, []string) {
	score := 100
	var issues []string
	
	// Count sleep prevention events
	preventCount := 0
	longPreventions := 0
	
	for _, event := range events {
		if strings.Contains(event.Event, "PreventUserIdleSystemSleep") {
			preventCount++
			if event.Duration > 30*time.Minute {
				longPreventions++
			}
		}
	}
	
	// Deduct points for sleep prevention
	if preventCount > 50 {
		score -= 30
		issues = append(issues, fmt.Sprintf("High number of sleep prevention events (%d)", preventCount))
	} else if preventCount > 20 {
		score -= 15
		issues = append(issues, fmt.Sprintf("Moderate sleep prevention activity (%d events)", preventCount))
	}
	
	// Deduct more points for long-duration preventions
	if longPreventions > 10 {
		score -= 25
		issues = append(issues, fmt.Sprintf("Multiple long-duration sleep preventions (%d > 30min)", longPreventions))
	} else if longPreventions > 5 {
		score -= 15
		issues = append(issues, fmt.Sprintf("Some long-duration sleep preventions (%d > 30min)", longPreventions))
	}
	
	// Check for problematic processes
	processCount := make(map[string]int)
	for _, event := range events {
		if strings.Contains(event.Event, "PreventUserIdleSystemSleep") {
			processCount[event.Process]++
		}
	}
	
	for process, count := range processCount {
		if count > 20 {
			score -= 10
			issues = append(issues, fmt.Sprintf("Process '%s' frequently prevents sleep (%d times)", process, count))
		}
	}
	
	if score < 0 {
		score = 0
	}
	
	return score, issues
}

func GenerateReportData(days int, maxCycles int) (*SleepReport, error) {
	events, err := GetSleepEvents(days)
	if err != nil {
		return nil, err
	}
	
	batteryEvents, err := GetBatteryHistory()
	if err != nil {
		return nil, err
	}
	
	sleepCycles, err := GetSleepCycles(days)
	if err != nil {
		return nil, err
	}
	
	// Apply maxCycles limit to sleep cycles
	if len(sleepCycles) > maxCycles {
		sleepCycles = sleepCycles[len(sleepCycles)-maxCycles:]
	}
	
	healthScore, issues := CalculateHealthScore(events)
	
	report := &SleepReport{
		Events:        events,
		BatteryEvents: batteryEvents,
		SleepCycles:   sleepCycles,
		HealthScore:   healthScore,
		Issues:        issues,
		Days:          days,
		MaxCycles:     maxCycles,
		GeneratedAt:   time.Now(),
	}
	
	return report, nil
}

func GenerateSleepReport(days int, maxCycles int) (string, error) {
	report, err := GenerateReportData(days, maxCycles)
	if err != nil {
		return "", err
	}
	
	// Get all cycles for the summary (before truncation)
	allCycles, err := GetSleepCycles(days)
	if err != nil {
		return "", err
	}
	
	return FormatMarkdownReport(report, days, maxCycles, allCycles), nil
}

func FormatMarkdownReport(report *SleepReport, days int, maxCycles int, allCycles []SleepCycle) string {
	var sb strings.Builder
	
	sb.WriteString("# Sleep Health Report\n\n")
	sb.WriteString(fmt.Sprintf("**Generated:** %s\n", time.Now().Format("2006-01-02 15:04:05")))
	if days == 1 {
		sb.WriteString("**Period:** Last 1 day\n\n")
	} else {
		sb.WriteString(fmt.Sprintf("**Period:** Last %d days\n\n", days))
	}
	
	// Health Score
	sb.WriteString("## Health Score\n\n")
	scoreEmoji := "🟢"
	if report.HealthScore < 70 {
		scoreEmoji = "🟡"
	}
	if report.HealthScore < 50 {
		scoreEmoji = "🔴"
	}
	sb.WriteString(fmt.Sprintf("%s **%d/100**\n\n", scoreEmoji, report.HealthScore))
	
	// Issues
	if len(report.Issues) > 0 {
		sb.WriteString("## Issues Found\n\n")
		for _, issue := range report.Issues {
			sb.WriteString(fmt.Sprintf("- ⚠️ %s\n", issue))
		}
		sb.WriteString("\n")
	}
	
	// Battery Status
	if len(report.BatteryEvents) > 0 {
		sb.WriteString("## Battery Status\n\n")
		for _, event := range report.BatteryEvents {
			sb.WriteString(fmt.Sprintf("- **%d%%** - %s\n", event.Level, event.Status))
		}
		sb.WriteString("\n")
	}
	
	// Sleep Cycles
	sb.WriteString("## Sleep Cycles\n\n")
	if len(report.SleepCycles) == 0 {
		if days == 1 {
			sb.WriteString("⚠️ No sleep cycles detected in the last 1 day.\n\n")
		} else {
			sb.WriteString(fmt.Sprintf("⚠️ No sleep cycles detected in the last %d days.\n\n", days))
		}
	} else {
		if days == 1 {
			sb.WriteString(fmt.Sprintf("Found **%d sleep cycles** in the last 1 day:\n\n", len(report.SleepCycles)))
		} else {
			sb.WriteString(fmt.Sprintf("Found **%d sleep cycles** in the last %d days:\n\n", len(report.SleepCycles), days))
		}
		
		// Show only latest N cycles to avoid overwhelming output
		startIndex := 0
		if len(report.SleepCycles) > maxCycles {
			startIndex = len(report.SleepCycles) - maxCycles
		}
		
		for i := startIndex; i < len(report.SleepCycles); i++ {
			cycle := report.SleepCycles[i]
			sb.WriteString(fmt.Sprintf("### Sleep Cycle %d\n\n", i+1))
			
			// Sleep info
			sb.WriteString(fmt.Sprintf("**Sleep:** %s\n", cycle.SleepTime.Format("Jan 2, 15:04")))
			sb.WriteString(fmt.Sprintf("- Reason: %s\n", cycle.SleepReason))
			sb.WriteString(fmt.Sprintf("- Battery: %d%% (%s)\n", cycle.SleepBattery, cycle.SleepPower))
			
			// Wake info (if available)
			if !cycle.WakeTime.IsZero() {
				sb.WriteString(fmt.Sprintf("\n**Wake:** %s\n", cycle.WakeTime.Format("Jan 2, 15:04")))
				sb.WriteString(fmt.Sprintf("- Reason: %s\n", cycle.WakeReason))
				sb.WriteString(fmt.Sprintf("- Battery: %d%% (%s)\n", cycle.WakeBattery, cycle.WakePower))
				sb.WriteString(fmt.Sprintf("- Duration: %s\n", formatDuration(cycle.Duration)))
				
				// Battery drain analysis
				if cycle.SleepBattery > 0 && cycle.WakeBattery > 0 {
					drain := cycle.SleepBattery - cycle.WakeBattery
					if drain > 0 {
						hours := cycle.Duration.Hours()
						if hours > 0 {
							drainRate := float64(drain) / hours
							sb.WriteString(fmt.Sprintf("- Battery drain: %d%% (%.1f%%/hour)\n", drain, drainRate))
						}
					}
				}
			} else {
				sb.WriteString("\n**Status:** Still sleeping or incomplete cycle\n")
			}
			
			sb.WriteString("\n")
		}
		
		if len(report.SleepCycles) > maxCycles {
			sb.WriteString(fmt.Sprintf("*Showing latest %d of %d cycles. Use a shorter time period for fewer results.*\n\n", maxCycles, len(report.SleepCycles)))
		}
		
		// Add grouped summary of all cycles (not just displayed ones)
		sb.WriteString("### Sleep/Wake Reasons Summary\n\n")
		
		// Group sleep reasons from all cycles
		sleepReasons := make(map[string]int)
		wakeReasons := make(map[string]int)
		
		// Use all cycles for the summary (not just the truncated ones for display)
		for _, cycle := range allCycles {
			sleepReasons[cycle.SleepReason]++
			if cycle.WakeReason != "" {
				wakeReasons[cycle.WakeReason]++
			}
		}
		
		// Sort and display sleep reasons
		type reasonCount struct {
			reason string
			count  int
		}
		
		var sleepReasonsList []reasonCount
		for reason, count := range sleepReasons {
			sleepReasonsList = append(sleepReasonsList, reasonCount{reason, count})
		}
		sort.Slice(sleepReasonsList, func(i, j int) bool {
			return sleepReasonsList[i].count > sleepReasonsList[j].count
		})
		
		var wakeReasonsList []reasonCount
		for reason, count := range wakeReasons {
			wakeReasonsList = append(wakeReasonsList, reasonCount{reason, count})
		}
		sort.Slice(wakeReasonsList, func(i, j int) bool {
			return wakeReasonsList[i].count > wakeReasonsList[j].count
		})
		
		sb.WriteString("**Sleep Reasons:**\n")
		for _, rc := range sleepReasonsList {
			sb.WriteString(fmt.Sprintf("- %s: %d times\n", rc.reason, rc.count))
		}
		
		sb.WriteString("\n**Wake Reasons:**\n")
		for _, rc := range wakeReasonsList {
			sb.WriteString(fmt.Sprintf("- %s: %d times\n", rc.reason, rc.count))
		}
		sb.WriteString("\n")
	}
	
	// Recent Sleep Prevention Events
	sb.WriteString("## Recent Sleep Prevention Events\n\n")
	if len(report.Events) == 0 {
		if days == 1 {
			sb.WriteString("✅ No sleep prevention events detected in the last 1 day.\n\n")
		} else {
			sb.WriteString(fmt.Sprintf("✅ No sleep prevention events detected in the last %d days.\n\n", days))
		}
	} else {
		// Group events by process
		processEvents := make(map[string][]SleepEvent)
		for _, event := range report.Events {
			processEvents[event.Process] = append(processEvents[event.Process], event)
		}
		
		for process, events := range processEvents {
			sb.WriteString(fmt.Sprintf("### %s (%d events)\n\n", process, len(events)))
			
			// Show most recent events (max 5)
			maxEvents := 5
			if len(events) < maxEvents {
				maxEvents = len(events)
			}
			
			for i := 0; i < maxEvents; i++ {
				event := events[i]
				sb.WriteString(fmt.Sprintf("- **%s** - %s", 
					event.Timestamp.Format("Jan 2, 15:04"), 
					event.Details))
				if event.Duration > 0 {
					sb.WriteString(fmt.Sprintf(" (Duration: %s)", event.Duration.String()))
				}
				sb.WriteString("\n")
			}
			
			if len(events) > maxEvents {
				sb.WriteString(fmt.Sprintf("- ... and %d more events\n", len(events)-maxEvents))
			}
			sb.WriteString("\n")
		}
	}
	
	// Recommendations
	sb.WriteString("## Recommendations\n\n")
	if report.HealthScore >= 80 {
		sb.WriteString("✅ Your sleep patterns look healthy! Your laptop should be sleeping properly when the lid is closed.\n\n")
	} else {
		sb.WriteString("Consider the following to improve sleep health:\n\n")
		
		if len(report.Issues) > 0 {
			for _, issue := range report.Issues {
				if strings.Contains(issue, "coreaudiod") {
					sb.WriteString("- Audio processes are preventing sleep - consider closing audio applications before closing the lid\n")
				} else if strings.Contains(issue, "sharingd") {
					sb.WriteString("- Sharing services (AirDrop, Handoff) are preventing sleep - check System Preferences > General > AirDrop & Handoff\n")
				} else if strings.Contains(issue, "powerd") {
					sb.WriteString("- Display is preventing sleep - ensure display sleep is configured properly\n")
				} else {
					sb.WriteString(fmt.Sprintf("- Address: %s\n", issue))
				}
			}
		}
		
		sb.WriteString("- Run `pmset -g assertions` to see current sleep preventions\n")
		sb.WriteString("- Check `pmset -g` for your current power settings\n")
		sb.WriteString("- Consider running `sudo pmset -a hibernatemode 25` for better sleep reliability\n")
	}
	
	return sb.String()
}

func formatDuration(d time.Duration) string {
	if d < time.Hour {
		return fmt.Sprintf("%dm", int(d.Minutes()))
	} else if d < 24*time.Hour {
		hours := int(d.Hours())
		minutes := int(d.Minutes()) % 60
		return fmt.Sprintf("%dh %dm", hours, minutes)
	} else {
		days := int(d.Hours()) / 24
		hours := int(d.Hours()) % 24
		return fmt.Sprintf("%dd %dh", days, hours)
	}
}