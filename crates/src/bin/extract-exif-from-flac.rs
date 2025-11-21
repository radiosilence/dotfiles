use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::{banner, system};
use std::io;
use std::path::Path;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(about = "Check if FLAC embedded artwork has been stripped of EXIF data")]
#[command(args_conflicts_with_subcommands(true))]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// FLAC file to check
    flac_file: Option<String>,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(
            shell,
            &mut Args::command(),
            "extract-exif-from-flac",
            &mut io::stdout(),
        );
        return Ok(());
    }

    let flac_file = args
        .flac_file
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;

    // Check for required tools
    if !system::which("metaflac") {
        anyhow::bail!("metaflac not found (brew install flac)");
    }
    if !system::which("exiftool") {
        anyhow::bail!("exiftool not found (brew install exiftool)");
    }

    let flac_path = Path::new(&flac_file);

    if !flac_path.exists() {
        anyhow::bail!("File not found: {}", flac_file);
    }

    if !flac_path
        .extension()
        .map(|e| e.eq_ignore_ascii_case("flac"))
        .unwrap_or(false)
    {
        anyhow::bail!("Not a FLAC file: {}", flac_file);
    }

    banner::print_glitch_header("EXTRACT-EXIF-FROM-FLAC", "cyan");
    banner::status("□", "FILE", &flac_file, "cyan");

    // Get picture info
    let output = Command::new("metaflac")
        .args(["--list", "--block-type=PICTURE"])
        .arg(&flac_file)
        .output()?;

    if !output.status.success() {
        anyhow::bail!("metaflac failed");
    }

    let picture_info = String::from_utf8_lossy(&output.stdout);

    if picture_info.trim().is_empty() {
        println!("   {} No embedded artwork\n", "ℹ".blue());
        return Ok(());
    }

    // Extract pictures to temp dir
    let temp_dir = TempDir::new()?;
    let mut picture_index = 0;

    for line in picture_info.lines() {
        if line.contains("type:") {
            if let Some(type_str) = line.split(':').nth(1) {
                let picture_type: u8 = type_str.trim().parse().unwrap_or(0);
                let type_desc = get_picture_type_desc(picture_type);

                let temp_image = temp_dir
                    .path()
                    .join(format!("picture_{}.jpg", picture_index));

                // Export picture
                let export_status = Command::new("metaflac")
                    .arg(format!("--export-picture-to={}", temp_image.display()))
                    .arg(&flac_file)
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .status()?;

                if export_status.success() {
                    // Check EXIF data
                    let exif_output = Command::new("exiftool")
                        .args(["-json", "-q"])
                        .arg(&temp_image)
                        .output()?;

                    if exif_output.status.success() {
                        let exif_json = String::from_utf8_lossy(&exif_output.stdout);

                        if has_sensitive_data(&exif_json) {
                            println!(
                                "   {} {} - Contains sensitive EXIF data",
                                "⚠".yellow(),
                                type_desc
                            );
                        } else {
                            println!("   {} {} - Clean", "✓".green(), type_desc);
                        }
                    } else {
                        println!("   {} {} - Clean (no EXIF data)", "✓".green(), type_desc);
                    }
                } else {
                    println!("   {} {} - Failed to extract", "✗".red(), type_desc);
                }

                picture_index += 1;
            }
        }
    }

    println!();
    Ok(())
}

fn has_sensitive_data(exif_json: &str) -> bool {
    let sensitive_fields = [
        "GPS",
        "CameraSerialNumber",
        "LensSerialNumber",
        "BodySerialNumber",
        "InternalSerialNumber",
        "UniqueImageID",
        "Artist",
        "Copyright",
        "Creator",
        "Contact",
        "Credit",
        "Source",
        "Comment",
        "UserComment",
    ];

    sensitive_fields
        .iter()
        .any(|field| exif_json.contains(field))
}

fn get_picture_type_desc(picture_type: u8) -> &'static str {
    match picture_type {
        0 => "Other",
        1 => "32x32 pixels file icon",
        2 => "Other file icon",
        3 => "Cover (front)",
        4 => "Cover (back)",
        5 => "Leaflet page",
        6 => "Media (e.g. label side of CD)",
        7 => "Lead artist/lead performer/soloist",
        8 => "Artist/performer",
        9 => "Conductor",
        10 => "Band/Orchestra",
        11 => "Composer",
        12 => "Lyricist/text writer",
        13 => "Recording Location",
        14 => "During recording",
        15 => "During performance",
        16 => "Movie/video screen capture",
        17 => "A bright coloured fish",
        18 => "Illustration",
        19 => "Band/artist logotype",
        20 => "Publisher/Studio logotype",
        _ => "Unknown",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_has_sensitive_data_gps() {
        let json = r#"{"GPS": "some data"}"#;
        assert!(has_sensitive_data(json));
    }

    #[test]
    fn test_has_sensitive_data_serial() {
        let json = r#"{"CameraSerialNumber": "12345"}"#;
        assert!(has_sensitive_data(json));

        let json2 = r#"{"LensSerialNumber": "67890"}"#;
        assert!(has_sensitive_data(json2));
    }

    #[test]
    fn test_has_sensitive_data_artist() {
        let json = r#"{"Artist": "John Doe"}"#;
        assert!(has_sensitive_data(json));
    }

    #[test]
    fn test_has_sensitive_data_clean() {
        let json = r#"{"Width": 1920, "Height": 1080}"#;
        assert!(!has_sensitive_data(json));
    }

    #[test]
    fn test_get_picture_type_desc() {
        assert_eq!(get_picture_type_desc(0), "Other");
        assert_eq!(get_picture_type_desc(3), "Cover (front)");
        assert_eq!(get_picture_type_desc(4), "Cover (back)");
        assert_eq!(get_picture_type_desc(6), "Media (e.g. label side of CD)");
        assert_eq!(get_picture_type_desc(8), "Artist/performer");
        assert_eq!(get_picture_type_desc(255), "Unknown");
    }
}
