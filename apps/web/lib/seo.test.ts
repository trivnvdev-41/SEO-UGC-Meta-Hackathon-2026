import { describe, expect, it } from "vitest";
import robots from "../app/robots";
import { escapeJsonLd } from "./jsonld";
import { videoObject } from "./structured";
import { sourceLabel, youtubeId } from "./video";
import { brandOf, compactViews, formatDate, sortFeed, timeAgo, trendingOf, viewsOf } from "./articles";
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

describe("viewsOf/compactViews", () => {
  it("stabil dan ringkas", () => {
    expect(viewsOf("abc")).toBe(viewsOf("abc"));
    expect(compactViews(999)).toBe("999");
    expect(compactViews(1500)).toBe("1,5 rb");
    expect(compactViews(1100)).toBe("1,1 rb");
    expect(compactViews(25000)).toBe("25 rb");
  });
});

describe("formatDate", () => {
  it("ID dan EN, kosong bila tak valid", () => {
    expect(formatDate("2026-11-01T00:00:00.000Z", "id")).toBe("1 Nov 2026");
    expect(formatDate("2026-11-01T00:00:00.000Z", "en")).toBe("Nov 1, 2026");
    expect(formatDate(undefined, "id")).toBe("");
    expect(formatDate("asal", "id")).toBe("");
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

describe("robots", () => {
  it("mengizinkan 7 bot AI eksplisit + sitemap", () => {
    const r = robots();
    const agents = (Array.isArray(r.rules) ? r.rules : []).map(
      (x) => (x as { userAgent?: string }).userAgent,
    );
    for (const bot of [
      "GPTBot",
      "ChatGPT-User",
      "ClaudeBot",
      "Claude-Web",
      "Google-Extended",
      "Bytespider",
      "PerplexityBot",
    ]) {
      expect(agents).toContain(bot);
    }
    expect(r.sitemap).toMatch(/\/sitemap\.xml$/);
  });
});

describe("brandOf/scoreOf/sortFeed/trendingOf/timeAgo", () => {
  const mk = (id: string, score?: number, createdAt = ""): Article => ({
    id,
    images: [],
    videoUrl: "https://x/v",
    id_body: { title: "T", meta: "M", body_md: "B" },
    en_body: { title: "T", meta: "M", body_md: "B" },
    json_ld: { brand: { name: `Merek ${id}` } },
    createdAt,
    ...(score === undefined ? {} : { votes: { up: score, down: 0, score, myVote: 0 as const } }),
  });

  it("brandOf baca nama brand, '' bila tak ada", () => {
    expect(brandOf(mk("a"))).toBe("Merek a");
    expect(brandOf({ ...mk("b"), json_ld: {} })).toBe("");
  });

  it("populer urut skor desc, terbaru urut tanggal desc", () => {
    const list = [mk("x", 1, "2026-01-01"), mk("y", 9, "2026-01-02"), mk("z", 5, "2026-01-03")];
    expect(sortFeed(list, "populer").map((a) => a.id)).toEqual(["y", "z", "x"]);
    expect(sortFeed(list, "terbaru").map((a) => a.id)).toEqual(["z", "y", "x"]);
    expect(sortFeed(list, "untuk-anda").map((a) => a.id)).toEqual(["x", "y", "z"]);
  });

  it("trendingOf ambil 3 teratas", () => {
    const list = [mk("a", 2), mk("b", 7), mk("c", 5), mk("d", 9), mk("e", 1)];
    expect(trendingOf(list).map((a) => a.id)).toEqual(["d", "b", "c"]);
  });

  it("timeAgo relatif ID/EN", () => {
    const now = new Date("2026-11-02T12:00:00.000Z").getTime();
    expect(timeAgo("2026-11-02T11:59:30.000Z", "id", now)).toBe("baru saja");
    expect(timeAgo("2026-11-02T11:00:00.000Z", "id", now)).toBe("1 jam lalu");
    expect(timeAgo("2026-10-30T12:00:00.000Z", "en", now)).toBe("3d ago");
    expect(timeAgo("", "id", now)).toBe("");
    expect(timeAgo("asal", "id", now)).toBe("");
  });
});
