// Shared Supabase client for Edge Functions.
// Uses service_role key for server-side operations that bypass RLS.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

/** Service-role client — bypasses RLS. Use for server-side writes to
 *  stem_packs, ml_population_models, aggregate_outcomes, generation_jobs. */
export const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

/** Creates an authenticated client scoped to the requesting user.
 *  Respects RLS policies — use for user-facing data. */
export function supabaseForUser(authHeader: string) {
  return createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
}

/** Extract and validate the Authorization header from a request. */
export function getAuthHeader(req: Request): string {
  const auth = req.headers.get("Authorization");
  if (!auth) throw new Error("Missing Authorization header");
  return auth;
}
