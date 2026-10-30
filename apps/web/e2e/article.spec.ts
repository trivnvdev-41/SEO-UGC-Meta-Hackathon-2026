import { expect, test, type Page } from "@playwright/test";

const ARTICLE = "/article/contoh-review";

function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));
  return errors;
}

// Embed pihak ketiga butuh jaringan; di CI/local tanpa akses TikTok script
// gagal load. Itu diabaikan, error dari kode sendiri tidak.
function ownErrors(errors: string[]): string[] {
  return errors.filter(
    (e) => !/(tiktok|instagram)\.com|net::ERR|Failed to load resource/i.test(e),
  );
}

test("artikel: H1, embed, JSON-LD valid, tanpa console error", async ({ page }) => {
  const errors = collectErrors(page);

  const res = await page.goto(ARTICLE);
  expect(res?.status()).toBe(200);

  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.locator("h1")).toContainText("Review Jujur Produk X");

  const embed = page.locator(
    "blockquote.tiktok-embed[data-video-id='123'], .article a[href*='tiktok.com']",
  );
  await expect(embed.first()).toBeVisible();

  const ld = await page.locator('script[type="application/ld+json"]').textContent();
  const parsed = JSON.parse(ld ?? "null");
  expect(parsed["@context"]).toBe("https://schema.org");
  expect(typeof parsed["@type"]).toBe("string");

  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    /\/article\/contoh-review$/,
  );
  await expect(page.locator('link[rel="alternate"][hrefLang="en"]')).toHaveCount(1);

  await page.screenshot({
    path: "e2e/__screenshots__/article-id.png",
    fullPage: true,
  });

  expect(ownErrors(errors)).toEqual([]);
});

test("switch bahasa: ?lang=en mengubah judul + canonical", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto(ARTICLE);

  await page.getByRole("link", { name: "EN", exact: true }).click();
  await expect(page).toHaveURL(/lang=en/);
  await expect(page.locator("h1")).toContainText("Honest Review of Product X");
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    /lang=en$/,
  );

  await page.screenshot({
    path: "e2e/__screenshots__/article-en.png",
    fullPage: true,
  });

  expect(ownErrors(errors)).toEqual([]);
});

test("halaman tidak ada → 404", async ({ page }) => {
  const res = await page.goto("/article/tidak-ada");
  expect(res?.status()).toBe(404);
});
