// What the buttons do, shared by the board and item views.

import { appHome, exec, focused, home, notify, panes, readTextFile, run, setShared, shared, spaces } from "herdr";
import { mutate, graphql, rest } from "./api.js";
import * as gh from "./gh.js";

export const MOD = "gh-board";
export const PREVIEW = "gh-board.preview";
export const PREVIEW_TAB = "gh-board.previewTab";

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
    catch (e) { errors.push(`run ${id}: ${errorText(e)}`); }
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

// Opens the PR's worktree as a Herdr space through the dotfiles' wtpr-space
// and starts Claude there with a brief of what is wrong. wtpr-space can take
// longer than exec's 30 s (fetch, worktree add, hooks), so it runs in a
// terminal of its own and the answer comes back through a file.
export async function fixWithAgent(cx, full, pr) {
  if (pr.fork) throw new Error("PRs from forks are not supported yet (dotfiles#117)");
  const detail = await loadPr(cx, full, pr.number);
  if (!detail) throw new Error("PR not found");
  if (detail.state !== "open") throw new Error(`PR is ${detail.state}`);
  const prompt = gh.agentPrompt(full, detail, detail.checks);
  const dir = `${appHome()}/data/${MOD}`, out = `${dir}/space-${detail.number}-${Date.now()}`;
  await exec("mkdir", ["-p", dir]);
  const started = await exec("hc", ["run", "--json", "--bg", "--rm", "--no-parent", "--cwd", home(), "--",
    "zsh", "-ic", 'wtpr-space "$1" "$2"', "wtpr-space", detail.url, out]);
  if (started.code !== 0) throw new Error((started.stderr || started.stdout).trim());
  const { address } = JSON.parse(started.stdout);
  let id = null;
  try {
    for (let i = 0; i < 300 && !id; i++) {
      await cx.sleep(1000);
      id = (await readTextFile(out))?.trim() || null;
      if (id || i % 3 !== 2) continue;
      const alive = await exec("hc", ["get", address, "--json"]);
      if (alive.code === 0) continue;
      id = (await readTextFile(out))?.trim() || null;
      if (id) break;
      const log = (await readTextFile(`${out}.log`))?.replace(/^.*can't change option: zle\n/gm, "").trim();
      throw new Error(log ? log.split("\n").slice(-4).join("\n") : "wtpr-space is missing: it comes with dotfiles#116");
    }
    if (!id) {
      await exec("hc", ["kill", address]);
      throw new Error("Opening the worktree took over 5 minutes");
    }
  } finally {
    await exec("rm", ["-f", out, `${out}.log`]);
  }
  run("tab.new", { space: id, name: `fix #${detail.number}`, argv: ["claude"], task: prompt });
}

// Shows a PR or issue in the preview pane beside the board, making that pane
// the first time. Pinned panes keep their own item; the preview follows clicks.
export function openItem(target) {
  setShared(PREVIEW, { repo: target.repo, number: target.number, kind: target.kind });
  const tab = activeTab();
  const here = panes().filter((p) => p.mod === MOD && p.tab === tab);
  if (shared(PREVIEW_TAB) === tab && here.length > 1) return;
  const from = focused()?.pane ?? here[0]?.pane;
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
