// Validasi URL konvertibel: harus http(s), panjang wajar.
export function isConvertibleUrl(url) {
  if (typeof url !== 'string') return false;
  const u = url.trim();
  if (u.length < 12 || u.length > 2048) return false;
  return /^https?:\/\/\S+$/i.test(u);
}
