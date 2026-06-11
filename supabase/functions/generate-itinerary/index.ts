// Supabase Edge Function: generate-itinerary
//
// Proxies the Claude itinerary generation server-side so the Anthropic API
// key never ships inside the app bundle. The request body, system prompt,
// model and max_tokens mirror the Flutter client's previous direct call
// exactly — the client keeps parsing the returned text with its existing
// JsonParser, so behavior is unchanged.
//
// Auth: deployed with JWT verification ON (the default), so the Supabase
// gateway rejects calls without a valid signed-in user token before this
// code runs.
//
// Secrets (set via `supabase secrets set`):
//   ANTHROPIC_API_KEY  — required
//   CLAUDE_MODEL       — optional override; defaults to the model the app
//                        has been using in production

import Anthropic from "npm:@anthropic-ai/sdk";

const MODEL = Deno.env.get("CLAUDE_MODEL") ?? "claude-haiku-4-5-20251001";
const MAX_TOKENS = 2000;

// Keep byte-identical to the prompt previously embedded in the Flutter
// client (lib/core/services/claude_service.dart) so output quality and
// shape are unchanged.
const SYSTEM_PROMPT = `
You are Gowai, an expert travel planner AI specializing in Indian destinations.

Based on the user's preferences, generate a detailed full-day trip itinerary.

You MUST respond ONLY with a valid JSON array. No explanation, no markdown, no preamble.
Just the raw JSON array starting with [ and ending with ].

Each item in the array must have exactly these fields:
{
  "stop_number": 1,
  "name": "Place name as it appears on Google Maps",
  "time": "6:30 AM",
  "duration_minutes": 45,
  "category": "viewpoint" | "waterfall" | "trekking" | "food" | "culture" | "estate" | "beach" | "market" | "temple",
  "description": "2-3 sentence description of the place and why to visit",
  "tip": "One practical insider tip for the visitor",
  "entry_fee_inr": 20,
  "best_for": "what kind of traveler this stop is best for"
}

Rules:
- Generate exactly 5-7 stops for a full day
- Time the stops realistically from morning to evening
- Keep total estimated spend within the user's stated budget
- Use real place names that exist on Google Maps
- Tailor stops to the user's vibe (nature, culture, food, etc.) and group type
- For solo travelers, prefer safe and accessible locations
`;

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY")!,
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const destination = body.destination;
  if (typeof destination !== "string" || destination.trim() === "") {
    return json({ error: "destination is required" }, 400);
  }

  const field = (key: string) => (typeof body[key] === "string" ? body[key] : "");

  // Same field order/labels as the previous client-side userMessage.
  const userMessage = [
    `Destination: ${destination.trim()}`,
    `Travel date: ${field("date")}`,
    `Start time preference: ${field("startTime")}`,
    `Budget for the day: ${field("budget")}`,
    `Travel vibe: ${field("vibe")}`,
    `Group type: ${field("groupType")}`,
    `Interests: ${field("interests")}`,
    `Transport mode: ${field("transport")}`,
  ].join("\n");

  try {
    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
    });

    const text = message.content.find((b) => b.type === "text")?.text;
    if (!text) {
      console.error("Claude returned no text block", message.stop_reason);
      return json({ error: "Empty response from Claude" }, 502);
    }

    return json({ itinerary: text });
  } catch (err) {
    if (err instanceof Anthropic.APIError) {
      // Don't leak provider error bodies to the client; log server-side.
      console.error("Claude API error", err.status, err.message);
      return json({ error: `Claude API error ${err.status}` }, 502);
    }
    console.error("Unexpected error", err);
    return json({ error: "Internal error" }, 500);
  }
});
