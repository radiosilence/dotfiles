// Scratch shell. Runs in a hidden herdr-core terminal started in the focused
// pane's folder, shown as a dialog that closes when the command exits.
// Bound with `mod.open:popup-shell` in keys.json.

import { View, div } from "gpui-kit";
import { exec, focused, home, openOverlay, closeOverlay, props, notify } from "herdr";

const ARGV = ["zsh", "-i"];

export default class Popup extends View {
  init(_props, cx) {
    const self = props()?.overlay;
    const cwd = focused()?.cwd || home();
    cx.spawn(async () => {
      const r = await exec("hc", ["run", "--json", "--bg", "--rm", "--no-parent", "--cwd", cwd, "--", ...ARGV]);
      if (self) closeOverlay(self);
      if (r.code !== 0) {
        notify({ title: "popup-shell failed", body: r.stderr.trim() || r.stdout.trim(), level: "error" });
        return;
      }
      const { address } = JSON.parse(r.stdout);
      openOverlay({ kind: "dialog", modal: true, layout: { type: "block", content: { terminal: address } }, width: 0.8, height: 0.6 });
    });
  }

  render() {
    return div();
  }
}
