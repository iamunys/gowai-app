// Supabase Edge Function: generate-itinerary
//
// Proxies the Claude itinerary generation server-side so the Anthropic API
// key never ships inside the app bundle. The client keeps parsing the
// returned text with its existing JsonParser, so response shape is
// unchanged.
//
// Auth: deployed with JWT verification ON (the default), so the Supabase
// gateway rejects calls without a valid signed-in user token before this
// code runs. That same user JWT is forwarded to PostgREST below to look up
// the caller's own profile under RLS.
//
// Model selection: free users get Haiku with a shorter prompt/response;
// Pro users get Sonnet with a richer prompt. Pro status is read from the
// profiles table server-side — the `is_pro` field in the request body is
// only a hint and is never trusted directly.
//
// Secrets (set via `supabase secrets set`):
//   ANTHROPIC_API_KEY  — required
//   CLAUDE_MODEL       — optional override for the free-tier model
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically in
// the Edge Function runtime — no need to set them as secrets.

import Anthropic from "npm:@anthropic-ai/sdk";

const FREE_MODEL = Deno.env.get("CLAUDE_MODEL") ?? "claude-haiku-4-5-20251001";
const PRO_MODEL = "claude-sonnet-4-6";

const FREE_MAX_TOKENS = 1200;
const PRO_MAX_TOKENS = 2000;

const BASE_PROMPT = `
You are Gowai, an expert travel planner AI specializing in Indian destinations.

Based on the user's preferences, generate a detailed full-day trip itinerary.

You MUST respond ONLY with a valid JSON array. No explanation, no markdown, no preamble.
Just the raw JSON array starting with [ and ending with ].

Each item in the array must have exactly these fields:
{
  "stop_number": 1,
  "name": "Place name as it appears on Google Maps",
  "search_query": "Place name + city + state + India, for an accurate Google Places search",
  "city": "City or town the place is in",
  "state": "State the place is in",
  "time": "6:30 AM",
  "duration_minutes": 45,
  "category": "viewpoint" | "waterfall" | "trekking" | "food" | "culture" | "estate" | "beach" | "market" | "temple",
  "description": "2-3 sentence description of the place and why to visit",
  "tip": "One practical insider tip for the visitor",
  "entry_fee_inr": 20,
  "best_for": "what kind of traveler this stop is best for",
  "approximate_lat": 12.4158,
  "approximate_lng": 75.6877
}

Rules:
- Time the stops realistically from morning to evening
- Keep total estimated spend within the user's stated budget
- Use real place names that exist on Google Maps
- search_query must include the place name, city, state, and "India" for an
  accurate Places search — e.g. "Abbey Falls Coorg Karnataka India"
- approximate_lat and approximate_lng must be the place's real coordinates
  (never 0.0), used as a fallback if the Places lookup fails
- Tailor stops to the user's vibe (nature, culture, food, etc.) and group type
- For solo travelers, prefer safe and accessible locations
`;

const PRO_ADDENDUM = `
PRO USER — deliver premium quality:
- Generate exactly 6 well-spaced stops
- Descriptions: 3-4 sentences with rich cultural and historical context
- Tips: specific insider knowledge that most tourists don't know
- Include exact opening hours if known
- Consider travel time between stops
- Add a "why_visit" field: one compelling reason specific to this place
- Suggest the best time of day for photos
- Include a local food recommendation near each stop
`;

const FREE_ADDENDUM = `
FREE USER — deliver solid quality:
- Generate exactly 5 stops
- Descriptions: 2 clear sentences
- Tips: practical and useful
- Focus on the most popular and accessible locations
`;

function getSystemPrompt(isPro: boolean): string {
  return BASE_PROMPT + (isPro ? PRO_ADDENDUM : FREE_ADDENDUM);
}

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

  // Verify pro status server-side from the profiles table — the `is_pro`
  // field on `body` is only a client hint and is never trusted directly.
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();

  let isPro = false;
  try {
    if (token) {
      const profileRes = await fetch(
        `${supabaseUrl}/rest/v1/profiles?select=is_pro&limit=1`,
        {
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${token}`,
          },
        },
      );
      const profiles = await profileRes.json();
      isPro = profiles?.[0]?.is_pro === true;
    }
  } catch (e) {
    console.error("Pro check failed, defaulting to free:", e);
    isPro = false;
  }

  const model = isPro ? PRO_MODEL : FREE_MODEL;
  const maxTokens = isPro ? PRO_MAX_TOKENS : FREE_MAX_TOKENS;
  console.log(`User isPro=${isPro}, model=${model}`);

  try {
    const message = await anthropic.messages.create({
      model,
      max_tokens: maxTokens,
      system: getSystemPrompt(isPro),
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
