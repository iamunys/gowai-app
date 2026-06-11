-- Harden profiles: stop clients from writing their own is_pro / usage columns.
--
-- ⚠️ DO NOT run this until BOTH are true:
--   1. The revenuecat-webhook Edge Function is deployed, configured in the
--      RevenueCat dashboard, and verified (make a sandbox purchase and watch
--      is_pro flip server-side).
--   2. The Flutter client no longer calls setProStatus()/direct is_pro
--      updates (paywall_screen.dart, legal/subscription_screen.dart,
--      revenuecat_service.dart _updateSupabaseProStatus). Until those call
--      sites are removed, running this SQL makes purchases/restores show a
--      DB error to the user even though the webhook still grants Pro.
--
-- What it does: replaces the blanket UPDATE grant for signed-in users with a
-- column-scoped grant, so RLS still controls WHICH rows a user can update
-- (their own), while these grants control WHICH COLUMNS. After this, clients
-- can only update full_name; is_pro and trips_used_this_month become
-- server-only (service role key / SECURITY DEFINER functions bypass this).

REVOKE UPDATE ON TABLE public.profiles FROM authenticated;
GRANT UPDATE (full_name) ON TABLE public.profiles TO authenticated;

-- Note: the increment_trips_used() RPC keeps working IF it is declared
-- SECURITY DEFINER (it runs as its owner, not the caller). Verify with:
--   select prosecdef from pg_proc where proname = 'increment_trips_used';
-- If it returns false, recreate the function with SECURITY DEFINER before
-- applying this file, or the free-trip counter will break.
