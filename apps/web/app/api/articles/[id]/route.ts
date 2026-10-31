// Proxy polling artikel: 200 = jadi, 404 = masih diproses.
import { NextRequest, NextResponse } from "next/server";

const API_BASE = process.env.API_BASE_URL ?? "http://localhost:4301";

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const res = await fetch(
    `${API_BASE}/v1/articles/${encodeURIComponent(id)}`,
    { cache: "no-store" },
  );
  if (res.status === 404) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }
  const body = await res.json().catch(() => ({}));
  return NextResponse.json(body, { status: res.status });
}
