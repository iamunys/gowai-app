// Supabase Edge Function: revenuecat-webhook
//
// Receives RevenueCat webhook events and updates profiles.is_pro
// server-side, so Pro status no longer depends on (or trusts) the client.
//
// Deploy with JWT verification OFF (RevenueCat can't send Supabase JWTs):
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
// Authentication is the shared secret you configure as the Authorization
// header value in the RevenueCat dashboard (Project → Integrations →
// Webhooks). Use the full value "Bearer <secret>" there.
//
// Secrets (set via `supabase secrets set`):
//   REVENUECAT_WEBHOOK_SECRET — required (generate a long random string)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import { createClient } from "npm:@supabase/supabase-js@2";

const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// Events that grant Pro. CANCELLATION is deliberately absent — a cancelled
// subscription stays active until EXPIRATION fires at period end, which is
// when access is actually revoked.
const PRO_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
  "NON_RENEWING_PURCHASE",
]);
const FREE_EVENTS = new Set(["EXPIRATION"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const auth = req.headers.get("authorization");
  if (auth !== `Bearer ${WEBHOOK_SECRET}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: { event?: { type?: string; app_user_id?: string } };
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const type = payload.event?.type ?? "";
  const userId = payload.event?.app_user_id;

  // The app calls Purchases.logIn(<supabase user id>) on sign-in, so
  // app_user_id is the profiles.id. Anonymous RevenueCat ids (purchases
  // made before login) can't be mapped — acknowledge so RevenueCat doesn't
  // retry forever; the client-side restore flow covers those users.
  if (!userId || userId.startsWith("$RCAnonymousID")) {
    return new Response("ok (no mappable user)", { status: 200 });
  }

  let isPro: boolean | null = null;
  if (PRO_EVENTS.has(type)) isPro = true;
  if (FREE_EVENTS.has(type)) isPro = false;
  if (isPro === null) {
    // TEST, TRANSFER, BILLING_ISSUE etc. — nothing to change.
    return new Response("ok (event ignored)", { status: 200 });
  }

  const { error } = await supabase
    .from("profiles")
    .update({ is_pro: isPro })
    .eq("id", userId);

  if (error) {
    console.error("profiles update failed", error.message);
    // Non-2xx so RevenueCat retries the delivery.
    return new Response("DB error", { status: 500 });
  }

  console.log(`is_pro=${isPro} set for ${userId} (${type})`);
  return new Response("ok", { status: 200 });
});
