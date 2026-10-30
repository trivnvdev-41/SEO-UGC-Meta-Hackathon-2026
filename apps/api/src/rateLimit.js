// Rate limiter in-memory per key (IP). Cukup untuk single instance demo.
// shortcut: state hilang saat restart & tidak shared antar replica,
// ganti ke Redis (INCR+EXPIRE) kalau sudah multi-instance.
export function makeRateLimiter({ limit, windowMs = 60_000, now = Date.now }) {
  const hits = new Map();
  return (key) => {
    const t = now();
    const list = (hits.get(key) ?? []).filter((x) => t - x < windowMs);
    if (list.length >= limit) {
      hits.set(key, list);
      return false;
    }
    list.push(t);
    hits.set(key, list);
    return true;
  };
}
