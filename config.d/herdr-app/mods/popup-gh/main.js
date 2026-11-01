// Shows the gh-board: selects its tab if one is open, else makes a "GitHub"
// space in the home folder with the board as its only tab.
// Bound with `mod.open:popup-gh` in keys.json.

import { View, div } from "gpui-kit";
import { closeOverlay, exec, home, notify, props, run, shared, spaces } from "herdr";

async function herdr(args) {
  const r = await exec("herdr-app", ["do", ...args]);
  const out = JSON.parse(r.stdout || "{}");
  if (r.code !== 0 || out.error) throw new Error(out.error || r.stderr.trim() || `herdr-app do ${args[0]} failed`);
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
      try {
        // space.new always starts a terminal; the board replaces its tab.
        const made = await herdr(["space.new", "--name", "GitHub", "--folder", home()]);
        await herdr(["tab.new", "--space", made.space, "--name", "Board", "--mod", "gh-board"]);
        await herdr(["tab.close", "--id", made.tab, "--confirmed", "true"]);
      } catch (e) {
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
