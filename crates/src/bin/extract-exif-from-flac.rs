use anyhow::{anyhow, bail, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use std::io;
use std::path::Path;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(name = "extract-exif-from-flac")]
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
        .ok_or_else(|| anyhow!(Args::command().render_help()))?;

    dotfiles_tools::check_command("metaflac")?;
    dotfiles_tools::check_command("exiftool")?;

    let flac_path = Path::new(&flac_file);

    if !flac_path.exists() {
        bail!("File not found: {}", flac_file);
    }

    if !flac_path
        .extension()
        .map(|e| e.eq_ignore_ascii_case("flac"))
        .unwrap_or(false)
    {
        bail!("Not a FLAC file: {}", flac_file);
    }

    println!("\n/// {}\n", "EXTRACT-EXIF-FROM-FLAC".bold());
    println!("  {} file: {}", "→".bright_black(), flac_file);

    // Get picture info
    let output = Command::new("metaflac")
        .args(["--list", "--block-type=PICTURE"])
        .arg(&flac_file)
        .output()?;

    if !output.status.success() {
        bail!("metaflac failed");
    }

    let picture_info = String::from_utf8_lossy(&output.stdout);

    if picture_info.trim().is_empty() {
        println!("  {} No embedded artwork", "·".bright_black());
        return Ok(());
    }

    // Parse picture blocks from metaflac --list output
    let temp_dir = TempDir::new()?;
    let pictures = parse_picture_blocks(&picture_info);

    if pictures.is_empty() {
        println!("  {} No picture blocks parsed", "·".bright_black());
        return Ok(());
    }

    for (i, pic) in pictures.iter().enumerate() {
        let type_desc = get_picture_type_desc(pic.picture_type);
        let temp_image = temp_dir.path().join(format!("picture_{i}.jpg"));

        // Export specific picture by block number
        let export_status = Command::new("metaflac")
            .arg(format!("--block-number={}", pic.block_number))
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
                        "  {} {} - Contains sensitive EXIF data",
                        "!".yellow(),
                        type_desc
                    );
                } else {
                    println!("  {} {} - Clean", "✓".green(), type_desc);
                }
            } else {
                println!("  {} {} - Clean (no EXIF data)", "✓".green(), type_desc);
            }
        } else {
            println!("  {} {} - Failed to extract", "✗".red(), type_desc);
        }
    }

    Ok(())
}

struct PictureBlock {
    block_number: u32,
    picture_type: u8,
}

/// Parse metaflac --list output to extract block numbers and picture types.
///
/// The output has two `type:` lines per block — the first is the block type
/// (always `6` for PICTURE), the second is the picture type (e.g. `3` for
/// front cover). We skip the block-type line and only capture the picture type.
///
/// ```text
/// METADATA block #2
///   type: 6 (PICTURE)
///   is last: false
///   length: 489516
///   type: 3 (Cover (front))
/// ```
fn parse_picture_blocks(output: &str) -> Vec<PictureBlock> {
    let mut blocks = Vec::new();
    let mut current_block_number: Option<u32> = None;
    let mut seen_block_type = false;

    for line in output.lines() {
        let trimmed = line.trim();

        // Match "METADATA block #N"
        if let Some(rest) = trimmed.strip_prefix("METADATA block #") {
            current_block_number = rest.parse().ok();
            seen_block_type = false;
        }

        // Match "type: N (description)"
        if trimmed.starts_with("type:") {
            if !seen_block_type {
                // First type: line is the block type (6 = PICTURE), skip it
                seen_block_type = true;
            } else if let Some(block_num) = current_block_number {
                // Second type: line is the picture type
                let after_colon = trimmed.strip_prefix("type:").unwrap_or("").trim();
                let type_str = after_colon.split_whitespace().next().unwrap_or("0");
                let picture_type: u8 = type_str.parse().unwrap_or(0);
                blocks.push(PictureBlock {
                    block_number: block_num,
                    picture_type,
                });
            }
        }
    }

    blocks
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
    fn test_parse_picture_blocks_single() {
        let output = "\
METADATA block #2
  type: 6 (PICTURE)
  is last: false
  length: 489516
  type: 3 (Cover (front))
  MIME type: image/jpeg
";
        let blocks = parse_picture_blocks(output);
        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].block_number, 2);
        assert_eq!(blocks[0].picture_type, 3);
    }

    #[test]
    fn test_parse_picture_blocks_multiple() {
        let output = "\
METADATA block #2
  type: 6 (PICTURE)
  is last: false
  length: 100
  type: 3 (Cover (front))
  MIME type: image/jpeg
METADATA block #3
  type: 6 (PICTURE)
  is last: true
  length: 200
  type: 4 (Cover (back))
  MIME type: image/png
";
        let blocks = parse_picture_blocks(output);
        assert_eq!(blocks.len(), 2);
        assert_eq!(blocks[0].block_number, 2);
        assert_eq!(blocks[0].picture_type, 3);
        assert_eq!(blocks[1].block_number, 3);
        assert_eq!(blocks[1].picture_type, 4);
    }

    #[test]
    fn test_parse_picture_blocks_empty() {
        let blocks = parse_picture_blocks("");
        assert!(blocks.is_empty());
    }

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
