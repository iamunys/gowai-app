# Gowai — Supabase server-side setup

Why this exists: the app previously shipped `.env` (Anthropic + Google API
keys) inside the app bundle, and wrote its own `is_pro` flag from the client.
Anyone unzipping the APK/IPA gets the keys; any patched client can grant
itself Pro. The two Edge Functions here fix both. The Flutter client already
prefers the Edge Function and falls back to the legacy direct call, so you
can deploy these at your own pace — nothing breaks before or after.

## 0. One-time CLI setup

```sh
brew install supabase/tap/supabase    # macOS
supabase login                        # opens browser
supabase link --project-ref <YOUR_PROJECT_REF>   # from the dashboard URL
```

## 1. Claude proxy (`generate-itinerary`)

```sh
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...   # use a NEW key, see §4
# optional: supabase secrets set CLAUDE_MODEL=claude-haiku-4-5-20251001
supabase functions deploy generate-itinerary
```

Verify from the app (debug build): generate a trip and check the logs — you
should NOT see `[Claude] edge function unavailable`. You can also watch
function logs live: `supabase functions logs generate-itinerary --tail`.

JWT verification stays ON for this function (default) — only signed-in app
users can invoke it.

## 2. RevenueCat webhook (`revenuecat-webhook`)

```sh
# generate a long random secret, e.g.:  openssl rand -hex 32
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<random>
supabase functions deploy revenuecat-webhook --no-verify-jwt
```

Then in the RevenueCat dashboard → Project → Integrations → Webhooks:

- URL: `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/revenuecat-webhook`
- Authorization header value: `Bearer <random>` (the same secret)

Verify with a sandbox purchase: `profiles.is_pro` should flip to `true`
without the app touching it (check function logs + the table).

## 3. Lock down `profiles` (only after §2 is verified)

`supabase/sql/harden_profiles.sql` revokes client UPDATE on everything except
`full_name`. **Order matters** — read the warning at the top of that file.
The short version:

1. Webhook live + verified (§2).
2. Remove the client-side `setProStatus` calls and
   `_updateSupabaseProStatus` (paywall_screen.dart,
   legal/subscription_screen.dart, revenuecat_service.dart) — ask Claude for
   the "post-webhook cleanup" pass.
3. Run the SQL in the Supabase SQL editor.
4. Confirm `increment_trips_used()` is SECURITY DEFINER (query in the SQL
   file), or the free-trip counter breaks.

## 4. Key rotation (IMPORTANT)

Every binary shipped so far contains the old keys. After §1 works:

1. **Anthropic**: create a new key in the Anthropic console, set it as the
   Supabase secret, then **disable the old key**. Remove `ANTHROPIC_API_KEY`
   from `.env`. (The client fallback then becomes dead code — ask Claude for
   the cleanup pass to delete `_generateDirect` from claude_service.dart.)
2. **Google Places/Directions**: these are still called from the client (a
   proxy for them is a possible follow-up — note the Places photo URLs even
   embed the key in rows saved to the `trips` table). Until then, in Google
   Cloud Console: restrict each key to only the APIs it needs and set daily
   quota caps so a leaked key has bounded blast radius.
3. **Supabase anon key + RevenueCat public SDK keys**: designed to be public,
   no rotation needed.

## File map

| File | Purpose |
|---|---|
| `functions/generate-itinerary/index.ts` | Claude proxy (JWT-verified) |
| `functions/revenuecat-webhook/index.ts` | RevenueCat → `is_pro` (secret-authed) |
| `sql/harden_profiles.sql` | Column-level lockdown — apply LAST |
