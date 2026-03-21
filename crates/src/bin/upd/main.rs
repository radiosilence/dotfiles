mod app;
mod tasks;
mod ui;

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::prelude::*;
use std::io;
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};
use which::which;

use app::SharedState;

#[derive(Parser)]
#[command(name = "upd")]
#[command(about = "Update the system", long_about = None)]
#[command(version)]
struct Args {
    #[arg(short, long)]
    verbose: bool,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(shell, &mut Args::command(), "upd", &mut io::stdout());
        return Ok(());
    }

    // Phase 1: Pre-TUI (interactive stuff that needs raw stdout)
    let (auth_status, has_sudo) = tasks::run_pre_tui()?;

    // Spawn sudo keepalive if needed
    let sudo_keepalive = if has_sudo {
        let keepalive = Arc::new(std::sync::atomic::AtomicBool::new(true));
        let keepalive_clone = keepalive.clone();
        Some((
            thread::spawn(move || {
                while keepalive_clone.load(std::sync::atomic::Ordering::Relaxed) {
                    let _ = std::process::Command::new("sudo").arg("-v").status();
                    thread::sleep(Duration::from_secs(60));
                }
            }),
            keepalive,
        ))
    } else {
        None
    };

    // Phase 2: TUI dashboard for parallel tasks
    let state = app::shared_state();

    let has_brew = which("brew").is_ok();
    let has_apt = which("apt-get").is_ok();
    let has_dnf = which("dnf").is_ok();
    let has_mise = which("mise").is_ok();
    let has_claude = which("claude").is_ok();

    // Register tasks and spawn them
    let mut handles: Vec<JoinHandle<()>> = Vec::new();

    {
        let mut s = state.lock().unwrap();
        s.phase = app::Phase::Tasks;

        if has_apt {
            let idx = s.add_task("apt");
            drop(s);
            handles.push(tasks::spawn_apt(state.clone(), idx));
            s = state.lock().unwrap();
        }

        if has_dnf {
            let idx = s.add_task("dnf");
            drop(s);
            handles.push(tasks::spawn_dnf(state.clone(), idx));
            s = state.lock().unwrap();
        }

        if has_brew {
            let idx = s.add_task("brew");
            drop(s);
            handles.push(tasks::spawn_brew(state.clone(), idx));
            s = state.lock().unwrap();
        }

        if has_mise {
            let idx = s.add_task("mise");
            drop(s);
            handles.push(tasks::spawn_mise(state.clone(), idx));
            s = state.lock().unwrap();
        }

        if has_claude {
            let idx = s.add_task("claude");
            drop(s);
            handles.push(tasks::spawn_claude(state.clone(), idx));
            s = state.lock().unwrap();
        }

        {
            let idx = s.add_task("tmux-plugins");
            drop(s);
            handles.push(tasks::spawn_tmux_plugins(state.clone(), idx));
        }
    }

    // Run TUI
    run_tui(&state)?;

    // Wait for all task threads
    for handle in handles {
        let _ = handle.join();
    }

    // Kill sudo keepalive
    if let Some((handle, keepalive)) = sudo_keepalive {
        keepalive.store(false, std::sync::atomic::Ordering::Relaxed);
        let _ = handle.join();
    }

    let any_failed = state.lock().unwrap().any_failed;

    // Phase 3: Post-TUI
    tasks::run_post_tui(&auth_status, any_failed)?;

    Ok(())
}

fn run_tui(state: &SharedState) -> Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let tick_rate = Duration::from_millis(100);
    let mut last_tick = Instant::now();
    let mut tick_count: usize = 0;

    loop {
        // Draw
        {
            let s = state.lock().unwrap();
            terminal.draw(|f| ui::draw(f, &s, tick_count))?;

            if s.all_finished() {
                // Show final state for a moment then exit
                drop(s);
                thread::sleep(Duration::from_millis(800));
                break;
            }
        }

        // Handle events
        let timeout = tick_rate.saturating_sub(last_tick.elapsed());
        if event::poll(timeout)? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => break,
                        _ => {}
                    }
                }
            }
        }

        if last_tick.elapsed() >= tick_rate {
            tick_count = tick_count.wrapping_add(1);
            last_tick = Instant::now();
        }
    }

    // Restore terminal
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    Ok(())
}
