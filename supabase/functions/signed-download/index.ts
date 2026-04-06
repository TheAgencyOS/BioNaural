// signed-download: Generates a signed URL for a specific stem pack archive.
//
// GET /functions/v1/signed-download?pack_id=TEXT
// Returns: { url: string, expires_at: string }

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

    const url = new URL(req.url);
    const packId = url.searchParams.get("pack_id");
    if (!packId) return errorResponse("Missing pack_id parameter");

    // Look up the pack's archive path
    const { data: pack, error: packError } = await supabaseAdmin
      .from("stem_packs")
      .select("archive_path, is_published")
      .eq("id", packId)
      .single();

    if (packError || !pack) return errorResponse("Pack not found", 404);
    if (!pack.is_published) return errorResponse("Pack not available", 403);

    // Generate signed URL
    const { data: signedUrl, error: signError } = await supabaseAdmin.storage
      .from("stem-packs")
      .createSignedUrl(pack.archive_path, SIGNED_URL_EXPIRY_SECONDS);

    if (signError || !signedUrl) {
      return errorResponse("Failed to generate download URL", 500);
    }

    // Increment download count
    await supabaseAdmin.rpc("increment_download_count", { pack_id: packId });

    const expiresAt = new Date(
      Date.now() + SIGNED_URL_EXPIRY_SECONDS * 1000
    ).toISOString();

    return jsonResponse({
      url: signedUrl.signedUrl,
      expires_at: expiresAt,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
