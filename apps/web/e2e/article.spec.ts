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

// Tautan video asli selalu ada (tanpa embed pihak ketiga agar ringan);
// galeri foto hanya tampil jika artikel punya images.
function ownErrors(errors: string[]): string[] {
  return errors.filter(
    (e) => !/net::ERR|Failed to load resource/i.test(e),
  );
}

test("artikel: H1, foto/tautan sumber, JSON-LD valid, tanpa console error", async ({
  page,
}) => {
  const errors = collectErrors(page);

  const res = await page.goto(ARTICLE);
  expect(res?.status()).toBe(200);

  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.locator("h1")).toContainText("Review Jujur Produk X");

  const source = page.locator("a[href*='tiktok.com/@contoh/video/123']");
  await expect(source.first()).toBeVisible();
  await expect(source.first()).toContainText("Tonton video asli");

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

test("switch bahasa: /en/article/<id> mengubah judul, lang, canonical", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto(ARTICLE);

  await page.getByRole("link", { name: "EN", exact: true }).click();
  await expect(page).toHaveURL(/\/en\/article\/contoh-review$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.locator("h1")).toContainText("Honest Review of Product X");
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    /\/en\/article\/contoh-review$/,
  );
  await expect(page.locator('link[rel="alternate"][hrefLang="id"]')).toHaveCount(1);

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

test("URL lama ?lang=en diarahkan ke path /en", async ({ page }) => {
  await page.goto(`${ARTICLE}?lang=en`);
  await expect(page).toHaveURL(/\/en\/article\/contoh-review$/);
  await expect(page.locator("h1")).toContainText("Honest Review");
});

test("llms.txt dan sitemap mengekspos artikel + hreflang", async ({ request }) => {
  const llms = await request.get("/llms.txt");
  expect(llms.status()).toBe(200);
  expect(await llms.text()).toContain("/article/contoh-review");

  const sitemap = await request.get("/sitemap.xml");
  expect(sitemap.status()).toBe(200);
  const xml = await sitemap.text();
  expect(xml).toContain("xhtml:link");
  expect(xml).toContain("/en/article/contoh-review");
});
