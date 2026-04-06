// content-catalog: Returns available stem packs filtered by mode,
// excludes already-installed packs, returns signed download URLs.
//
// POST /functions/v1/content-catalog
// Body: { mode?: string, installed_pack_ids: string[], include_variation_sets?: boolean }
// Returns: { packs: [...], variation_sets: [...] }

import {
  supabaseAdmin,
  supabaseForUser,
  getAuthHeader,
} from "../_shared/supabase-client.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const SIGNED_URL_EXPIRY_SECONDS = 3600; // 1 hour

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const authHeader = getAuthHeader(req);
    const supabase = supabaseForUser(authHeader);

    // Verify authentication
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) return errorResponse("Unauthorized", 401);

    const body = await req.json();
    const mode: string | undefined = body.mode;
    const installedPackIds: string[] = body.installed_pack_ids ?? [];
    const includeVariationSets: boolean = body.include_variation_sets ?? true;

    // Query published stem packs
    let query = supabaseAdmin
      .from("stem_packs")
      .select(
        "id, name, mode, energy, brightness, warmth, density, tempo, key, scale, " +
        "variation_set_id, variation_order, archive_path, archive_size_bytes, " +
        "duration_seconds, quality_score"
      )
      .eq("is_published", true);

    if (mode) {
      query = query.eq("mode", mode);
    }

    // Exclude already-installed packs
    if (installedPackIds.length > 0) {
      query = query.not("id", "in", `(${installedPackIds.join(",")})`);
    }

    query = query.order("quality_score", { ascending: false, nullsFirst: false });

    const { data: packs, error: packsError } = await query;
    if (packsError) return errorResponse(packsError.message, 500);

    // Generate signed download URLs for each pack
    const packsWithUrls = await Promise.all(
      (packs ?? []).map(async (pack) => {
        const { data: signedUrl } = await supabaseAdmin.storage
          .from("stem-packs")
          .createSignedUrl(pack.archive_path, SIGNED_URL_EXPIRY_SECONDS);

        return {
          ...pack,
          download_url: signedUrl?.signedUrl ?? null,
        };
      })
    );

    // Optionally include variation sets
    let variationSets: unknown[] = [];
    if (includeVariationSets) {
      let vsQuery = supabaseAdmin
        .from("variation_sets")
        .select("id, name, mode, key, tempo_min, tempo_max, pack_count, crossfade_interval_seconds")
        .eq("is_published", true);

      if (mode) {
        vsQuery = vsQuery.eq("mode", mode);
      }

      const { data: sets } = await vsQuery;
      variationSets = sets ?? [];
    }

    // Increment download counts for packs that will be downloaded
    // (actual increment happens in signed-download, but we track catalog views)

    return jsonResponse({
      packs: packsWithUrls,
      variation_sets: variationSets,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
