// Escape `<` supaya output model tidak bisa breakout dari <script> JSON-LD.
export function escapeJsonLd(value: unknown): string {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}
