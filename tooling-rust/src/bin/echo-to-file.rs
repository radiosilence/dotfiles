use anyhow::Result;
use std::fs;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let content = args.join(" ");
    fs::write("/tmp/echo-out", content)?;
    Ok(())
}
