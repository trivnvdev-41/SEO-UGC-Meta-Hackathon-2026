// URL konvertibel: https + host harus TikTok/Instagram (whitelist, bukan blacklist).
// Ini sekaligus menutup SSRF: host internal/IP literal tidak mungkin lolos.
const ALLOWED_HOST = /(^|\.)(tiktok\.com|instagram\.com)$/i;

export function isConvertibleUrl(url) {
  if (typeof url !== 'string') return false;
  const raw = url.trim();
  if (raw.length < 12 || raw.length > 2048) return false;
  let u;
  try {
    u = new URL(raw);
  } catch {
    return false;
  }
  if (u.protocol !== 'https:') return false;
  if (u.username || u.password) return false;
  return ALLOWED_HOST.test(u.hostname);
}
