// Proxy server-side ke API gateway: browser tidak kena CORS,
// API tetap tidak perlu membuka origin publik.
import { NextRequest, NextResponse } from "next/server";

const API_BASE = process.env.API_BASE_URL ?? "http://localhost:4301";

export async function POST(req: NextRequest) {
  let url: string;
  try {
    url = (await req.json()).url;
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  if (typeof url !== "string" || !url.trim()) {
    return NextResponse.json({ error: "invalid_url" }, { status: 400 });
  }
  const res = await fetch(`${API_BASE}/v1/convert`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ url: url.trim() }),
  });
  const body = await res.json().catch(() => ({}));
  return NextResponse.json(body, { status: res.status });
}
