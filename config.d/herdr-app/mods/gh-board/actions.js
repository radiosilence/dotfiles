// What the buttons do, shared by the board and item views.

import { appHome, exec, focused, home, notify, panes, readTextFile, run, setShared, shared, spaces } from "herdr";
import * as fs from "fs/promises";
import { mutate, graphql, rest } from "./api.js";
import * as gh from "./gh.js";

export const MOD = "gh-board";
export const PREVIEW = "gh-board.preview";
// { [tab]: true } for each tab with a live preview pane, written by that pane
// and cleared when it closes.
export const PREVIEW_AT = "gh-board.preview.at";

export function registerPreview(tab, live) {
  if (!tab) return;
  const tabs = { ...(shared(PREVIEW_AT) ?? {}) };
  if (live) tabs[tab] = true; else delete tabs[tab];
  setShared(PREVIEW_AT, tabs);
}

export const activeTab = () => spaces().find((s) => s.active)?.tabs.find((t) => t.active)?.id ?? null;

// A copy starts the first time it shows, and new panes take focus, so the tab
// focused at init is the copy's own. Without one, any of this mod's panes in
// the shown tab counts.
export function ownTab() {
  return focused()?.tab ?? null;
}

export function isShown(tab) {
  const shown = activeTab();
  if (tab) return shown === tab;
  return panes().some((p) => p.mod === MOD && p.tab === shown);
}

export const errorText = (e) => String(e?.message ?? e).replace(/^Error: /, "");

export function fail(title, e) {
  notify({ title, body: errorText(e), level: "error", timeout: 8000 });
}

export async function loadPr(cx, full, number) {
  const json = await graphql(cx, gh.prDetailQuery(full, number));
  if (json?.errors?.length && !json?.data?.repository?.pullRequest) throw new Error(json.errors[0].message);
  return gh.prDetailModel(json);
}

export async function merge(cx, pr, methods) {
  await mutate(cx, gh.mergeMutation(pr, gh.mergeMethod(methods)));
}

export async function setAuto(cx, pr, methods, enable) {
  await mutate(cx, gh.autoMergeMutation(pr, enable, gh.mergeMethod(methods)));
}

export async function updateBranch(cx, pr) {
  await mutate(cx, gh.updateBranchMutation(pr));
}

export async function markReady(cx, pr) {
  await mutate(cx, gh.readyMutation(pr));
}

export async function comment(cx, subjectId, body) {
  await mutate(cx, gh.commentMutation(subjectId, body));
}

// Reruns every failed Actions run behind the checks; reports the checks that
// no rerun can reach rather than skipping them silently.
export async function rerunFailed(cx, full, checks) {
  const { runs, stuck } = gh.rerunPlan(checks);
  const errors = [];
  for (const id of runs) {
    try { await rest(cx, "POST", `/repos/${full}/actions/runs/${id}/rerun-failed-jobs`); }
    catch (e) { errors.push(`run ${id}: ${errorText(e)}${/cannot be rerun|in progress/i.test(errorText(e)) ? " (wait for it to finish)" : ""}`); }
  }
  if (stuck.length) notify({ title: "Not rerun", body: `${stuck.join(", ")}: not GitHub Actions runs`, level: "warning", timeout: 8000 });
  if (errors.length) throw new Error(errors.join("; "));
  if (!runs.length && !stuck.length) throw new Error("Nothing has failed");
  return runs.length;
}

export const rerunRun = (cx, full, id, failedOnly) =>
  rest(cx, "POST", `/repos/${full}/actions/runs/${id}/${failedOnly ? "rerun-failed-jobs" : "rerun"}`);
export const cancelRun = (cx, full, id) => rest(cx, "POST", `/repos/${full}/actions/runs/${id}/cancel`);
export const dispatch = (cx, full, file, ref) => rest(cx, "POST", `/repos/${full}/actions/workflows/${encodeURIComponent(file)}/dispatches`, { ref });

const DATA = () => `${appHome()}/data/${MOD}`;

// PRs with an agent being started, so two clicks don't make two worktrees.
export const starting = new Set();

// Removes hand-off files a closed copy left behind.
export async function sweep() {
  const dir = DATA(), now = Date.now();
  try {
    for (const name of await fs.readdir(dir)) {
      const at = Number(/^space-\d+-(\d+)/.exec(name)?.[1]);
      if (at && now - at > 10 * 60 * 1000) await fs.rm(`${dir}/${name}`, { force: true });
    }
  } catch { /* no folder yet */ }
}

