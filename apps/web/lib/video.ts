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

/// Label sumber: TikTok / YouTube / Instagram / Facebook / X, '' bila tak dikenal.
export function sourceLabel(url: string): string {
  return parseSocialUrl(url)?.label ?? "";
}

export interface SocialRef {
  platform: "youtube" | "tiktok" | "instagram" | "facebook" | "x";
  label: string;
  id: string | null;
}

/// Kenali platform sosmed + ekstrak id/slug bila polanya dikenal.
/// Tak dikenal -> null (dirender sebagai link biasa).
export function parseSocialUrl(url: string): SocialRef | null {
  let host = "";
  let path = "";
  try {
    const u = new URL(url);
    host = u.hostname.toLowerCase();
    path = u.pathname;
  } catch {
    return null;
  }
  const id = (m: RegExpMatchArray | null) => (m ? m[1] : null);
  if (host.includes("youtube.com") || host.includes("youtu.be")) {
    return { platform: "youtube", label: "YouTube", id: youtubeId(url) };
  }
  if (host.includes("tiktok.com")) {
    return {
      platform: "tiktok",
      label: "TikTok",
      id: id(path.match(/\/video\/(\d+)/)),
    };
  }
  if (host.includes("instagram.com")) {
    return {
      platform: "instagram",
      label: "Instagram",
      id: id(path.match(/\/(?:p|reel|reels)\/([\w-]+)/)),
    };
  }
  if (host.includes("facebook.com") || host.includes("fb.watch")) {
    return {
      platform: "facebook",
      label: "Facebook",
      id: id(path.match(/(?:reel|reels|videos|watch)[^\d?]*(\d+)/)) ??
        id(path.match(/\/share\/[vr]\/([\w-]+)/)),
    };
  }
  if (host.includes("x.com") || host.includes("twitter.com")) {
    return {
      platform: "x",
      label: "X",
      id: id(path.match(/\/status\/(\d+)/)),
    };
  }
  return null;
}
