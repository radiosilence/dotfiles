package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/spf13/cobra"
)

func main() {
	var days int
	var maxCycles int
	var jsonOutput bool

	var rootCmd = &cobra.Command{
		Use:   "sleep-report",
		Short: "Generate sleep reports for macOS",
		Long:  `A lightweight tool to analyze macOS sleep patterns and generate health reports.`,
		Run: func(cmd *cobra.Command, args []string) {
			if jsonOutput {
				reportData, err := GenerateReportData(days, maxCycles)
				if err != nil {
					log.Fatal(err)
				}
				jsonBytes, err := json.MarshalIndent(reportData, "", "  ")
				if err != nil {
					log.Fatal(err)
				}
				fmt.Print(string(jsonBytes))
			} else {
				report, err := GenerateSleepReport(days, maxCycles)
				if err != nil {
					log.Fatal(err)
				}
				fmt.Print(report)
			}
		},
	}

	rootCmd.Flags().IntVarP(&days, "days", "d", 7, "Number of days to analyze (default: 7)")
	rootCmd.Flags().IntVarP(&maxCycles, "cycles", "c", 20, "Maximum number of sleep cycles to show (default: 20)")
	rootCmd.Flags().BoolVar(&jsonOutput, "json", false, "Output report as JSON")

	// Add completion subcommand
	var completionCmd = &cobra.Command{
		Use:   "completion [bash|zsh|fish]",
		Short: "Generate completion script",
		Long: `To load completions:

Bash:
  $ source <(sleep-report completion bash)

  # To load completions for each session, execute once:
  # Linux:
  $ sleep-report completion bash > /etc/bash_completion.d/sleep-report
  # macOS:
  $ sleep-report completion bash > /usr/local/etc/bash_completion.d/sleep-report

Zsh:
  # If shell completion is not already enabled in your environment,
  # you will need to enable it.  You can execute the following once:
  $ echo "autoload -U compinit; compinit" >> ~/.zshrc

  # To load completions for each session, execute once:
  $ sleep-report completion zsh > "${fpath[1]}/_sleep-report"

  # You will need to start a new shell for this setup to take effect.

Fish:
  $ sleep-report completion fish | source

  # To load completions for each session, execute once:
  $ sleep-report completion fish > ~/.config/fish/completions/sleep-report.fish
`,
		DisableFlagsInUseLine: true,
		ValidArgs:             []string{"bash", "zsh", "fish"},
		Args:                  cobra.ExactValidArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			switch args[0] {
			case "bash":
				rootCmd.GenBashCompletion(os.Stdout)
			case "zsh":
				rootCmd.GenZshCompletion(os.Stdout)
			case "fish":
				rootCmd.GenFishCompletion(os.Stdout, true)
			}
		},
	}

	rootCmd.AddCommand(completionCmd)

	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}