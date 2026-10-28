import { expect, test } from "@playwright/test";
import { cell, editorRule, Game, SPOT } from "./game";

test("loads with WebGL2 on the main menu and no console errors", async ({ page }, testInfo) => {
  const game = new Game(page, testInfo);
  await game.open();
  const webgl2 = await page.evaluate(
    () => document.querySelector("canvas")?.getContext("webgl2") instanceof WebGL2RenderingContext,
  );
  expect(webgl2, "the game canvas renders with WebGL2").toBe(true);
  await page.waitForTimeout(1_000);
  expect(game.errors).toEqual([]);
});

test("starting a match from the setup screen", async ({ page }, testInfo) => {
  const game = new Game(page, testInfo);
  await game.open();
  await game.startMatch();
  expect(game.errors).toEqual([]);
});

test("placing a ball by dragging it onto the board", async ({ page }, testInfo) => {
  const game = new Game(page, testInfo);
  await game.open();
  const playerFirst = await game.startMatch();
  if (!playerFirst) {
    // Going second, the player picks the AI's first colour, then the AI places.
    const since = game.markers.length;
    await game.click(SPOT.pickRed);
    await game.waitFor("[ballen] ball_placed by=ai", since);
  }
  await page.waitForTimeout(500);
  // The AI may have taken a cell; with true rule R08 every free cell is legal.
  for (const target of [cell(2, 2), cell(3, 3), cell(1, 4)]) {
    const since = game.markers.length;
    await game.drag(SPOT.playerBall, target);
    if (await game.seen("[ballen] ball_placed by=player", since, 3_000)) break;
  }
  await game.waitFor("[ballen] ball_placed by=player");
  expect(game.errors).toEqual([]);
});

// The RotateHint autoload prints the marker in web builds.
test("a portrait screen shows the rotate hint", async ({ page }, testInfo) => {
  const game = new Game(page, testInfo);
  await page.setViewportSize({ width: 390, height: 844 });
  await game.open();
  await game.waitFor("[ballen] rotate_hint=shown");
});

test.describe("deck persistence", () => {
  // The Decks screen stretches with the screen; at 16:9 it matches the
  // run-ballen coordinates on every device.
  test.use({ viewport: { width: 1024, height: 576 } });

  test("a saved deck is still listed after a reload", async ({ page }, testInfo) => {
    const game = new Game(page, testInfo);
    await game.open();
    let since = game.markers.length;
    await game.click(SPOT.decks);
    await game.waitFor("[ballen] scene=Decks", since);
    await page.waitForTimeout(500);
    await game.click(SPOT.newDeck);
    await page.waitForTimeout(500);
    await game.click(SPOT.deckName);
    await page.waitForTimeout(200);
    await page.keyboard.type("Web deck");
    for (let n = 1; n <= 5; n++) {
      await game.click(editorRule(n));
      await page.waitForTimeout(100);
    }
    since = game.markers.length;
    await game.click(SPOT.save);
    await game.waitFor("[ballen] deck_saved name=Web deck", since);
    await game.waitFor("[ballen] decks=Starter,Web deck", since);
    // user:// reaches IndexedDB asynchronously after the file closes.
    await page.waitForTimeout(2_000);

    await page.reload();
    game.markers.length = 0;
    await game.waitFor("[ballen] scene=Main", 0, 60_000);
    since = game.markers.length;
    await game.click(SPOT.decks);
    await game.waitFor("[ballen] decks=Starter,Web deck", since);
    expect(game.errors).toEqual([]);
  });
});
