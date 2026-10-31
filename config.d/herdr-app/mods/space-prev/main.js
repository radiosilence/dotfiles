// Selects the prev space in the order the spaces sidebar shows them: each
// worktree's space straight after its main checkout's. space.prev follows the
// order spaces were made in instead, which jumps around once worktrees are
// nested. Bound with `mod.open:space-prev` in keys.json.

import { View, div } from "gpui-kit";
import { spaces, panes, exec, run, props, closeOverlay } from "herdr";

const STEP = -1;

async function repoOf(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((t) => t.id));
  const cwd = ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
  try {
    const r = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir", "--show-toplevel"], { cwd, on: s.machine });
    if (r.code !== 0) return null;
    const [common, top] = r.stdout.trim().split("\n");
    return { repo: JSON.stringify([s.machine, common]), linked: common !== `${top}/.git` };
  } catch {
    return null;
  }
}

async function sidebarOrder() {
  const sp = spaces(), ps = panes();
  const list = await Promise.all(sp.map(async (s) => ({ s, g: await repoOf(s, ps) })));
  const mains = new Set(list.filter((r) => r.g && !r.g.linked).map((r) => r.g.repo));
  const nested = (r) => r.g?.linked && mains.has(r.g.repo);
  const out = [], placed = new Set();
  for (const r of list) {
    if (nested(r)) continue;
    out.push(r.s);
    if (!r.g || r.g.linked || placed.has(r.g.repo)) continue;
    placed.add(r.g.repo);
    out.push(...list.filter((k) => nested(k) && k.g.repo === r.g.repo).map((k) => k.s));
  }
  return out;
}

export default class SpaceStep extends View {
  init(_props, cx) {
    const self = props()?.overlay;
    cx.spawn(async () => {
      const order = await sidebarOrder();
      if (self) closeOverlay(self);
      const at = order.findIndex((s) => s.active);
      if (order.length < 2 || at < 0) return;
      run("space.select", { id: order[(at + STEP + order.length) % order.length].id });
    });
  }

  render() {
    return div();
  }
}
