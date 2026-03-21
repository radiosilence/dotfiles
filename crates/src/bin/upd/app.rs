use std::sync::{Arc, Mutex};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskStatus {
    Pending,
    Running,
    Done,
    Failed,
}

#[derive(Debug, Clone)]
pub struct TaskState {
    pub name: String,
    pub status: TaskStatus,
    /// Current sub-step label (e.g. "brew:update", "mise:up")
    pub step: String,
    /// Last N lines of output
    pub output: Vec<String>,
    /// Error message if failed
    pub error: Option<String>,
}

impl TaskState {
    pub fn new(name: &str) -> Self {
        Self {
            name: name.to_string(),
            status: TaskStatus::Pending,
            step: String::new(),
            output: Vec::new(),
            error: None,
        }
    }

    pub fn push_line(&mut self, line: String) {
        self.output.push(line);
        // Keep last 50 lines
        if self.output.len() > 50 {
            self.output.remove(0);
        }
    }
}

#[derive(Debug)]
pub struct AppState {
    pub tasks: Vec<TaskState>,
    pub status_message: String,
    pub any_failed: bool,
    pub auth_gh_ok: bool,
    pub auth_op_ok: bool,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            tasks: Vec::new(),
            status_message: String::new(),
            any_failed: false,
            auth_gh_ok: false,
            auth_op_ok: false,
        }
    }

    pub fn add_task(&mut self, name: &str) -> usize {
        let idx = self.tasks.len();
        self.tasks.push(TaskState::new(name));
        idx
    }

    pub fn set_running(&mut self, idx: usize, step: &str) {
        if let Some(t) = self.tasks.get_mut(idx) {
            t.status = TaskStatus::Running;
            t.step = step.to_string();
        }
    }

    pub fn set_step(&mut self, idx: usize, step: &str) {
        if let Some(t) = self.tasks.get_mut(idx) {
            t.step = step.to_string();
        }
    }

    pub fn push_output(&mut self, idx: usize, line: String) {
        if let Some(t) = self.tasks.get_mut(idx) {
            t.push_line(line);
        }
    }

    pub fn set_done(&mut self, idx: usize) {
        if let Some(t) = self.tasks.get_mut(idx) {
            t.status = TaskStatus::Done;
        }
    }

    pub fn set_failed(&mut self, idx: usize, error: String) {
        if let Some(t) = self.tasks.get_mut(idx) {
            t.status = TaskStatus::Failed;
            t.error = Some(error);
            self.any_failed = true;
        }
    }

    pub fn all_finished(&self) -> bool {
        self.tasks
            .iter()
            .all(|t| matches!(t.status, TaskStatus::Done | TaskStatus::Failed))
    }
}

pub type SharedState = Arc<Mutex<AppState>>;

pub fn shared_state() -> SharedState {
    Arc::new(Mutex::new(AppState::new()))
}
