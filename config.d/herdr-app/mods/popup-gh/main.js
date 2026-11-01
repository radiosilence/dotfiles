// Shows the gh-board: selects its tab if one is open, else makes a "GitHub"
// space in the home folder with the board as its only tab.
// Bound with `mod.open:popup-gh` in keys.json.

import { View, div } from "gpui-kit";
import { closeOverlay, exec, home, notify, props, run, shared, spaces } from "herdr";

async function herdr(args) {
  const r = await exec("herdr-app", ["do", ...args]);
  let out = null;
  try { out = JSON.parse(r.stdout || "{}"); } catch { out = null; }
  if (r.code !== 0 || !out || out.error) throw new Error(out?.error || r.stderr.trim() || r.stdout.trim() || `herdr-app do ${args[0]} failed`);
  return out;
}

export default class PopupGh extends View {
  init(_props, cx) {
    const self = props()?.overlay;
    const tab = shared("gh-board.boardTab");
    const space = tab && spaces().find((s) => s.tabs.some((t) => t.id === tab));
    if (space) {
      if (self) closeOverlay(self);
      run("space.select", { id: space.id });
      run("tab.select", { id: tab });
      return;
    }
    cx.spawn(async () => {
      let made = null, board = null;
      try {
        // space.new always starts a terminal; the board replaces its tab.
        made = await herdr(["space.new", "--name", "GitHub", "--folder", home()]);
        board = await herdr(["tab.new", "--space", made.space, "--name", "Board", "--mod", "gh-board"]);
        await herdr(["tab.close", "--id", made.tab, "--confirmed", "true"]);
      } catch (e) {
        // Without a board the space is only a stray shell; with one, a leftover tab is harmless.
        if (made?.space && !board) await herdr(["space.close", "--id", made.space, "--confirmed", "true"]).catch(() => {});
        notify({ title: "gh-board", body: String(e?.message ?? e), level: "error" });
      } finally {
        if (self) closeOverlay(self);
      }
    });
  }

  render() {
    return div();
  }
}
