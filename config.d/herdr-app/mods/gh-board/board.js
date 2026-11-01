// The board: every added repository, its open PRs and their state, with the
// actions that would otherwise mean a trip to github.com.

import { div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { home, panes, readTextFile, setShared, shared, theme, watchFolder } from "herdr";
import * as fs from "fs/promises";
import { graphql, rest } from "./api.js";
import * as gh from "./gh.js";
import * as act from "./actions.js";
import { alpha, badge, button, ciLabel, dot, mergeLabel, reviewLabel, stateColor } from "./ui.js";

const REPOS = "gh-board.repos";
const CHUNK = 8;
const TICK = 5000;
// Seconds between polls: everything when shown, everything when hidden, and
// repositories where something is about to change.
const FULL = 60, HIDDEN = 300, HOT = 15;
// Below this many GraphQL points left, every interval stretches.
const LOW = 1000;
const ARM = 4000;

const repoList = () => (shared(REPOS) ?? []).filter((r) => typeof r === "string");

// The local checkout of a repository, found as wt-core finds it: under
// ~/workspace/<owner>/<repo>, else any ~/workspace/*/<repo>, plus ~/.dotfiles;
// whichever has a remote pointing at it.
async function checkout(full) {
  const r = gh.splitRepo(full);
  if (!r) return null;
  const ws = `${home()}/workspace`;
  const dirs = await fs.readdir(ws).catch(() => []);
  const candidates = [`${ws}/${r.owner}/${r.name}`, ...dirs.map((d) => `${ws}/${d}/${r.name}`), `${home()}/.${r.name}`];
  for (const root of [...new Set(candidates)]) {
    const config = await readTextFile(`${root}/.git/config`).catch(() => null);
    if (config && gh.remoteMatches(config, full)) return root;
  }
  return null;
}

export class Board {
  init(cx) {
    this.tab = act.ownTab();
    this.data = {};       // full -> repo model, or { error }
    this.polled = {};     // full -> ms of the last answer applied
    this.started = {};    // full -> ms the newest request for it started
    this.inflight = new Set();
    this.hotUntil = {};   // full -> ms; after an action or a local push
    this.touchedAt = {};  // full -> ms of the last action, so an older answer can't settle it
    this.busy = {};       // `${full}#${n}` -> label of the running action
    this.actions = {};    // full -> lazily loaded runs/workflows/releases, when opened
    this.watched = new Set();
    this.filter = "all";
    this.text = "";
    this.armed = null;    // { key, oid, at } of a merge awaiting its second click
    this.pausedUntil = 0;
    this.reviewErrors = {}; // first repo of a chunk -> its review search's error
    this.input = InputState.new({ placeholder: "Filter, or owner/repo to add" });
    this.input.on("change", (_e, cx) => { this.text = this.input.value(); cx.notify(); });
    this.input.on("submit", (_e, cx) => this.submit(cx));
    this.input.on("focus", (_e, cx) => { this.typing = true; this.loadSuggestions(cx); cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    setShared("gh-board.boardTab", this.tab);
    cx.spawn(async () => act.sweep());
    cx.timer.every(TICK, (cx) => this.tick(cx));
    this.tick(cx);
  }

  close() { this.closed = true; }

  // The tab is taken from focus at init, which a copy opened from a popup can
  // get wrong; a tab with no board in it is corrected to the shown one that has one.
  shown() {
    const tab = act.activeTab();
    if (!panes().some((p) => p.mod === act.MOD && p.tab === this.tab) && panes().some((p) => p.mod === act.MOD && p.tab === tab)) {
      this.tab = tab;
      setShared("gh-board.boardTab", tab);
    }
    return act.isShown(this.tab);
  }

  // Decides what is due. One timer for everything, so nothing piles up.
  tick(cx, force = false) {
    const now = Date.now(), repos = repoList(), shown = this.shown();
    if (now < this.pausedUntil && !force) return;
    const low = (this.rate?.remaining ?? Infinity) < LOW ? 4 : 1;
    const due = repos.filter((full) => {
      if (this.inflight.has(full)) return false;
      if (force || !this.polled[full]) return true;
      const age = (now - this.polled[full]) / 1000;
      if (!shown) return age >= HIDDEN * low;
      const hot = gh.isHot(this.data[full], now) || (this.hotUntil[full] ?? 0) > now;
      return age >= (hot ? HOT : FULL) * low;
    });
    if (due.length) this.poll(due, cx);
    if (shown) for (const full of Object.keys(this.actions)) this.maybeLoadActions(full, cx);
    for (const full of repos) this.watch(full, cx);
  }

  poll(repos, cx) {
    for (const part of gh.chunk(repos, CHUNK)) {
      const started = Date.now();
      for (const full of part) { this.inflight.add(full); this.started[full] = started; }
      cx.spawn(async (cx) => {
        try {
          const { query, aliases } = gh.boardQuery(part);
          const out = gh.parseBoard(await graphql(cx, query), aliases);
          this.apply({ ...out, chunk: part[0] }, started);
        } catch (e) {
          if (e?.status === 403 || e?.status === 429) this.pause(null);
          for (const full of part) this.keep(full, act.errorText(e), started);
        } finally {
          for (const full of part) this.inflight.delete(full);
          cx.notify();
        }
      });
    }
  }

  pause(resetAt) {
    const until = resetAt ? Date.parse(resetAt) : NaN;
    this.pausedUntil = Number.isFinite(until) && until > Date.now() ? until : Date.now() + 5 * 60 * 1000;
  }

  apply(out, started) {
    if (out.rate) this.rate = out.rate;
    if (out.viewer) this.viewer = out.viewer;
    this.reviewErrors[out.chunk] = out.reviewError;
    if (out.limited) this.pause(out.rate?.resetAt);
    for (const [full, repo] of Object.entries(out.repos)) {
      if (repo.error && repo.transient) this.keep(full, repo.error, started);
      else if ((this.started[full] ?? 0) <= started) {
        this.data[full] = repo;
        // Asked before the last action landed: show it, but ask again at once.
        this.polled[full] = gh.settledAt(started, this.touchedAt[full], Date.now());
      }
    }
  }

  // A failed request keeps what the board shows, marked stale, rather than
  // blanking repositories that were fine a minute ago.
  keep(full, error, started) {
    if ((this.started[full] ?? 0) > started) return;
    const prev = this.data[full];
    this.data[full] = prev && !prev.error ? { ...prev, stale: error } : { full, error };
    this.polled[full] = Date.now();
  }

  // A push from a local checkout moves its remote refs: CI is about to start.
  // Worktrees share the main checkout's .git, so one watch covers them all.
  watch(full, cx) {
    if (this.watched.has(full)) return;
    this.watched.add(full);
    cx.spawn(async (cx) => {
      const root = await checkout(full);
      if (!root) return;
      try {
        while (!this.closed && repoList().includes(full)) {
          await watchFolder(`${root}/.git/refs/remotes`);
          if (this.closed || !repoList().includes(full)) break;
          this.hotUntil[full] = Date.now() + 2 * 60 * 1000;
          this.polled[full] = Math.min(this.polled[full] ?? 0, Date.now() - (HOT - 2) * 1000);
          // Also ends this loop after a reload, which stops a task at its next cx use.
          cx.notify();
        }
        this.watched.delete(full);
      } catch { /* no remotes folder: stays marked as watched, and the board polls as usual */ }
    });
  }

  // After an action, poll the repository at once and keep it hot a while.
  touched(full, cx) {
    this.touchedAt[full] = Date.now();
    this.hotUntil[full] = Date.now() + 3 * 60 * 1000;
    this.polled[full] = 0;
    this.tick(cx);
  }

  do(full, pr, label, fn, cx) {
    const key = `${full}#${pr.number}`;
    if (this.busy[key]) return;
    this.busy[key] = label;
    cx.spawn(async (cx) => {
      try { await fn(cx); }
      catch (e) { act.fail(`${label} ${full}#${pr.number}`, e); }
      finally { delete this.busy[key]; this.touched(full, cx); cx.notify(); }
    });
    cx.notify();
  }

  // Merging takes two clicks on the same head commit within a few seconds.
  merge(full, repo, pr, cx) {
    const key = `${full}#${pr.number}`, now = Date.now();
    if (!this.armed || this.armed.key !== key || this.armed.oid !== pr.oid || now - this.armed.at > ARM) {
      this.armed = { key, oid: pr.oid, at: now };
      cx.timer.after(ARM + 100, (cx) => { if (this.armed?.key === key && Date.now() - this.armed.at > ARM) { this.armed = null; cx.notify(); } });
      cx.notify();
      return;
    }
    this.armed = null;
    this.do(full, pr, "Merging", (cx) => act.merge(cx, pr, repo.methods), cx);
  }

  // Enter adds a repository only when the text names one and filters out
  // every PR, so a branch name like feat/login stays a filter.
  submit(cx) {
    const text = this.text.trim();
    const r = gh.splitRepo(text.replace(/^https:\/\/github\.com\//, "").replace(/\/$/, ""));
    if (!r) return;
    if (repoList().some((f) => { const repo = this.data[f]; return repo && !repo.error && this.visible(repo).length; })) return;
    this.addRepo(`${r.owner}/${r.name}`, cx);
  }

  addRepo(full, cx) {
    const list = repoList();
    if (!list.some((x) => x.toLowerCase() === full.toLowerCase())) setShared(REPOS, [...list, full]);
    this.text = ""; this.input.set_value("");
    this.polled[full] = 0;
    this.tick(cx);
  }

  removeRepo(full, cx) {
    if (this.removing !== full) {
      this.removing = full;
      cx.timer.after(ARM, (cx) => { if (this.removing === full) { this.removing = null; cx.notify(); } });
      cx.notify();
      return;
    }
    this.removing = null;
    setShared(REPOS, repoList().filter((x) => x !== full));
    delete this.data[full]; delete this.actions[full];
    cx.notify();
  }

  loadSuggestions(cx) {
    if (this.suggestions || this.loadingSuggestions) return;
    this.loadingSuggestions = true;
    cx.spawn(async (cx) => {
      try {
        const json = await graphql(cx, gh.viewerReposQuery);
        this.suggestions = (json?.data?.viewer?.repositories?.nodes ?? []).map((n) => n.nameWithOwner);
      } catch { this.suggestions = null; }
      finally { this.loadingSuggestions = false; cx.notify(); }
    });
  }

  toggleActions(full, cx) {
    if (this.actions[full]) delete this.actions[full];
    else { this.actions[full] = { loading: false, at: 0 }; this.maybeLoadActions(full, cx); }
    cx.notify();
  }

  maybeLoadActions(full, cx, force = false) {
    const a = this.actions[full];
    if (!a || a.loading) return;
    const pending = a.runs?.some((r) => r.state === "pending");
    if (!force && a.at && Date.now() - a.at < (pending ? HOT : FULL) * 1000) return;
    a.loading = true;
    cx.spawn(async (cx) => {
      try {
        // Workflow files change only with the default branch, so they are read
        // again only when its head moves; runs and releases keep their cadence.
        const oid = this.data[full]?.branchOid ?? null;
        const stale = !a.workflows || a.oid !== oid;
        const [meta, runs, releaseRuns] = await Promise.all([
          graphql(cx, stale ? gh.workflowsQuery(full) : gh.releasesQuery(full)),
          rest(cx, "GET", `/repos/${full}/actions/runs?per_page=20`),
          rest(cx, "GET", `/repos/${full}/actions/runs?event=release&per_page=5`),
        ]);
        if (this.actions[full] !== a) return;
        if (meta?.errors?.length && !meta?.data?.repository) throw new Error(meta.errors[0].message);
        const releases = gh.releasesModel(meta), tags = new Set(releases.map((r) => r.tag));
        // A partial answer leaves the workflows to be read again next time.
        if (stale && !meta?.errors?.length) {
          a.workflows = gh.workflowsModel(meta).filter((w) => w.dispatch);
          a.branch = meta?.data?.repository?.defaultBranchRef?.name ?? "main";
          a.oid = oid;
        }
        a.releases = releases;
        const seen = new Set();
        a.runs = [...(runs?.workflow_runs ?? []), ...(releaseRuns?.workflow_runs ?? [])]
          .filter((r) => !seen.has(r.id) && seen.add(r.id))
          .map((r) => gh.restRunModel(r, tags))
          .sort((x, y) => Date.parse(y.createdAt) - Date.parse(x.createdAt));
        a.error = null;
      } catch (e) { a.error = act.errorText(e); }
      finally { a.loading = false; a.at = Date.now(); cx.notify(); }
    });
  }

  runAction(full, id, label, fn, cx) {
    const a = this.actions[full];
    if (!a || a.busy?.[id]) return;
    (a.busy ??= {})[id] = label;
    cx.spawn(async (cx) => {
      try { await fn(cx); }
      catch (e) { act.fail(`${label} ${full}`, e); }
      finally { delete a.busy[id]; this.maybeLoadActions(full, cx, true); this.touched(full, cx); cx.notify(); }
    });
    cx.notify();
  }

  visible(repo) {
    const text = this.text.trim().toLowerCase();
    return repo.prs.filter((p) => {
      if (this.filter === "attention" && !gh.needsAttention(p, this.viewer)) return false;
      if (this.filter === "mine" && p.author !== this.viewer) return false;
      if (!text) return true;
      return `${p.number} ${p.title} ${p.author} ${p.head}`.toLowerCase().includes(text);
    });
  }

  render(cx) {
    // An item pane acted on a PR: settle its repository here too.
    const signal = shared(act.TOUCHED);
    if (signal?.at && signal.at !== this.lastSignal) {
      this.lastSignal = signal.at;
      if (repoList().includes(signal.repo)) this.touched(signal.repo, cx);
    }
    const t = theme(), repos = repoList();
    const all = repos.map((f) => this.data[f]).filter((r) => r && !r.error);
    const count = (fn) => all.reduce((n, r) => n + r.prs.filter(fn).length, 0);
    const counts = { all: count(() => true), attention: count((p) => gh.needsAttention(p, this.viewer)), mine: count((p) => p.author === this.viewer) };
    return v_flex().id("gh-board").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(this.topBar(t, counts, repos))
      .when(this.typing && Boolean(this.suggestions), (e) => e.child(this.suggestionList(t, repos)))
      .child(v_flex().id("gh-board-list").flex_1().min_h(0).overflow_y_scrollbar().pb(12)
        .when(!repos.length, (e) => e.child(div().p(16).text_color(t.dim).child("No repositories yet. Type owner/repo above and press Enter, or focus the box for suggestions.")))
        .children(repos.map((full) => this.repoSection(full, t))));
  }

  topBar(t, counts, repos) {
    const chip = (id, label, n) => div().id(`filter-${id}`).h(24).px(10).flex().items_center().gap(6).rounded(12).cursor_pointer().text_size(12)
      .bg(this.filter === id ? t.selected : t.background).border_1().border_color(this.filter === id ? t.accent : t.border)
      .on_click((_e, cx) => { this.filter = id; cx.notify(); })
      .child(label).child(div().text_color(t.dim).child(String(n)));
    const rate = this.rate ? `${this.rate.remaining} pts` : "";
    const paused = this.pausedUntil > Date.now() ? `rate limited, paused ${gh.age(new Date(Date.now() - (this.pausedUntil - Date.now())).toISOString())}` : "";
    const newest = Math.max(0, ...Object.values(this.polled));
    return h_flex().h(44).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border).bg(t.chrome)
      .child(div().font_semibold().child("GitHub"))
      .child(chip("all", "All", counts.all)).child(chip("attention", "Needs you", counts.attention)).child(chip("mine", "Mine", counts.mine))
      .child(div().id("gh-board-input").flex_1().min_w(120).h(28).px(10).flex().items_center().rounded(7).border_1()
        .border_color(this.typing ? t.accent : t.border).cursor_text().on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .child(Input.new(this.input).h_full().text_size(12).text_color(t.foreground)))
      .when(Object.values(this.reviewErrors).some(Boolean), (e) => e.child(div().text_size(11).text_color(t.dim).child("review requests unavailable")))
      .child(div().text_size(11).text_color(paused ? t.ansi1 : t.dim).child(paused || [rate, newest ? `${gh.age(new Date(newest).toISOString())} ago` : ""].filter(Boolean).join(" · ")))
      .child(button("gh-refresh", this.inflight.size ? "Refreshing…" : "Refresh", t, (_e, cx) => { this.pausedUntil = 0; this.tick(cx, true); }, { disabled: !repos.length }));
  }

  suggestionList(t, repos) {
    const text = this.text.trim().toLowerCase(), have = new Set(repos.map((r) => r.toLowerCase()));
    const list = this.suggestions.filter((s) => !have.has(s.toLowerCase()) && (!text || s.toLowerCase().includes(text))).slice(0, 8);
    if (!list.length) return div();
    return v_flex().flex_none().px(12).py(6).gap(2).border_b(1).border_color(t.border).bg(t.popover)
      .children(list.map((full) => h_flex().id(`suggest-${full}`).h(24).px(8).gap(8).items_center().rounded(5).cursor_pointer().hover((s) => s.bg(t.hover))
        .on_mouse_down("left", (_e, cx) => { cx.stop_propagation(); this.addRepo(full, cx); })
        .child(div().text_color(t.dim).child("+")).child(full)));
  }

  repoSection(full, t) {
    const repo = this.data[full];
    const header = h_flex().id(`repo-${full}`).h(34).flex_none().px(12).gap(8).items_center().bg(t.surface).border_b(1).border_color(t.border);
    if (!repo) return v_flex().child(header.child(dot("pending", t)).child(div().font_semibold().child(full)).child(div().text_color(t.dim).child("loading…")));
    if (repo.error) {
      return v_flex().child(header.child(dot("fail", t)).child(div().font_semibold().child(full)).child(div().flex_1().min_w(0).truncate().text_color(t.ansi1).text_size(12).child(repo.error))
        .child(button(`rm-${full}`, this.removing === full ? "Remove?" : "×", t, (_e, cx) => this.removeRepo(full, cx), { armed: this.removing === full })));
    }
    const prs = this.visible(repo);
    if (this.filter !== "all" && !prs.length && !this.actions[full]) return div();
    const latest = repo.runs[0];
    return v_flex()
      .child(header
        .child(dot(repo.branchCi === "none" && latest ? latest.state : repo.branchCi, t))
        .child(div().id(`open-${full}`).font_semibold().cursor_pointer().hover((s) => s.text_color(t.accent)).on_click((_e, cx) => cx.open_url(repo.url)).child(full))
        .when(Boolean(repo.branch), (e) => e.child(div().text_size(11).text_color(t.dim).child(repo.branch)))
        .children(repo.runs.slice(0, 3).map((r) => h_flex().id(`brun-${r.id}`).gap(4).items_center().text_size(11).text_color(t.muted).cursor_pointer()
          .on_click((_e, cx) => cx.open_url(r.url)).child(dot(r.state, t, 6)).child(r.name)))
        .child(div().flex_1())
        .when(Boolean(repo.stale), (e) => e.child(div().text_size(11).text_color(t.blocked).child("stale")))
        .when(Boolean(repo.release), (e) => e.child(div().id(`rel-${full}`).text_size(11).text_color(t.muted).cursor_pointer().on_click((_e, cx) => cx.open_url(repo.release.url)).child(repo.release.tag)))
        .child(div().text_size(11).text_color(t.dim).child(`${repo.prTotal} PRs · ${repo.issues} issues`))
        .child(button(`actions-${full}`, this.actions[full] ? "Actions ▴" : "Actions ▾", t, (_e, cx) => this.toggleActions(full, cx)))
        .child(button(`rm-${full}`, this.removing === full ? "Remove?" : "×", t, (_e, cx) => this.removeRepo(full, cx), { armed: this.removing === full })))
      .when(Boolean(this.actions[full]), (e) => e.child(this.actionsPanel(full, t)))
      .children(prs.map((pr) => this.prRow(full, repo, pr, t)))
      .when(repo.prTotal > repo.prs.length && this.filter === "all", (e) => e.child(div().px(12).py(4).text_size(11).text_color(t.dim).child(`${repo.prTotal - repo.prs.length} older PRs not shown`)));
  }

  prRow(full, repo, pr, t) {
    const key = `${full}#${pr.number}`, busy = this.busy[key], armed = this.armed?.key === key && this.armed.oid === pr.oid;
    const review = reviewLabel(pr.review);
    const target = { repo: full, number: pr.number, kind: "pr" };
    const buttons = busy ? [div().text_size(11).text_color(t.working).child(`${busy}…`)] : this.prButtons(full, repo, pr, t, armed);
    return h_flex().id(`pr-${key}`).h(32).flex_none().px(12).gap(8).items_center().border_b(1).border_color(alpha(t.border, "66")).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_click((_e, cx) => act.openItem(target))
      .child(dot(pr.ci, t))
      .child(div().w(44).flex_none().text_color(t.dim).text_size(12).child(`#${pr.number}`))
      .child(div().flex_1().min_w(0).truncate().child(pr.title))
      .child(div().flex_none().text_size(11).text_color(t.dim).child(`${pr.author} · ${gh.age(pr.updatedAt)}`))
      .child(badge(mergeLabel(pr.merge), stateColor(pr.merge, t), t))
      .when(pr.ci !== "none", (e) => e.child(badge(ciLabel(pr.ci), stateColor(pr.ci, t), t)))
      .when(Boolean(review), (e) => e.child(badge(review, pr.review === "APPROVED" ? t.ansi2 : t.blocked, t)))
      .when(Boolean(pr.reviewRequested), (e) => e.child(badge("your review", t.accent, t)))
      .when(Boolean(pr.auto), (e) => e.child(badge("auto-merge", t.ansi4, t)))
      .children(buttons);
  }

  prButtons(full, repo, pr, t, armed) {
    const out = [];
    if (pr.merge === "behind" && pr.can.update) out.push(button(`upd-${full}-${pr.number}`, "Update", t, (_e, cx) => this.do(full, pr, "Updating", (cx) => act.updateBranch(cx, pr), cx)));
    if (pr.ci === "fail") out.push(button(`rerun-${full}-${pr.number}`, "Rerun", t, (_e, cx) => this.do(full, pr, "Rerunning", async (cx) => {
      const detail = await act.loadPr(cx, full, pr.number);
      await act.rerunFailed(cx, full, detail?.checks ?? []);
    }, cx)));
    if (pr.auto && pr.can.disableAuto) out.push(button(`auto-${full}-${pr.number}`, "Auto off", t, (_e, cx) => this.do(full, pr, "Disabling auto-merge", (cx) => act.setAuto(cx, pr, repo.methods, false), cx)));
    else if (!pr.auto && pr.can.enableAuto && repo.autoMergeAllowed) out.push(button(`auto-${full}-${pr.number}`, "Auto", t, (_e, cx) => this.do(full, pr, "Enabling auto-merge", (cx) => act.setAuto(cx, pr, repo.methods, true), cx)));
    const label = gh.mergeAction(pr);
    if (label) out.push(button(`merge-${full}-${pr.number}`, armed ? `${label}?` : label, t, (_e, cx) => this.merge(full, repo, pr, cx), { primary: pr.merge === "clean", armed }));
    if (gh.fixable(pr)) {
      out.push(button(`fix-${full}-${pr.number}`, "Fix", t, (_e, cx) => this.do(full, pr, "Starting agent", (cx) => act.fixWithAgent(cx, full, pr), cx)));
    }
    out.push(button(`web-${full}-${pr.number}`, "↗", t, (_e, cx) => cx.open_url(pr.url)));
    return out;
  }

  actionsPanel(full, t) {
    const a = this.actions[full];
    const section = (title) => div().px(12).pt(8).pb(2).text_size(11).font_semibold().text_color(t.dim).child(title);
    const body = v_flex().pb(6).bg(t.canvas).border_b(1).border_color(t.border);
    if (!a.runs) return body.child(div().p(10).text_size(12).text_color(a.error ? t.ansi1 : t.dim).child(a.error ?? "Loading runs…"));
    const releaseRuns = a.runs.filter((r) => r.release);
    return body
      .when(Boolean(a.error), (e) => e.child(div().px(12).pt(6).text_size(11).text_color(t.ansi1).child(a.error)))
      .when(a.workflows.length > 0, (e) => e.child(section("Run a workflow"))
        .child(h_flex().px(12).gap(6).children(a.workflows.map((w) => button(`wf-${full}-${w.file}`, a.busy?.[w.file] ? `${w.name}…` : `▶ ${w.name}${w.inputs ? " (inputs)" : ""}`, t,
          (_e, cx) => this.runAction(full, w.file, "Dispatching", (cx) => act.dispatch(cx, full, w.file, a.branch), cx))))))
      .when(releaseRuns.length > 0 || a.releases.length > 0, (e) => e.child(section("Releases"))
        .child(h_flex().px(12).gap(8).children(a.releases.slice(0, 5).map((r) => div().id(`relx-${full}-${r.tag}`).text_size(12).cursor_pointer()
          .text_color(r.draft ? t.dim : t.foreground).on_click((_e, cx) => cx.open_url(r.url)).child(`${r.tag} · ${gh.age(r.at)}`))))
        .children(releaseRuns.slice(0, 5).map((r) => this.runRow(full, a, r, t))))
      .child(section("Recent runs"))
      .children(a.runs.filter((r) => !r.release).slice(0, 15).map((r) => this.runRow(full, a, r, t)));
  }

  runRow(full, a, r, t) {
    const busy = a.busy?.[r.id];
    return h_flex().id(`run-${full}-${r.id}`).h(26).px(12).gap(8).items_center().cursor_pointer().hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => cx.open_url(r.url))
      .child(dot(r.state, t, 7))
      .child(div().w(140).flex_none().truncate().text_size(12).child(r.name ?? ""))
      .child(div().flex_1().min_w(0).truncate().text_size(12).text_color(t.muted).child(r.title ?? ""))
      .child(div().flex_none().text_size(11).text_color(t.dim).child(`${r.branch ?? ""} · ${r.event} · ${r.actor} · ${gh.age(r.updatedAt)}`))
      .children(busy ? [div().text_size(11).text_color(t.working).child(`${busy}…`)] : [
        r.state === "pending" ? button(`cancel-${r.id}`, "Cancel", t, (_e, cx) => this.runAction(full, r.id, "Cancelling", (cx) => act.cancelRun(cx, full, r.id), cx)) : null,
        r.state === "fail" || r.state === "cancel" ? button(`rerunf-${r.id}`, "Rerun failed", t, (_e, cx) => this.runAction(full, r.id, "Rerunning", (cx) => act.rerunRun(cx, full, r.id, true), cx)) : null,
        r.state !== "pending" ? button(`rerun-${r.id}`, "Rerun", t, (_e, cx) => this.runAction(full, r.id, "Rerunning", (cx) => act.rerunRun(cx, full, r.id, false), cx)) : null,
      ].filter(Boolean));
  }
}
