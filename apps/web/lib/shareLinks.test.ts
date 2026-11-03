import { describe, expect, it } from "vitest";
import { shareLinks } from "./shareLinks";

describe("shareLinks", () => {
  it("5 target dengan URL ter-encode", () => {
    const out = shareLinks("https://saba.ink/article/x", "Judul A&B");
    expect(out.map((t) => t.key)).toEqual(["wa", "x", "fb", "tg", "copy"]);
    const wa = out[0].href;
    expect(wa).toContain("wa.me");
    expect(wa).toContain(encodeURIComponent("https://saba.ink/article/x"));
    expect(out[1].href).toContain("twitter.com/intent/tweet");
    expect(out[2].href).toContain("facebook.com/sharer");
    expect(out[3].href).toContain("t.me/share/url");
    expect(out[4]).toMatchObject({ key: "copy", href: "https://saba.ink/article/x" });
  });
});
