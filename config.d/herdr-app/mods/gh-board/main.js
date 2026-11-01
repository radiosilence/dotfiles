// gh-board: GitHub for the repositories you add, inside Herdr. A pane shows
// either the board (default) or one item (props { view: "item" }).

import { View } from "gpui-kit";
import { props } from "herdr";
import { Board } from "./board.js";
import { Item } from "./item.js";

export default class GhBoard extends View {
  init(_props, cx) {
    this.view = props()?.view === "item" ? new Item() : new Board();
    this.view.init(cx);
  }

  render(cx) {
    return this.view.render(cx);
  }

  async close(cx) {
    await this.view.close?.(cx);
  }
}
