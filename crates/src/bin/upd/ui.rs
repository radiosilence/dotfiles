use ratatui::{
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

use super::app::{AppState, TaskStatus};

const SPINNER_FRAMES: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

pub fn draw(f: &mut Frame, state: &AppState, tick: usize) {
    let area = f.area();

    if state.tasks.is_empty() {
        let msg =
            Paragraph::new("  waiting for tasks...").style(Style::default().fg(Color::DarkGray));
        f.render_widget(msg, area);
        return;
    }

    let task_count = state.tasks.len();

    // Reserve bottom 3 lines for status bar
    let chunks = Layout::vertical([Constraint::Min(4), Constraint::Length(3)]).split(area);

    let grid_area = chunks[0];
    let status_area = chunks[1];

    // Determine column count based on width
    let cols = if grid_area.width >= 120 {
        3
    } else if grid_area.width >= 60 {
        2
    } else {
        1
    };

    let rows = task_count.div_ceil(cols);

    // Build row constraints
    let row_constraints: Vec<Constraint> = (0..rows)
        .map(|_| Constraint::Ratio(1, rows as u32))
        .collect();
    let row_areas = Layout::vertical(row_constraints).split(grid_area);

    // Build col constraints
    let col_constraints: Vec<Constraint> = (0..cols)
        .map(|_| Constraint::Ratio(1, cols as u32))
        .collect();

    for (i, task) in state.tasks.iter().enumerate() {
        let row = i / cols;
        let col = i % cols;

        let col_areas = Layout::horizontal(col_constraints.clone()).split(row_areas[row]);
        let cell = col_areas[col];

        draw_task_panel(f, task, cell, tick);
    }

    // Status bar
    draw_status_bar(f, state, status_area, tick);
}

fn draw_task_panel(f: &mut Frame, task: &super::app::TaskState, area: Rect, tick: usize) {
    let (border_color, title_style) = match task.status {
        TaskStatus::Pending => (Color::DarkGray, Style::default().fg(Color::DarkGray)),
        TaskStatus::Running => (
            Color::Magenta,
            Style::default()
                .fg(Color::Magenta)
                .add_modifier(Modifier::BOLD),
        ),
        TaskStatus::Done => (Color::Green, Style::default().fg(Color::Green)),
        TaskStatus::Failed => (
            Color::Red,
            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
        ),
    };

    let status_icon = match task.status {
        TaskStatus::Pending => "·".to_string(),
        TaskStatus::Running => {
            let frame = SPINNER_FRAMES[tick % SPINNER_FRAMES.len()];
            frame.to_string()
        }
        TaskStatus::Done => "󰄬".to_string(),
        TaskStatus::Failed => "󰅖".to_string(),
    };

    let title = format!(" {} {} ", status_icon, task.name);

    let block = Block::default()
        .title(Line::from(Span::styled(title, title_style)))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(border_color));

    let inner = block.inner(area);
    f.render_widget(block, area);

    if inner.height == 0 || inner.width == 0 {
        return;
    }

    let mut lines: Vec<Line> = Vec::new();

    // Show current step
    if !task.step.is_empty() && task.status == TaskStatus::Running {
        lines.push(Line::from(vec![
            Span::styled("→ ", Style::default().fg(Color::Cyan)),
            Span::styled(&task.step, Style::default().fg(Color::White)),
        ]));
    }

    // Show output lines (fit to panel height)
    let max_output = inner.height.saturating_sub(lines.len() as u16) as usize;
    let start = task.output.len().saturating_sub(max_output);
    for line in &task.output[start..] {
        lines.push(Line::from(Span::styled(
            line.as_str(),
            Style::default().fg(Color::DarkGray),
        )));
    }

    // Show error if failed
    if let Some(ref err) = task.error {
        lines.push(Line::from(Span::styled(
            err.as_str(),
            Style::default().fg(Color::Red),
        )));
    }

    let paragraph = Paragraph::new(lines).wrap(Wrap { trim: false });
    f.render_widget(paragraph, inner);
}

fn draw_status_bar(f: &mut Frame, state: &AppState, area: Rect, tick: usize) {
    let done = state
        .tasks
        .iter()
        .filter(|t| t.status == TaskStatus::Done)
        .count();
    let failed = state
        .tasks
        .iter()
        .filter(|t| t.status == TaskStatus::Failed)
        .count();
    let total = state.tasks.len();
    let running = state
        .tasks
        .iter()
        .filter(|t| t.status == TaskStatus::Running)
        .count();

    let mut spans = vec![Span::styled(
        "  ⟢ ",
        Style::default()
            .fg(Color::Magenta)
            .add_modifier(Modifier::BOLD),
    )];

    if state.all_finished() {
        if state.any_failed {
            spans.push(Span::styled(
                format!("complete ({done}/{total} ok, {failed} failed)"),
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ));
        } else {
            spans.push(Span::styled(
                "all tasks complete",
                Style::default()
                    .fg(Color::Green)
                    .add_modifier(Modifier::BOLD),
            ));
        }
    } else {
        let frame = SPINNER_FRAMES[tick % SPINNER_FRAMES.len()];
        spans.push(Span::styled(
            format!("{frame} {running} running, {done}/{total} done"),
            Style::default().fg(Color::White),
        ));
        if !state.status_message.is_empty() {
            spans.push(Span::styled(
                format!(" — {}", state.status_message),
                Style::default().fg(Color::DarkGray),
            ));
        }
    }

    let block = Block::default()
        .borders(Borders::TOP)
        .border_style(Style::default().fg(Color::DarkGray));

    let inner = block.inner(area);
    f.render_widget(block, area);

    let paragraph = Paragraph::new(Line::from(spans));
    f.render_widget(paragraph, inner);
}
