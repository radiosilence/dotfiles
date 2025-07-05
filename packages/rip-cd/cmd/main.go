package main

import (
	"fmt"
	"os"

	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/config"
	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/metadata"
	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/ripper"
	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/setup"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

const (
	version = "2.0.0"
	name    = "rip-cd"
)

var (
	cfgFile   string
	workspace string
	dryRun    bool
	verbose   bool
	debug     bool
	overwrite bool
)

func main() {
	if err := rootCmd.Execute(); err != nil {
		logrus.Fatal(err)
	}
}

var rootCmd = &cobra.Command{
	Use:   name,
	Short: "CD Ripper with metadata management and strong typing",
	Long: `A modern CD ripper with metadata management, MusicBrainz integration,
and strongly-typed configuration support.

Supports YAML configuration with JSON schema validation for type safety.`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		if debug {
			logrus.SetLevel(logrus.DebugLevel)
		} else if verbose {
			logrus.SetLevel(logrus.InfoLevel)
		} else {
			logrus.SetLevel(logrus.WarnLevel)
		}

		logrus.SetFormatter(&logrus.TextFormatter{
			FullTimestamp: true,
		})
	},
}

var ripCmd = &cobra.Command{
	Use:   "rip [config-file]",
	Short: "Rip a CD using the provided configuration",
	Long: `Rip a CD using the metadata and settings from the configuration file.
The configuration file should be in YAML format.`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		configFile := args[0]

		cfg, err := config.Load(configFile, workspace)
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}

		meta, err := metadata.Parse(configFile)
		if err != nil {
			return fmt.Errorf("failed to parse metadata: %w", err)
		}

		if dryRun {
			logrus.Info("🎯 Dry run mode - showing what would be done")
			return ripper.DryRun(cfg, meta)
		}

		return ripper.Rip(cfg, meta)
	},
}

var generateCmd = &cobra.Command{
	Use:   "generate",
	Short: "Generate templates and schemas",
	Long:  "Generate configuration templates and validation schemas",
}

var generateTemplateCmd = &cobra.Command{
	Use:   "template [format]",
	Short: "Generate a configuration template",
	Long: `Generate a configuration template file.
Supported formats: yaml (default)`,
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		format := "yaml"
		if len(args) > 0 {
			format = args[0]
		}

		cfg, err := config.Load("", workspace)
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}

		return metadata.GenerateTemplate(cfg, format, overwrite)
	},
}

var generateSchemaCmd = &cobra.Command{
	Use:   "schema [format]",
	Short: "Generate validation schema",
	Long: `Generate a validation schema file.
Supported formats: json (default)`,
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		format := "json"
		if len(args) > 0 {
			format = args[0]
		}

		cfg, err := config.Load("", workspace)
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}

		return metadata.GenerateSchema(cfg, format, overwrite)
	},
}

var generateConfigCmd = &cobra.Command{
	Use:   "config",
	Short: "Generate default configuration file",
	Long: `Generate a default configuration file at ~/.rip-cd.yaml.
This creates a configuration file with sensible defaults for CD ripping.
The file will not be overwritten if it already exists.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return config.GenerateDefault(overwrite)
	},
}

var validateCmd = &cobra.Command{
	Use:   "validate [config-file]",
	Short: "Validate a configuration file",
	Long: `Validate a configuration file against the schema.
Supports YAML format with JSON schema validation.`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		configFile := args[0]

		cfg, err := config.Load("", workspace)
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}

		return metadata.Validate(cfg, configFile)
	},
}

var setupCmd = &cobra.Command{
	Use:   "setup",
	Short: "Install essential dependencies for CD ripping",
	Long: `Install only the essential dependencies needed for CD ripping and tagging.
This will update your Brewfile with the minimal required packages:
- XLD (for CD ripping)
- flac (for metadata tools)
- ffmpeg (for audio processing)
- Python packages (beets, musicbrainzngs, etc.)`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return setup.Run(dryRun, verbose)
	},
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("%s v%s\n", name, version)
		fmt.Println("CD ripper with verification and metadata management 🎵")
	},
}

var completionCmd = &cobra.Command{
	Use:   "completion [bash|zsh|fish]",
	Short: "Generate completion script",
	Long: `Generate the autocompletion script for the specified shell.

To load completions:

Bash:
  $ source <(rip-cd completion bash)

  # To load completions for each session, execute once:
  # Linux:
  $ rip-cd completion bash > /etc/bash_completion.d/rip-cd
  # macOS:
  $ rip-cd completion bash > $(brew --prefix)/etc/bash_completion.d/rip-cd

Zsh:
  # If shell completion is not already enabled, enable it:
  $ echo "autoload -U compinit; compinit" >> ~/.zshrc

  # To load completions for each session, execute once:
  $ rip-cd completion zsh > "${fpath[1]}/_rip-cd"

  # Start a new shell for this setup to take effect.

Fish:
  $ rip-cd completion fish | source

  # To load completions for each session, execute once:
  $ rip-cd completion fish > ~/.config/fish/completions/rip-cd.fish
`,
	DisableFlagsInUseLine: true,
	ValidArgs:             []string{"bash", "zsh", "fish"},
	Args:                  cobra.MatchAll(cobra.ExactArgs(1), cobra.OnlyValidArgs),
	Run: func(cmd *cobra.Command, args []string) {
		switch args[0] {
		case "bash":
			cmd.Root().GenBashCompletion(os.Stdout)
		case "zsh":
			cmd.Root().GenZshCompletion(os.Stdout)
		case "fish":
			cmd.Root().GenFishCompletion(os.Stdout, true)
		}
	},
}

func init() {
	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default: $HOME/.rip-cd.yaml)")
	rootCmd.PersistentFlags().StringVar(&workspace, "workspace", "", "workspace directory (default: $HOME/cd_ripping)")
	rootCmd.PersistentFlags().BoolVar(&dryRun, "dry-run", false, "show what would be done without actually doing it")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")
	rootCmd.PersistentFlags().BoolVar(&debug, "debug", false, "debug output")

	// Add subcommands
	rootCmd.AddCommand(ripCmd)
	rootCmd.AddCommand(generateCmd)
	rootCmd.AddCommand(validateCmd)
	rootCmd.AddCommand(setupCmd)
	rootCmd.AddCommand(completionCmd)
	rootCmd.AddCommand(versionCmd)

	// Add generate subcommands
	generateCmd.AddCommand(generateTemplateCmd)
	generateCmd.AddCommand(generateSchemaCmd)
	generateCmd.AddCommand(generateConfigCmd)

	// Add overwrite flag to generation commands
	generateTemplateCmd.Flags().BoolVar(&overwrite, "overwrite", false, "overwrite existing files")
	generateSchemaCmd.Flags().BoolVar(&overwrite, "overwrite", false, "overwrite existing files")
	generateConfigCmd.Flags().BoolVar(&overwrite, "overwrite", false, "overwrite existing files")
}
