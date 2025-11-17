use clap::{Command, CommandFactory};
use clap_complete::{generate_to, Shell};
use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let shell = Shell::Zsh;
    let outdir =
        PathBuf::from(env::var("HOME").expect("HOME not set")).join(".config/zsh/completions");

    fs::create_dir_all(&outdir).expect("Failed to create completions dir");

    println!("Generating completions for Rust tools...");

    // List of all our tools with their clap Commands
    let tools = vec![
        ("kill-port", kill_port_cmd()),
        ("prune", prune_cmd()),
        ("git-sync", git_sync_cmd()),
        ("git-squash", git_squash_cmd()),
        ("git-trigger", git_trigger_cmd()),
        ("git-update", git_update_cmd()),
        ("to-opus", to_opus_cmd()),
        ("to-flac", to_flac_cmd()),
        ("clean-exif", clean_exif_cmd()),
        ("clean-dls", clean_dls_cmd()),
        ("url2base64", url2base64_cmd()),
        ("imp", imp_cmd()),
        ("install-font-macos", install_font_macos_cmd()),
        ("unfuck-xcode", unfuck_xcode_cmd()),
        ("vimv", vimv_cmd()),
        ("embed-art", embed_art_cmd()),
        ("extract-exif-from-flac", extract_exif_from_flac_cmd()),
        ("gen-diff", gen_diff_cmd()),
        ("install-terminfo", install_terminfo_cmd()),
        ("prune-gen", prune_gen_cmd()),
        ("pull-music", pull_music_cmd()),
        ("push-music", push_music_cmd()),
        ("echo-to-file", echo_to_file_cmd()),
        ("parallel-dl-extract", parallel_dl_extract_cmd()),
        ("upd", upd_cmd()),
    ];

    for (name, mut cmd) in tools {
        generate_to(shell, &mut cmd, name, &outdir).expect("Failed to generate completion");
        println!("  ✓ {}", name);
    }

    println!("\nCompletions generated in {}", outdir.display());
}

// Command definitions for each tool
fn kill_port_cmd() -> Command {
    Command::new("kill-port")
        .about("Kill process listening on port")
        .arg(clap::Arg::new("port").required(true).help("Port number"))
        .arg(clap::Arg::new("signal").help("Signal to send (default: SIGTERM)"))
}

fn prune_cmd() -> Command {
    Command::new("prune")
        .about("Find and delete small directories")
        .arg(clap::Arg::new("path").required(true).help("Path to search"))
        .arg(
            clap::Arg::new("size")
                .default_value("100")
                .help("Size in KB"),
        )
}

fn git_sync_cmd() -> Command {
    Command::new("git-sync").about("Clean up merged branches")
}

fn git_squash_cmd() -> Command {
    Command::new("git-squash")
        .about("Squash commits")
        .arg(clap::Arg::new("branch").help("Branch to squash"))
}

fn git_trigger_cmd() -> Command {
    Command::new("git-trigger").about("Trigger CI/CD pipeline")
}

fn git_update_cmd() -> Command {
    Command::new("git-update")
        .about("Update all git repos")
        .arg(clap::Arg::new("path").help("Path to search"))
}

fn to_opus_cmd() -> Command {
    Command::new("to-opus")
        .about("Convert audio to Opus")
        .arg(clap::Arg::new("files").num_args(1..).required(true))
        .arg(
            clap::Arg::new("bitrate")
                .long("bitrate")
                .short('b')
                .default_value("128"),
        )
}

fn to_flac_cmd() -> Command {
    Command::new("to-flac")
        .about("Convert audio to FLAC")
        .arg(clap::Arg::new("files").num_args(1..).required(true))
        .arg(
            clap::Arg::new("compression")
                .long("compression")
                .short('c')
                .default_value("8"),
        )
}

fn clean_exif_cmd() -> Command {
    Command::new("clean-exif")
        .about("Strip EXIF data from images")
        .arg(clap::Arg::new("paths").num_args(1..).required(true))
        .arg(
            clap::Arg::new("dry-run")
                .long("dry-run")
                .short('n')
                .action(clap::ArgAction::SetTrue),
        )
}

fn clean_dls_cmd() -> Command {
    Command::new("clean-dls")
        .about("Clean scene release garbage")
        .arg(clap::Arg::new("paths").num_args(1..).default_value("."))
}

fn url2base64_cmd() -> Command {
    Command::new("url2base64")
        .about("Download and base64 encode")
        .arg(clap::Arg::new("urls").num_args(0..))
}

fn imp_cmd() -> Command {
    Command::new("imp")
        .about("Music importer")
        .arg(clap::Arg::new("url").required(true))
        .arg(clap::Arg::new("dest").required(true))
}

fn install_font_macos_cmd() -> Command {
    Command::new("install-font-macos")
        .about("Install fonts from URLs")
        .arg(clap::Arg::new("urls").num_args(1..).required(true))
}

fn unfuck_xcode_cmd() -> Command {
    Command::new("unfuck-xcode").about("Fix corrupt Xcode CLI tools")
}

fn vimv_cmd() -> Command {
    Command::new("vimv")
        .about("Batch rename with editor")
        .arg(clap::Arg::new("files").num_args(0..))
}

fn embed_art_cmd() -> Command {
    Command::new("embed-art")
        .about("Embed artwork into FLAC")
        .arg(clap::Arg::new("paths").num_args(1..).default_value("."))
}

fn extract_exif_from_flac_cmd() -> Command {
    Command::new("extract-exif-from-flac")
        .about("Check FLAC embedded artwork for EXIF")
        .arg(clap::Arg::new("flac_file").required(true))
}

fn gen_diff_cmd() -> Command {
    Command::new("gen-diff")
        .about("Generate visual image diff")
        .arg(clap::Arg::new("image1").required(true))
        .arg(clap::Arg::new("image2").required(true))
        .arg(clap::Arg::new("output").required(true))
}

fn install_terminfo_cmd() -> Command {
    Command::new("install-terminfo")
        .about("Install terminfo to remote host")
        .arg(clap::Arg::new("host").required(true))
}

fn prune_gen_cmd() -> Command {
    Command::new("prune-gen").about("Generate test directory structure")
}

fn pull_music_cmd() -> Command {
    Command::new("pull-music").about("Sync music from remote")
}

fn push_music_cmd() -> Command {
    Command::new("push-music").about("Sync music to remote")
}

fn echo_to_file_cmd() -> Command {
    Command::new("echo-to-file")
        .about("Write to temp file")
        .arg(
            clap::Arg::new("text")
                .num_args(0..)
                .allow_hyphen_values(true),
        )
}

fn parallel_dl_extract_cmd() -> Command {
    Command::new("parallel-dl-extract")
        .about("Parallel download and extract")
        .arg(clap::Arg::new("urls").num_args(1..).required(true))
}

fn upd_cmd() -> Command {
    Command::new("upd").about("Parallel system update orchestrator")
}
