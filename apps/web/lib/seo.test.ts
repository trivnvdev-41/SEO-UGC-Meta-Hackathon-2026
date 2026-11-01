import { describe, expect, it } from "vitest";
import { escapeJsonLd } from "./jsonld";
import { videoObject } from "./structured";
import { sourceLabel, youtubeId } from "./video";
import { articlePath, articleUrl } from "./site";
import type { Article } from "./articles";

describe("escapeJsonLd", () => {
  it("tidak membiarkan </script> breakout", () => {
    const out = escapeJsonLd({ reviewBody: "</script><script>alert(1)</script>" });
    expect(out).not.toContain("</script>");
    expect(out).toContain("\\u003c/script>");
    expect(JSON.parse(out).reviewBody).toContain("</script>");
  });

  it("JSON biasa tetap utuh", () => {
    expect(escapeJsonLd({ "@type": "Product" })).toBe('{"@type":"Product"}');
  });
});

describe("youtubeId", () => {
  it("mengenali shorts, watch, youtu.be, embed", () => {
    expect(youtubeId("https://www.youtube.com/shorts/aBcD1234xyz")).toBe("aBcD1234xyz");
    expect(youtubeId("https://www.youtube.com/watch?v=aBcD1234xyz")).toBe("aBcD1234xyz");
    expect(youtubeId("https://youtu.be/aBcD1234xyz")).toBe("aBcD1234xyz");
    expect(youtubeId("https://www.youtube.com/embed/aBcD1234xyz")).toBe("aBcD1234xyz");
  });

  it("null untuk platform lain", () => {
    expect(youtubeId("https://www.tiktok.com/@a/video/1")).toBeNull();
    expect(youtubeId("https://www.youtube.com/@channel")).toBeNull();
  });
});

describe("sourceLabel", () => {
  it("melabeli TikTok/YouTube, kosong bila tak dikenal", () => {
    expect(sourceLabel("https://www.tiktok.com/@a/video/1")).toBe("TikTok");
    expect(sourceLabel("https://www.youtube.com/shorts/aBcD1234xyz")).toBe("YouTube");
    expect(sourceLabel("https://youtu.be/aBcD1234xyz")).toBe("YouTube");
    expect(sourceLabel("https://example.com/x")).toBe("");
    expect(sourceLabel("bukan-url")).toBe("");
  });
});

describe("videoObject", () => {
  const base = {
    id: "x",
    images: [],
    videoUrl: "https://www.youtube.com/shorts/aBcD1234xyz",
    id_body: { title: "T", meta: "M", body_md: "B" },
    en_body: { title: "T", meta: "M", body_md: "B" },
    json_ld: {},
    createdAt: "2026-10-30T00:00:00.000Z",
  } as Article;

  it("menghasilkan VideoObject untuk YouTube", () => {
    const out = videoObject(base, base.id_body);
    expect(out?.["@type"]).toBe("VideoObject");
    expect(out?.embedUrl).toContain("/embed/aBcD1234xyz");
    expect(out?.thumbnailUrl?.[0]).toContain("aBcD1234xyz");
    expect(out?.uploadDate).toBe("2026-10-30T00:00:00.000Z");
  });

  it("null untuk non-YouTube", () => {
    const tiktok = { ...base, videoUrl: "https://www.tiktok.com/@a/video/1" };
    expect(videoObject(tiktok, tiktok.id_body)).toBeNull();
  });
});

describe("articleUrl", () => {
  it("id default, en pakai path /en/article", () => {
    expect(articleUrl("abc", "id")).toMatch(/\/article\/abc$/);
    expect(articleUrl("abc", "en")).toMatch(/\/en\/article\/abc$/);
  });

  it("articlePath relatif (aman untuk href & redirect)", () => {
    expect(articlePath("abc", "id")).toBe("/article/abc");
    expect(articlePath("abc", "en")).toBe("/en/article/abc");
  });
});
