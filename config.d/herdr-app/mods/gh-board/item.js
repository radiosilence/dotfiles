// One PR in a pane: its state, checks, description and conversation, with the
// board's actions and a comment box. The preview copy follows the board's
// clicks; a pinned copy keeps the item it was opened with.

import { div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, TextView } from "gpui-base";
import { props, setShared, shared, theme } from "herdr";
import * as gh from "./gh.js";
import * as act from "./actions.js";
import { badge, button, ciLabel, dot, mergeLabel, reviewLabel, stateColor } from "./ui.js";

const HOT = 15000, IDLE = 60000, ARM = 4000;

const targetKey = (t) => (t ? `${t.repo}#${t.number}#${t.kind}` : "");

export class Item {
  init(cx) {
    this.preview = Boolean(props()?.preview);
    this.tab = act.ownTab();
    this.gen = 0;
    this.comment = InputState.new({ placeholder: "Comment" });
    this.comment.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.comment.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.comment.on("submit", (_e, cx) => this.send(cx));
    if (this.preview) setShared(act.PREVIEW_AT, { tab: this.tab });
    cx.timer.every(5000, (cx) => this.tick(cx));
    this.follow(cx);
  }

  async close() {
    if (this.preview && shared(act.PREVIEW_AT)?.tab === this.tab) setShared(act.PREVIEW_AT, null);
  }

  target() {
    const p = this.preview ? shared(act.PREVIEW) : props();
    return p?.repo && p?.number ? { repo: p.repo, number: Number(p.number), kind: p.kind ?? "pr" } : null;
  }

  // A new target drops the old one's answer, even if it arrives later.
  follow(cx) {
    const key = targetKey(this.target());
    if (key === this.key) return;
    this.key = key; this.item = null; this.error = null; this.at = 0; this.armed = false;
    this.load(cx);
  }

  tick(cx) {
    if (!act.isShown(this.tab) || this.loading) return;
    const hot = this.item && (this.item.ci === "pending" || this.item.merge === "unknown" || this.busy);
    if (Date.now() - this.at >= (hot ? HOT : IDLE)) this.load(cx);
  }

