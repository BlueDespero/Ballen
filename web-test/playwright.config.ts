import { defineConfig, devices } from "@playwright/test";

// Tests the web export in build/web (export it first; see CLAUDE.md, "Web tests").
const port = Number(process.env.PORT ?? 8137);
const baseURL = `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: "tests",
  // Each test loads the whole engine; a slow CI machine needs the room.
  timeout: 120_000,
  expect: { timeout: 30_000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  // Every test runs a whole engine; more at once starve each other.
  workers: 2,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : "list",
  use: {
    baseURL,
    trace: "retain-on-failure",
  },
  webServer: {
    command: "node serve.mjs",
    url: baseURL,
    env: { PORT: String(port) },
    // Never test another build that happens to be served on the port.
    reuseExistingServer: false,
  },
  projects: [
    {
      name: "desktop-chrome",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 720 } },
    },
    {
      name: "pixel-7-landscape",
      use: { ...devices["Pixel 7 landscape"], hasTouch: true },
    },
    {
      name: "iphone-15-landscape",
      use: { ...devices["iPhone 15 landscape"], hasTouch: true },
    },
    {
      name: "desktop-firefox",
      use: { ...devices["Desktop Firefox"], viewport: { width: 1280, height: 720 } },
    },
  ],
});
