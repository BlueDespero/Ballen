import { expect, type Page, type TestInfo } from "@playwright/test";

// Drives the web export through its canvas. The game prints `[ballen] …`
// marker lines to the console in web builds (gui/web_markers.gd); tests wait
// for them. Coordinates are the 1280×720 layout in the run-ballen skill.

export const BASE = { width: 1280, height: 720 };

// Known spots at 1280×720 (see .claude/skills/run-ballen/SKILL.md, "Layout").
// The web build hides Quit, so its main menu buttons sit 24 px lower than on
// desktop.
export const SPOT = {
  singlePlayer: { x: 640, y: 369 },
  decks: { x: 640, y: 417 },
  setupRuleR08: { x: 368, y: 528 },
  start: { x: 461, y: 648 },
  pickRed: { x: 624, y: 660 },
  playerBall: { x: 440, y: 660 },
  newDeck: { x: 1035, y: 640 },
  deckName: { x: 650, y: 58 },
  save: { x: 1113, y: 660 },
};

// The centre of board cell (x, y).
export function cell(x: number, y: number): { x: number; y: number } {
  return { x: 240 + 80 * x, y: 160 + 80 * y };
}

// The rule row Rnn in the deck editor with All shown (R01 to R09 are visible).
export function editorRule(n: number): { x: number; y: number } {
  return { x: 600, y: 172 + 54 * (n - 1) };
}

// Playwright's WebKit reports this WebGL validation error every frame from
// Godot's own final blit (the Compatibility renderer); the game still draws
// correctly. Not seen in Chromium. Check on a real iPhone before release.
const WEBKIT_KNOWN_ERROR = /glBlitFramebuffer: Read and write color attachments cannot be the same image/;

export class Game {
  readonly markers: string[] = [];
  readonly errors: string[] = [];
  private readonly touch: boolean;

  constructor(readonly page: Page, testInfo: TestInfo) {
    this.touch = !!testInfo.project.use.hasTouch;
    const webkit = testInfo.project.use.defaultBrowserType === "webkit";
    page.on("console", (message) => {
      const text = message.text();
      if (text.startsWith("[ballen]")) this.markers.push(text);
      if (message.type() === "error" && !(webkit && WEBKIT_KNOWN_ERROR.test(text))) this.errors.push(text);
    });
    page.on("pageerror", (error) => this.errors.push(String(error)));
  }

  // Opens the game and waits for the main menu.
  async open(): Promise<void> {
    this.markers.length = 0;
    await this.page.goto("/");
    // The engine download and start take a while on a busy machine.
    await this.waitFor("[ballen] scene=Main", 0, 60_000);
  }

  // Waits for a marker line that equals `marker` (or starts with it plus a
  // space) or matches the pattern, printed after the first `since` markers.
  async waitFor(marker: string | RegExp, since = 0, timeout = 30_000): Promise<string> {
    const matches = (line: string): boolean =>
      typeof marker === "string" ? line === marker || line.startsWith(marker + " ") : marker.test(line);
    let found = "";
    await expect
      .poll(
        () => {
          found = this.markers.slice(since).find(matches) ?? "";
          return found;
        },
        { message: `console marker ${marker}`, timeout },
      )
      .not.toBe("");
    return found;
  }

  // Whether such a marker shows up in time, without failing the test.
  async seen(marker: string | RegExp, since = 0, timeout = 5_000): Promise<boolean> {
    try {
      await this.waitFor(marker, since, timeout);
      return true;
    } catch {
      return false;
    }
  }

  // A 1280×720 layout point in page pixels. The game scales the layout to fit
  // the canvas and centres it (stretch canvas_items, aspect expand).
  async toPage(point: { x: number; y: number }): Promise<{ x: number; y: number }> {
    const box = await this.page.locator("canvas").boundingBox();
    if (box === null) throw new Error("no canvas");
    const scale = Math.min(box.width / BASE.width, box.height / BASE.height);
    return {
      x: box.x + (box.width - BASE.width * scale) / 2 + point.x * scale,
      y: box.y + (box.height - BASE.height * scale) / 2 + point.y * scale,
    };
  }

  // A tap on touch projects, a click otherwise.
  async click(point: { x: number; y: number }): Promise<void> {
    const at = await this.toPage(point);
    if (this.touch) await this.page.touchscreen.tap(at.x, at.y);
    else await this.page.mouse.click(at.x, at.y);
  }

  // Drags with the mouse, or with a finger on touch projects.
  async drag(from: { x: number; y: number }, to: { x: number; y: number }): Promise<void> {
    const a = await this.toPage(from);
    const b = await this.toPage(to);
    const steps = 12;
    const points = Array.from({ length: steps + 1 }, (_, i) => ({
      x: a.x + ((b.x - a.x) * i) / steps,
      y: a.y + ((b.y - a.y) * i) / steps,
    }));
    if (!this.touch) {
      await this.page.mouse.move(a.x, a.y);
      await this.page.mouse.down();
      for (const p of points) await this.page.mouse.move(p.x, p.y);
      await this.page.mouse.up();
    } else if (this.page.context().browser()?.browserType().name() === "chromium") {
      await this.cdpTouchDrag(points);
    } else {
      await this.syntheticTouchDrag(points);
    }
  }

  // A real touch drag through the Chrome DevTools Protocol.
  private async cdpTouchDrag(points: { x: number; y: number }[]): Promise<void> {
    const cdp = await this.page.context().newCDPSession(this.page);
    const first = points[0];
    await cdp.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: first.x, y: first.y }] });
    for (const p of points.slice(1)) {
      await this.page.waitForTimeout(16);
      await cdp.send("Input.dispatchTouchEvent", { type: "touchMove", touchPoints: [{ x: p.x, y: p.y }] });
    }
    await this.page.waitForTimeout(16);
    await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
    await cdp.detach();
  }

  // WebKit has no CDP: script-made TouchEvents on the canvas instead.
  private async syntheticTouchDrag(points: { x: number; y: number }[]): Promise<void> {
    const send = (type: string, p: { x: number; y: number }): Promise<void> =>
      this.page.evaluate(
        ({ type, x, y }) => {
          // WebKit forbids `new Touch()`, so the event carries plain touch
          // objects: Godot reads only identifier and clientX/Y.
          const canvas = document.querySelector("canvas") as HTMLCanvasElement;
          const touch = { identifier: 1, target: canvas, clientX: x, clientY: y, pageX: x, pageY: y, screenX: x, screenY: y };
          const active = type === "touchend" ? [] : [touch];
          const event = new Event(type, { bubbles: true, cancelable: true });
          Object.defineProperties(event, {
            touches: { value: active },
            targetTouches: { value: active },
            changedTouches: { value: [touch] },
          });
          canvas.dispatchEvent(event);
        },
        { type, x: p.x, y: p.y },
      );
    await send("touchstart", points[0]);
    for (const p of points.slice(1)) {
      await this.page.waitForTimeout(16);
      await send("touchmove", p);
    }
    await this.page.waitForTimeout(16);
    await send("touchend", points[points.length - 1]);
  }

  // Single Player, true rule R08 (any cell is legal for a first ball), Start;
  // returns whether the player goes first.
  async startMatch(): Promise<boolean> {
    const since = this.markers.length;
    await this.click(SPOT.singlePlayer);
    await this.waitFor("[ballen] scene=MainGame", since);
    await this.page.waitForTimeout(500);
    await this.click(SPOT.setupRuleR08);
    await this.page.waitForTimeout(200);
    await this.click(SPOT.start);
    const started = await this.waitFor("[ballen] match_started", since);
    return started.endsWith("first=player");
  }
}