// Opens the PR's worktree as a Herdr space through the dotfiles' wtpr-space
// and starts Claude there with a brief of what is wrong. wtpr-space can take
// longer than exec's 30 s (fetch, worktree add, hooks), so it runs in a
// terminal of its own and the answer comes back through a file.
export async function fixWithAgent(cx, full, pr) {
  const key = `${full}#${pr.number}`;
  if (starting.has(key)) return;
  if (pr.fork) throw new Error("PRs from forks are not supported yet (dotfiles#117)");
  starting.add(key);
  try {
    const detail = await loadPr(cx, full, pr.number);
    if (!detail) throw new Error("PR not found");
    if (detail.state !== "open") throw new Error(`PR is ${detail.state}`);
    const prompt = gh.agentPrompt(full, detail, detail.checks);
    const { space, folder } = await openWorktree(cx, detail);
    run("tab.new", { space, folder, name: `fix #${detail.number}`, argv: ["claude"], task: prompt });
  } finally {
    starting.delete(key);
  }
}

async function openWorktree(cx, detail) {
  const dir = DATA(), out = `${dir}/space-${detail.number}-${Date.now()}`;
  await fs.mkdir(dir, { recursive: true });
  const started = await exec("hc", ["run", "--json", "--bg", "--rm", "--no-parent", "--cwd", home(), "--",
    "zsh", "-ic", 'wtpr-space "$1" "$2"', "wtpr-space", detail.url, out]);
  if (started.code !== 0) throw new Error((started.stderr || started.stdout).trim());
  const { address } = JSON.parse(started.stdout);
  const read = async () => {
    const [space, folder] = ((await readTextFile(out)) ?? "").split("\n").map((l) => l.trim());
    return space && folder ? { space, folder } : null;
  };
  try {
    // hc get failing twice in a row, 3 s apart, means the terminal has gone;
    // once could be the core hiccuping.
    let misses = 0;
    for (let i = 1; i <= 300; i++) {
      await cx.sleep(1000);
      const found = await read();
      if (found) return found;
      if (i % 3) continue;
      misses = (await exec("hc", ["get", address, "--json"])).code === 0 ? 0 : misses + 1;
      if (misses < 2) continue;
      const late = await read();
      if (late) return late;
      const log = (await readTextFile(`${out}.log`))?.replace(/^.*can't change option: zle\n/gm, "").trim();
      throw new Error(log ? log.split("\n").slice(-4).join("\n") : "wtpr-space wrote nothing (it needs dotfiles#116, or the shell failed to start)");
    }
    await exec("hc", ["kill", address]);
    throw new Error("Opening the worktree took over 5 minutes");
  } finally {
    await fs.rm(out, { force: true }).catch(() => {});
    await fs.rm(`${out}.log`, { force: true }).catch(() => {});
  }
}

// Shows a PR or issue in the preview pane beside the board, making that pane
// the first time. Pinned panes keep their own item; the preview follows clicks.
let splitting = null;

export function openItem(target) {
  setShared(PREVIEW, { repo: target.repo, number: target.number, kind: target.kind });
  const tab = activeTab();
  // A crash skips close(), so the registry is checked against the panes: the
  // board alone in its tab means no preview, whatever was recorded.
  if (shared(PREVIEW_AT)?.[tab]) {
    if (panes().filter((p) => p.mod === MOD && p.tab === tab).length >= 2) return;
    registerPreview(tab, false);
  }
  // The new pane registers once it starts; until then a second click must not split again.
  if (splitting?.tab === tab && Date.now() - splitting.at < 2000) return;
  splitting = { tab, at: Date.now() };
  const from = focused()?.pane ?? panes().find((p) => p.mod === MOD && p.tab === tab)?.pane;
  run("pane.split", { direction: "right", ...(from ? { pane: from } : {}), mod: MOD, props: { view: "item", preview: true } });
}

export function pinItem(target) {
  const tab = activeTab();
  const from = focused()?.pane ?? panes().find((p) => p.mod === MOD && p.tab === tab)?.pane;
  run("pane.split", { direction: "down", ...(from ? { pane: from } : {}), mod: MOD, props: { view: "item", repo: target.repo, number: target.number, kind: target.kind } });
}

export function openUrl(url, cx) {
  const item = gh.itemLink(url);
  if (item) openItem(item);
  else cx.open_url(url);
}
