import { View, div, svg } from "gpui-kit";
import { Button, Checkbox, h_flex, v_flex } from "gpui-base";
import { appHome, home, exec, theme, props, openOverlay, closeOverlay,
  shared, setShared, nextCommand, spaces, agents, run, window } from "herdr";

const NAMES = { codex: "Codex", claude: "Claude", cursor: "Cursor" };
const ORDER = ["codex", "claude", "cursor"];
const SNAPSHOT = "usage-bar.snapshot";
const PROVIDERS = "usage-bar.providers";
const COUNTDOWNS = "usage-bar.countdowns";

function showCountdown(provider) {
  const saved = shared(COUNTDOWNS)?.[provider];
  return typeof saved === "boolean" ? saved : provider !== "cursor";
}

function enabledProviders() {
  const saved = shared(PROVIDERS);
  return Array.isArray(saved) ? ORDER.filter(name => saved.includes(name)) : ["claude"];
}

const ERRORS = {
  not_signed_in: "Not signed in", expired: "Sign-in expired", forbidden: "Usage access refused",
  missing_scope: "Usage permission missing", no_quota: "No quota reported", offline: "Offline",
  rate_limited: "Try again later", keychain_locked: "Keychain locked",
  keychain_missing: "Sign-in key missing",
  keychain_denied: "Keychain access denied", keychain_error: "Keychain unavailable",
  cancelled: "Request cancelled", invalid_session: "Session not connected", reader_error: "Reader error",
};

function percent(n) {
  if (n > 0 && n < 1) return "<1%";
  if (n < 100 && n > 99) return ">99%";
  return `${Math.round(n)}%`;
}

function resetText(value) {
  if (!value) return "Reset time unavailable";
  const date = new Date(typeof value === "number" ? value * 1000 : value);
  return Number.isNaN(date.getTime()) ? "Reset time unavailable" : `Resets ${date.toLocaleString()}`;
}

function resetCountdown(value, now = Date.now()) {
  if (value == null || value === "") return null;
  const reset = new Date(typeof value === "number" ? value * 1000 : value).getTime();
  if (!Number.isFinite(reset)) return null;
  const minutes = Math.ceil((reset - now) / 60000);
  if (minutes <= 0) return "Reset pending";
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor(minutes / 60) % 24;
  if (days) return `${days}d ${hours}h`;
  if (minutes >= 60) return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
  return `${minutes}m`;
}

function usageColor(n, t) {
  return n >= 95 ? t.blocked : n >= 75 ? t.working : t.foreground;
}

function windowName(label) {
  if (label === "7d") return "Weekly · 7 days";
  if (label === "5h") return "Current · 5 hours";
  if (label === "Other") return "Other models";
  return label;
}

function control(id, text, action, t) {
  return Button.new(id).px(10).py(6).rounded(5).cursor_pointer()
    .text_color(t.foreground).bg(t.surface).hover(s => s.bg(t.raised))
    .accessibility_label(text).child(text).on_click(action);
}

export default class UsageBar extends View {
  init(_props, cx) {
    this.records = {};
    this.busy = {};
    this.width = 1200;
    this.detail = props()?.provider || null;
    this.settings = props()?.settings || false;
    // Countdown data changes by the minute; this does not fetch provider usage.
    if (!this.settings) cx.timer.every(60000, cx => cx.notify());
    if (this.detail || this.settings) return;
    setShared(SNAPSHOT, {});
    this.refreshAll(cx);
    cx.timer.every(30000, cx => this.refreshAll(cx));
    cx.spawn(async cx => {
      for (;;) {
        const command = await nextCommand();
        if (command === "refresh") this.refreshAll(cx);
        const provider = command.replace("connect-", "");
        if (command.startsWith("connect-") && ORDER.includes(provider)) {
          this.refresh(provider, cx, true);
        }
      }
    });
  }

  refreshAll(cx) {
    for (const provider of enabledProviders()) this.refresh(provider, cx);
  }

