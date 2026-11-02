import type { MetadataRoute } from "next";
import { SITE_URL } from "../lib/site";

const AI_BOTS = [
  "GPTBot", // OpenAI ChatGPT crawl
  "ChatGPT-User", // OpenAI ChatGPT user browsing
  "ClaudeBot", // Anthropic Claude crawl
  "Claude-Web", // Anthropic Claude web fetch
  "Google-Extended", // Google Gemini training/search
  "Bytespider", // DeepSeek/ByteDance
  "PerplexityBot", // Perplexity AI
];

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      { userAgent: "*", allow: "/" },
      ...AI_BOTS.map((userAgent) => ({ userAgent, allow: "/" })),
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  };
}
