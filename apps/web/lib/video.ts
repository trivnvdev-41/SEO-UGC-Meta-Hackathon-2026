const YOUTUBE_ID = [
  /youtu\.be\/([\w-]{11})/,
  /youtube\.com\/(?:watch\?v=|shorts\/|embed\/)([\w-]{11})/,
];

export function youtubeId(url: string): string | null {
  for (const re of YOUTUBE_ID) {
    const m = url.match(re);
    if (m) return m[1];
  }
  return null;
}

/// Label sumber ala Zhihu: TikTok / YouTube / ''.
export function sourceLabel(url: string): string {
  const host = (() => {
    try {
      return new URL(url).hostname.toLowerCase();
    } catch {
      return "";
    }
  })();
  if (host.includes("tiktok.com")) return "TikTok";
  if (host.includes("youtube.com") || host.includes("youtu.be")) {
    return "YouTube";
  }
  return "";
}
