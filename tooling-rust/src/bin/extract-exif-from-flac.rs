use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use std::path::Path;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(about = "Check if FLAC embedded artwork has been stripped of EXIF data")]
struct Args {
    /// FLAC file to check
    flac_file: String,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Check for required tools
    if !which("metaflac") {
        anyhow::bail!("metaflac not found (brew install flac)");
    }
    if !which("exiftool") {
        anyhow::bail!("exiftool not found (brew install exiftool)");
    }

    let flac_path = Path::new(&args.flac_file);

    if !flac_path.exists() {
        anyhow::bail!("File not found: {}", args.flac_file);
    }

    if !flac_path
        .extension()
        .map(|e| e.eq_ignore_ascii_case("flac"))
        .unwrap_or(false)
    {
        anyhow::bail!("Not a FLAC file: {}", args.flac_file);
    }

    banner::print_glitch_header("EXTRACT-EXIF-FROM-FLAC", "cyan");
    banner::status("□", "FILE", &args.flac_file, "cyan");

    // Get picture info
    let output = Command::new("metaflac")
        .args(["--list", "--block-type=PICTURE"])
        .arg(&args.flac_file)
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
                    .arg(&args.flac_file)
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

fn which(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

mod banner {
    use colored::Colorize;

    pub fn print_glitch_header(title: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("\n{}", color_fn(&format!("   ╔═══ {} ═══╗", title)).bold());
    }

    pub fn status(icon: &str, label: &str, value: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }
}
