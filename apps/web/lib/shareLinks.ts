// Builder link share ke semua sosmed (pure, ter-test).
// Dipakai ShareButton header + FeedActions; tanpa SDK pihak ketiga.
export interface ShareTarget {
  key: "wa" | "x" | "fb" | "tg" | "copy";
  label: string;
  href: string;
}

export function shareLinks(url: string, title: string): ShareTarget[] {
  const u = encodeURIComponent(url);
  const t = encodeURIComponent(title);
  return [
    {
      key: "wa",
      label: "WhatsApp",
      href: `https://wa.me/?text=${t}%20${u}`,
    },
    { key: "x", label: "X", href: `https://twitter.com/intent/tweet?text=${t}&url=${u}` },
    {
      key: "fb",
      label: "Facebook",
      href: `https://www.facebook.com/sharer/sharer.php?u=${u}`,
    },
    {
      key: "tg",
      label: "Telegram",
      href: `https://t.me/share/url?url=${u}&text=${t}`,
    },
    { key: "copy", label: "Salin link", href: url },
  ];
}
