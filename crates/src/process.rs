//! Process management utilities

use anyhow::{Context, Result};

/// Find process ID listening on a port using lsof
/// This is the most reliable method on macOS/Linux
pub fn find_by_port(port: u16) -> Result<Option<u32>> {
    use std::process::Command;

    let output = Command::new("lsof")
        .args(["-ti", &format!(":{}", port)])
        .output()
        .context("Failed to run lsof")?;

    if !output.status.success() {
        return Ok(None);
    }

    let pid_str = String::from_utf8_lossy(&output.stdout);
    let pid = pid_str.trim();

    if pid.is_empty() {
        return Ok(None);
    }

    let pid_num = pid.parse::<u32>().context("Failed to parse PID")?;

    Ok(Some(pid_num))
}

/// Kill a process by PID with optional signal
pub fn kill(pid: u32, signal: Option<&str>) -> Result<()> {
    use std::process::Command;

    let mut cmd = Command::new("kill");

    if let Some(sig) = signal {
        cmd.arg(format!("-{}", sig));
    }

    cmd.arg(pid.to_string());

    let status = cmd.status().context("Failed to execute kill command")?;

    if !status.success() {
        anyhow::bail!("Failed to kill process {}", pid);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_port_range() {
        // Just verify u16::MAX is what we expect for port calculations
        assert_eq!(65535, u16::MAX);
    }
}