  refresh(provider, cx, allowKeychain = false, copiedSession = false) {
    if (this.busy[provider]) return;
    this.busy[provider] = true;
    cx.notify();
    cx.spawn(async cx => {
      try {
        const args = [`${appHome()}/mods/usage-bar/collect.py`, provider];
        if (allowKeychain) args.push("--allow-keychain-prompt");
        if (copiedSession) args.push("--cursor-session-from-clipboard");
        // mise sets CLAUDE_CONFIG_DIR, which the app's environment lacks; work
        // folders override it, so resolve it from home.
        const result = await exec("mise", ["exec", "--", "python3", ...args], { cwd: home() });
        if (result.code !== 0) throw new Error("helper");
        const record = JSON.parse(result.stdout);
        if (record.provider !== provider || !Array.isArray(record.windows)) throw new Error("data");
        this.records[provider] = record;
      } catch (_) {
        this.records[provider] = { provider, windows: [], updated: null,
          error: "The local usage helper did not finish successfully.", code: "reader_error",
          action: "Check that Python 3 is available. A long-running permission dialog can also time out; close it and retry." };
      }
      this.busy[provider] = false;
      setShared(SNAPSHOT, { ...(shared(SNAPSHOT) || {}), [provider]: this.records[provider] });
      cx.notify();
    });
  }

  open(provider) {
    const connected = Boolean(shared(SNAPSHOT)?.[provider]?.windows?.length);
    openOverlay({ mod: "usage-bar", props: { provider }, kind: "popup", width: 480,
      height: provider === "cursor" ? (connected ? 440 : 500) : provider === "codex" ? 450 : 380 });
  }

  picker() {
    const t = theme();
    const enabled = enabledProviders();
    return v_flex().size_full().p(16).gap(10).bg(t.chrome).text_size(12).text_color(t.foreground)
      .child(h_flex().items_center().justify_between()
        .child(div().font_semibold().text_size(15).child("Usage providers"))
        .child(control("close-picker", "Close", () => closeOverlay(props().overlay), t)))
      .child(div().text_color(t.muted).child("Choose which providers appear in the bar."))
      .children(ORDER.map(provider => Button.new(`show-${provider}`).h_flex().items_center().gap(10)
        .w_full().px(10).py(8).rounded(5).selected(enabled.includes(provider))
        .bg(enabled.includes(provider) ? t.selected : t.surface).hover(s => s.bg(t.raised))
        .accessibility_label(`Show ${NAMES[provider]}: ${enabled.includes(provider) ? "on" : "off"}`)
        .child(div().w(16).child(enabled.includes(provider) ? "✓" : "○"))
        .child(NAMES[provider]).on_click((_event, cx) => {
          const before = enabledProviders();
          const next = before.includes(provider) ? before.filter(name => name !== provider) : [...before, provider];
          setShared(PROVIDERS, ORDER.filter(name => next.includes(name)));
          if (!before.includes(provider)) this.refresh(provider, cx);
          cx.notify();
        })))
      .child(div().text_size(11).text_color(t.dim).child("Choices are saved. Hidden providers stop automatic refresh."));
  }

  chip(provider, compact, t) {
    const record = shared(SNAPSHOT)?.[provider] || this.records[provider];
    const windows = record?.windows || [];
    const title = `${NAMES[provider]} usage — ${record?.error || windows.map(w =>
      `${w.label}: ${percent(w.used)} used. ${resetCountdown(w.reset) || "Countdown unavailable"}. ${resetText(w.reset)}`).join("; ") || "Loading"}. Click for details.`;
    const chip = Button.new(`usage-${provider}`).h_flex().items_center().gap(compact ? 5 : 7)
      .h(24).px(compact ? 6 : 8).rounded(4).flex_shrink_0().cursor_pointer()
      .hover(s => s.bg(t.raised)).accessibility_label(title).tooltip(title)
      .on_click(() => this.open(provider))
      .child(div().font_semibold().text_color(t.foreground).child(NAMES[provider]));
    if (!record) return chip.child(div().text_color(t.dim).child("…"));
    if (!windows.length) return chip.child(div().text_color(t.dim).child("!"));
    windows.forEach((w, index) => {
      if (index) chip.child(div().text_color(t.dim).child("·"));
      chip.child(div().text_color(t.muted).child(w.label));
      chip.child(div().text_color(usageColor(w.used, t)).child(percent(w.used)));
      const remaining = resetCountdown(w.reset);
      if (showCountdown(provider) && remaining) {
        chip.child(div().text_size(10.5).text_color(t.dim).child(`(${remaining})`));
      }
    });
    return chip;
  }

