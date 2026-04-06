// job-status: Poll generation job status.
//
// GET /functions/v1/job-status?job_id=UUID
// Returns: { status, pack_id?, download_url?, error?, created_at, started_at, completed_at }

import {
  supabaseAdmin,
  supabaseForUser,
  getAuthHeader,
} from "../_shared/supabase-client.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const SIGNED_URL_EXPIRY_SECONDS = 3600;

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
    const jobId = url.searchParams.get("job_id");
    if (!jobId) return errorResponse("Missing job_id parameter");

    // RLS ensures users can only see their own jobs
    const { data: job, error: jobError } = await supabase
      .from("generation_jobs")
      .select(
        "id, status, result_pack_id, error_message, created_at, started_at, completed_at"
      )
      .eq("id", jobId)
      .single();

    if (jobError || !job) return errorResponse("Job not found", 404);

    let downloadUrl: string | null = null;

    // If completed, generate a signed download URL for the result pack
    if (job.status === "completed" && job.result_pack_id) {
      const { data: pack } = await supabaseAdmin
        .from("stem_packs")
        .select("archive_path")
        .eq("id", job.result_pack_id)
        .single();

      if (pack) {
        const { data: signedUrl } = await supabaseAdmin.storage
          .from("stem-packs")
          .createSignedUrl(pack.archive_path, SIGNED_URL_EXPIRY_SECONDS);
        downloadUrl = signedUrl?.signedUrl ?? null;
      }
    }

    return jsonResponse({
      status: job.status,
      pack_id: job.result_pack_id,
      download_url: downloadUrl,
      error: job.error_message,
      created_at: job.created_at,
      started_at: job.started_at,
      completed_at: job.completed_at,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