  load(cx) {
    const target = this.target(), gen = ++this.gen;
    if (!target) { cx.notify(); return; }
    if (target.kind !== "pr") { this.error = null; cx.notify(); return; }
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const item = await act.loadPr(cx, target.repo, target.number);
        if (gen !== this.gen) return;
        if (!item) { this.error = "Not found"; return; }
        if (this.armed && this.item?.oid !== item.oid) this.armed = false;
        this.item = item; this.error = null;
      } catch (e) {
        if (gen === this.gen) this.error = act.errorText(e);
      } finally {
        if (gen === this.gen) { this.loading = false; this.at = Date.now(); }
        cx.notify();
      }
    });
  }

  do(label, fn, cx) {
    if (this.busy) return;
    const target = this.target(), gen = this.gen;
    this.busy = label;
    cx.spawn(async (cx) => {
      try { await fn(cx); }
      catch (e) { act.fail(`${label} ${target.repo}#${target.number}`, e); }
      finally { this.busy = null; if (gen === this.gen) this.load(cx); cx.notify(); }
    });
    cx.notify();
  }

  merge(cx) {
    const it = this.item;
    if (!this.armed || this.armedOid !== it.oid || Date.now() - this.armedAt > ARM) {
      this.armed = true; this.armedOid = it.oid; this.armedAt = Date.now();
      cx.timer.after(ARM + 100, (cx) => { if (this.armed && Date.now() - this.armedAt > ARM) { this.armed = false; cx.notify(); } });
      cx.notify();
      return;
    }
    this.armed = false;
    this.do("Merging", (cx) => act.merge(cx, it, it.methods), cx);
  }

  send(cx) {
    const body = this.comment.value().trim(), it = this.item;
    if (!body || !it) return;
    this.do("Commenting", async (cx) => { await act.comment(cx, it.id, body); this.comment.set_value(""); }, cx);
  }

  render(cx) {
    this.follow(cx);
    const t = theme(), target = this.target(), it = this.item;
    const root = v_flex().id("gh-item").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13);
    if (!target) return root.child(div().p(16).text_color(t.dim).child("Click a PR on the board to show it here."));
    if (target.kind !== "pr") {
      return root.child(div().p(16).text_color(t.dim).child(`Issue views are not built yet.`))
        .child(div().px(16).child(button("issue-web", "Open on GitHub", t, (_e, cx) => cx.open_url(`https://github.com/${target.repo}/issues/${target.number}`))));
    }
    if (!it) return root.child(div().p(16).text_color(this.error ? t.ansi1 : t.dim).child(this.error ?? `Loading ${target.repo}#${target.number}…`));
    return root
      .child(this.header(target, it, t))
      .child(v_flex().id("gh-item-scroll").flex_1().min_h(0).overflow_y_scrollbar().p(14).gap(14)
        .child(this.checks(target, it, t))
        .child(this.markdown("gh-item-body", it.body || "_No description._", t))
        .children(it.timeline.map((e, i) => this.event(e, i, t))))
      .child(this.composer(it, t));
  }

  header(target, it, t) {
    const review = reviewLabel(it.review);
    const open = it.state === "open";
    return v_flex().flex_none().px(14).py(10).gap(6).border_b(1).border_color(t.border).bg(t.chrome)
      .child(h_flex().gap(8).items_center()
        .child(dot(open ? it.ci : it.state === "merged" ? "merged" : "none", t))
        .child(div().text_color(t.dim).child(`${target.repo}#${it.number}`))
        .child(div().flex_1().min_w(0).truncate().font_semibold().child(it.title))
        .when(this.loading, (e) => e.child(div().text_size(11).text_color(t.dim).child("…"))))
      .child(h_flex().gap(6).items_center().text_size(11).text_color(t.muted)
        .child(div().child(`${it.author} wants ${it.base} ← ${it.head}`))
        .child(div().text_color(t.ansi2).child(`+${it.additions}`)).child(div().text_color(t.ansi1).child(`−${it.deletions}`))
        .child(div().text_color(t.dim).child(`${it.changedFiles} files · ${gh.age(it.updatedAt)} ago`))
        .child(div().flex_1())
        .child(badge(open ? mergeLabel(it.merge) : it.state, stateColor(open ? it.merge : it.state, t), t))
        .when(open && it.ci !== "none", (e) => e.child(badge(ciLabel(it.ci), stateColor(it.ci, t), t)))
        .when(Boolean(review), (e) => e.child(badge(review, it.review === "APPROVED" ? t.ansi2 : t.blocked, t)))
        .when(Boolean(it.auto), (e) => e.child(badge("auto-merge", t.ansi4, t)))
        .children(it.labels.map((l) => badge(l.name, `#${l.color}`, t))))
      .child(h_flex().gap(6).items_center().children(this.buttons(target, it, t)));
  }

  buttons(target, it, t) {
    if (this.busy) return [div().text_size(11).text_color(t.working).child(`${this.busy}…`)];
    const out = [], open = it.state === "open";
    if (open && it.draft) out.push(button("ready", "Ready for review", t, (_e, cx) => this.do("Marking ready", (cx) => act.markReady(cx, it), cx)));
    if (open && it.merge === "behind" && it.can.update) out.push(button("update", "Update branch", t, (_e, cx) => this.do("Updating", (cx) => act.updateBranch(cx, it), cx)));
    if (open && it.checks.some((c) => c.state === "fail" || c.state === "cancel")) out.push(button("rerun", "Rerun failed", t, (_e, cx) => this.do("Rerunning", (cx) => act.rerunFailed(cx, target.repo, it.checks), cx)));
    if (open && it.auto && it.can.disableAuto) out.push(button("auto", "Auto-merge off", t, (_e, cx) => this.do("Disabling auto-merge", (cx) => act.setAuto(cx, it, it.methods, false), cx)));
    else if (open && !it.auto && it.can.enableAuto) out.push(button("auto", "Auto-merge", t, (_e, cx) => this.do("Enabling auto-merge", (cx) => act.setAuto(cx, it, it.methods, true), cx)));
    if (open && (it.merge === "clean" || (it.can.admin && it.merge !== "conflict" && !it.draft))) {
      const label = it.merge === "clean" ? "Merge" : "Admin merge";
      out.push(button("merge", this.armed ? `${label}?` : label, t, (_e, cx) => this.merge(cx), { primary: it.merge === "clean", armed: this.armed }));
    }
    if (open && !it.fork) out.push(button("fix", act.starting.has(`${target.repo}#${it.number}`) ? "Opening…" : "Agent", t, (_e, cx) => this.do("Starting agent", (cx) => act.fixWithAgent(cx, target.repo, it), cx)));
    out.push(div().flex_1());
    if (this.preview) out.push(button("pin", "Pin", t, () => act.pinItem(target)));
    out.push(button("reload", "Reload", t, (_e, cx) => this.load(cx)));
    out.push(button("web", "↗", t, (_e, cx) => cx.open_url(it.url)));
    return out;
  }

  checks(target, it, t) {
    if (!it.checks.length) return div();
    const failing = it.checks.filter((c) => c.state !== "pass" && c.state !== "skip");
    const rest = it.checks.length - failing.length;
    return v_flex().gap(2).p(8).rounded(8).border_1().border_color(t.border).bg(t.surface)
      .child(div().pb(4).text_size(11).font_semibold().text_color(t.dim).child(`Checks · ${it.checks.length}${it.checks.more ? ` (+${it.checks.more} more on GitHub)` : ""}`))
      .children((this.allChecks ? it.checks : failing).map((c, i) => h_flex().id(`check-${i}`).h(22).gap(8).items_center().rounded(4).px(4)
        .when(Boolean(c.url), (e) => e.cursor_pointer().hover((s) => s.bg(t.hover)).on_click((_e, cx) => cx.open_url(c.url)))
        .child(dot(c.state, t, 7)).child(div().flex_1().min_w(0).truncate().text_size(12).child(c.name))
        .when(c.required, (e) => e.child(div().text_size(10).text_color(t.dim).child("required")))))
      .when(rest > 0, (e) => e.child(div().id("checks-toggle").pt(2).text_size(11).text_color(t.accent).cursor_pointer()
        .on_click((_e, cx) => { this.allChecks = !this.allChecks; cx.notify(); })
        .child(this.allChecks ? "Hide passing" : `${rest} passing or skipped`)));
  }

  markdown(id, text, t) {
    return TextView.markdown(id, text).selectable(true).text_size(13).text_color(t.foreground)
      .on_link_click((url, cx) => act.openUrl(url, cx));
  }

  event(e, i, t) {
    if (e.kind === "commit") {
      return h_flex().gap(8).items_center().text_size(12).text_color(t.muted)
        .child(div().text_color(t.dim).font_family("JetBrains Mono").child(e.oid.slice(0, 7))).child(div().flex_1().min_w(0).truncate().child(e.body)).child(div().text_color(t.dim).child(gh.age(e.at)));
    }
    if (e.kind === "event") return div().text_size(12).text_color(t.dim).child(`${e.who} ${e.body} · ${gh.age(e.at)} ago`);
    const tone = e.state === "APPROVED" ? t.ansi2 : e.state === "CHANGES_REQUESTED" ? t.ansi1 : t.border;
    const verb = e.kind === "review" ? ({ APPROVED: "approved", CHANGES_REQUESTED: "requested changes", COMMENTED: "reviewed", DISMISSED: "review dismissed" }[e.state] ?? "reviewed") : "commented";
    if (e.kind === "review" && !e.body) return div().text_size(12).text_color(tone === t.border ? t.dim : tone).child(`${e.who} ${verb} · ${gh.age(e.at)} ago`);
    return v_flex().rounded(8).border_1().border_color(tone).overflow_hidden()
      .child(h_flex().px(10).h(26).gap(6).items_center().bg(t.surface).text_size(11).text_color(t.muted)
        .child(div().font_semibold().text_color(t.foreground).child(e.who)).child(div().child(`${verb} · ${gh.age(e.at)} ago`)))
      .child(div().p(10).child(this.markdown(`gh-ev-${i}`, e.body, t)));
  }

  composer(it, t) {
    return h_flex().flex_none().p(10).gap(8).border_t(1).border_color(t.border)
      .child(div().id("gh-comment").flex_1().min_w(0).h(30).px(10).flex().items_center().rounded(7).border_1()
        .border_color(this.typing ? t.accent : t.border).cursor_text().on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .child(Input.new(this.comment).h_full().text_size(12).text_color(t.foreground)))
      .child(button("send", "Comment", t, (_e, cx) => this.send(cx), { primary: true, disabled: Boolean(this.busy) }));
  }
}
