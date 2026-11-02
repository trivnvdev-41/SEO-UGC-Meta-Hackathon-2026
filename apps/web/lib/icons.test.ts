import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const DIR = join(__dirname, "..", "components", "icons");

const EXPECTED = [
  "Background",
  "Button",
  "Button2",
  "Button3",
  "ButtonBagikan",
  "ButtonKembali",
  "ButtonKomentar",
  "ButtonKurangSetuju",
  "ButtonKurangSetuju2",
  "ButtonKurangSetuju3",
  "ButtonMenuArtikel",
  "ButtonMenuOpsi",
  "ButtonNotifikasi",
  "ButtonSimpan",
  "Container",
  "Container2",
  "Container3",
  "Container4",
  "Container5",
  "Container6",
  "Container7",
  "Container8",
  "Container9",
  "Container10",
  "Container11",
  "Container12",
  "Container13",
  "Container14",
  "Container15",
  "Container16",
  "FrostedGlassNavigationBarOptimizedForMobileIosSafeBottom",
  "Margin",
  "Margin2",
];

describe("icons", () => {
  it("33 komponen SVG mockup terdaftar di barrel", () => {
    const src = readFileSync(join(DIR, "index.ts"), "utf8");
    for (const name of EXPECTED) {
      expect(src, name).toContain(`as ${name}`);
      expect(src, name).toContain(`./${name}`);
    }
  });

  it("tiap komponen punya default export + root <svg> + viewBox", () => {
    const files = readdirSync(DIR).filter(
      (f) => f.endsWith(".tsx") && f !== "index.tsx",
    );
    expect(files).toHaveLength(33);
    for (const f of files) {
      const src = readFileSync(join(DIR, f), "utf8");
      expect(src, f).toContain("export default");
      expect(src, f).toMatch(/<svg[^>]*viewBox="[^"]+"/);
      expect(src, f).toContain('height="1em"');
    }
  });
});