  details() {
    const t = theme();
    const provider = this.detail;
    const record = shared(SNAPSHOT)?.[provider];
    const connected = Boolean(record?.windows?.length || (provider === "codex" && record?.credits));
    const body = v_flex().id("usage-details").size_full().p(18).gap(12).bg(t.chrome).overflow_y_scrollbar()
      .text_size(12).text_color(t.foreground)
      .child(h_flex().items_center().justify_between()
        .child(div().text_size(16).font_semibold().child(`${NAMES[provider]} usage`))
        .child(control("close", "Close", () => closeOverlay(props().overlay), t)))
      .child(div().text_color(t.muted).child(provider === "cursor"
        ? "Auto is included Cursor-model usage. Other is named-model usage. Both are quota used for this billing cycle."
        : "Percentages show quota used in each rolling window."));
    if (connected) {
      for (const w of record.windows) {
        const remaining = resetCountdown(w.reset);
        body.child(v_flex().gap(5)
          .child(h_flex().justify_between()
            .child(div().child(windowName(w.label)))
            .child(div().font_semibold().text_color(usageColor(w.used, t)).child(`${percent(w.used)} used`)))
          .child(div().h(4).w_full().rounded(2).bg(t.border)
            .child(div().h(4).w(395 * Math.min(100, w.used) / 100).rounded(2).bg(usageColor(w.used, t))))
          .when(Boolean(remaining), el => el.child(div().text_size(11.5).text_color(t.muted)
            .child(remaining === "Reset pending" ? remaining : `Resets in ${remaining}`)))
          .child(div().text_size(11).text_color(t.dim).child(resetText(w.reset))));
      }
      if (provider === "codex") {
        const credits = record.credits;
        const balance = credits?.unlimited ? "Unlimited"
          : credits?.balance != null ? `${credits.balance} credits`
          : credits?.has_credits ? "Available · balance not reported"
          : credits?.has_credits === false ? "No remaining credits" : "Not reported";
        body.child(v_flex().gap(5)
          .child(h_flex().justify_between()
            .child(div().child("Credits remaining"))
            .child(div().font_semibold().child(balance)))
          .child(div().text_size(11).text_color(t.muted)
            .child("Additional usage credits, separate from your plan’s rolling limits.")));
      }
      body.child(div().text_size(11).text_color(t.dim)
        .child(`Updated ${new Date(record.updated * 1000).toLocaleTimeString()} · refreshes every 30 seconds`));
    } else {
      body.child(div().font_semibold().text_color(t.working).child(ERRORS[record?.code] || "Usage unavailable"))
        .child(div().text_color(t.muted).child(record?.error || "Reading usage…"));
      if (record?.action) body.child(div().text_size(11.5).text_color(t.muted).child(record.action));
    }
    const countdown = showCountdown(provider);
    body.child(Checkbox.new(`countdown-${provider}`).h_flex().items_center().gap(8).py(6)
      .cursor_pointer().checked(countdown).text_color(t.muted)
      .accessibility_label(`Show ${NAMES[provider]} countdowns in bar`)
      .child(div().size(14).flex_shrink_0().flex().items_center().justify_center().rounded(3)
        .border(1).border_color(countdown ? t.accent : t.border)
        .bg(countdown ? t.selected : t.surface).text_size(11).text_color(t.foreground)
        .child(countdown ? "✓" : ""))
      .child("Show countdowns in bar")
      .on_change((checked, cx) => {
        setShared(COUNTDOWNS, { ...(shared(COUNTDOWNS) || {}), [provider]: checked });
        cx.notify();
      }));
    body.child(div().flex_1());
    const pending = ORDER.some(name => this.busy[name]);
    const actions = h_flex().gap(8).child(control("refresh-provider", pending ? "Refreshing…" : "Refresh all",
      (_event, cx) => this.refreshAll(cx), t).disabled(pending));
    if (!connected && (provider === "claude" || provider === "cursor")) {
      actions.child(control("connect-provider", this.busy[provider] ? "Connecting…" : "Retry Keychain",
        (_event, cx) => this.refresh(provider, cx, true), t).disabled(Boolean(this.busy[provider]))
        .tooltip("Ask macOS to allow Python to read this provider's sign-in item. Automatic refresh never prompts."));
    }
    body.child(actions);
    if (provider === "cursor" && !connected) {
      body.child(div().h(1).bg(t.border)).child(div().font_semibold().child("Connect without Keychain"))
        .child(div().text_size(11.5).text_color(t.muted).child("In a signed-in cursor.com tab: DevTools → Application → Cookies → WorkosCursorSessionToken. Copy only its value, then click below."))
        .child(control("copied-session", this.busy.cursor ? "Connecting…" : "Use copied browser session",
          (_event, cx) => this.refresh("cursor", cx, false, true), t).disabled(Boolean(this.busy.cursor)))
        .child(div().text_size(11).text_color(t.dim).child("Reads the clipboard only on click. Saves the validated session privately on this Mac for automatic refresh. Do not paste it into chat."));
    }
    return body;
  }

