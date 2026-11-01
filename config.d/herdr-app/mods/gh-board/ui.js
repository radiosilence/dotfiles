// Small pieces both views draw.

import { div } from "gpui-kit";

// Theme colors may already carry alpha (#rrggbbaa); this replaces it.
export const alpha = (color, aa) => /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(color) ? color.slice(0, 7) + aa : color;

export function stateColor(state, t) {
  switch (state) {
    case "pass": case "clean": case "merged": return t.ansi2;
    case "fail": case "conflict": return t.ansi1;
    case "pending": case "unknown": return t.working;
    case "behind": case "blocked": case "unstable": return t.blocked;
    default: return t.dim;
  }
}

const CI_LABEL = { pass: "passing", fail: "failing", pending: "running", none: "no checks", skip: "skipped", cancel: "cancelled" };
const MERGE_LABEL = { draft: "draft", conflict: "conflicts", unknown: "checking", behind: "behind", blocked: "blocked", unstable: "unstable", clean: "ready" };
const REVIEW_LABEL = { APPROVED: "approved", CHANGES_REQUESTED: "changes requested", REVIEW_REQUIRED: "review required" };

export const ciLabel = (s) => CI_LABEL[s] ?? s;
export const mergeLabel = (s) => MERGE_LABEL[s] ?? s;
export const reviewLabel = (s) => REVIEW_LABEL[s] ?? null;

// A running state pulses rather than spins: it costs nothing while hidden.
export function dot(state, t, size = 8) {
  const d = div().w(size).h(size).flex_none().rounded(size).bg(stateColor(state, t));
  return state === "pending" ? d.loop("opacity", { from: 0.35, to: 1, period: 1200 }) : d;
}

export function badge(text, color, t) {
  return div().flex_none().px(6).h(18).flex().items_center().rounded(4).border_1().border_color(alpha(color, "66")).text_color(color).text_size(10).child(text);
}

// A button that stops its press, so it works inside a draggable window and
// doesn't also fire the row's click beneath it.
export function button(id, label, t, onClick, { primary = false, danger = false, disabled = false, armed = false } = {}) {
  const fg = disabled ? t.dim : armed || danger ? t.ansi1 : primary ? t.solid_foreground : t.foreground;
  const bg = disabled ? t.raised : armed ? alpha(t.ansi1, "22") : primary ? t.solid : t.raised;
  return div().id(id).flex_none().h(22).px(8).flex().items_center().rounded(5).text_size(11).text_color(fg).bg(bg)
    .border_1().border_color(armed ? t.ansi1 : t.border)
    .when(!disabled, (e) => e.cursor_pointer().hover((s) => s.border_color(t.accent)))
    .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
    .on_click((e, cx) => { cx.stop_propagation(); if (!disabled) onClick(e, cx); })
    .child(label);
}

