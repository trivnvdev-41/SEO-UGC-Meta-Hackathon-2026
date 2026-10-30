import { defineConfig, devices } from "@playwright/test";

const WEB_PORT = Number(process.env.WEB_PORT ?? 4320);
const API_PORT = Number(process.env.API_PORT ?? 4301);

export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  reporter: [["list"]],
  use: {
    baseURL: `http://localhost:${WEB_PORT}`,
    screenshot: "only-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: [
    {
      command: "node --env-file=../../.env src/server.js",
      cwd: "../api",
      url: `http://localhost:${API_PORT}/v1/articles`,
      reuseExistingServer: true,
      timeout: 60_000,
      env: { PORT: String(API_PORT) },
    },
    {
      command: `npx next dev -p ${WEB_PORT}`,
      url: `http://localhost:${WEB_PORT}/robots.txt`,
      reuseExistingServer: true,
      timeout: 120_000,
      env: { API_BASE_URL: `http://localhost:${API_PORT}` },
    },
  ],
});