  render() {
    if (this.settings) return this.picker();
    if (this.detail) return this.details();
    const t = theme();
    const compact = this.width < 700;
    const workspaceStatus = Boolean(props()?.workspaceStatus);
    return h_flex().id("usage-bar").size_full().items_center().px(6).gap(2)
      .bg(t.chrome).border_t(1).border_color(t.border).text_size(11.5)
      .on_size_change((size, cx) => {
        if (this.width !== size.width) { this.width = size.width; cx.notify(); }
      })
      .when(workspaceStatus, el => el.child(this.workspaceStatus(t)))
      .child(Button.new("usage-provider-picker").size(24).flex_shrink_0().rounded(4).cursor_pointer()
        .hover(s => s.bg(t.raised)).text_color(t.muted)
        .child(svg("mods/usage-bar/tokens.svg").size(14))
        .accessibility_label("Choose usage providers").tooltip("Choose which providers to display")
        .on_click(() => openOverlay({ mod: "usage-bar", props: { settings: true }, kind: "popup", width: 310, height: 275 })))
      .child(h_flex().id("usage-providers").items_center().gap(2).min_w(0).overflow_x_scroll()
        .when(!workspaceStatus, el => el.flex_1())
        .children(enabledProviders().map(provider => this.chip(provider, compact, t)))
        .when(enabledProviders().length === 0, el => el.child(div().text_color(t.dim).px(6).child("Choose providers")))
        .child(Button.new("refresh-usage").px(8).h(24).flex_shrink_0().rounded(4).cursor_pointer()
          .text_color(t.muted).hover(s => s.bg(t.raised)).child("↻")
          .accessibility_label("Refresh usage for Codex, Claude and Cursor")
          .tooltip("Refresh usage · automatic refresh every 30 seconds")
          .on_click((_event, cx) => this.refreshAll(cx))))
      .when(workspaceStatus, el => el.child(div().flex_1()))
      .when(workspaceStatus && this.width > 900, el => el.child(Button.new("usage-commands").pr(8).text_color(t.dim)
        .on_click(() => run("app.palette"))
        .child(`${window()?.platform === "macos" ? "⌘" : "Ctrl"} Shift P  commands`)))
      .when(!workspaceStatus && this.width > 760, el => el.child(div().px(8).text_color(t.dim).child("quota used")));
  }

  workspaceStatus(t) {
    const space = spaces().find(item => item.active);
    const list = agents();
    const needs = list.filter(agent => agent.status === "blocked").length;
    const label = (icon, text) => h_flex().gap(6).items_center().flex_shrink_0()
      .child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    return h_flex().id("usage-workspace-status").flex_shrink_0().pl(8).pr(10).gap(16)
      .items_center().text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), el => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().flex_shrink_0()
        .child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, el => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))));
  }
}
