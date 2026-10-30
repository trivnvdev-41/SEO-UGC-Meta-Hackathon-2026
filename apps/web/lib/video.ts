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
