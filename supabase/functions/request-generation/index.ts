// request-generation: Queue a personalized stem pack generation job
// via Replicate ACE-STEP 1.5. Premium users only, rate-limited.
//
// POST /functions/v1/request-generation
// Body: {
//   prompt: string,
//   mode: string,
//   duration_seconds?: number,
//   target_bpm?: number,
//   target_key?: string,
//   target_scale?: string,
//   target_energy?: number,
//   target_brightness?: number,
//   target_warmth?: number
// }
// Returns: { job_id: string, estimated_wait_seconds: number }

import {
  supabaseAdmin,
  supabaseForUser,
  getAuthHeader,
} from "../_shared/supabase-client.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const MAX_REQUESTS_PER_WEEK = 5;
const REPLICATE_API_TOKEN = Deno.env.get("REPLICATE_API_TOKEN");
const REPLICATE_ACE_STEP_MODEL =
  Deno.env.get("REPLICATE_ACE_STEP_MODEL") ??
  "anthropics/ace-step-1.5"; // Replace with actual model identifier
const WEBHOOK_URL = Deno.env.get("SUPABASE_URL") +
  "/functions/v1/generation-webhook";

const VALID_MODES = new Set(["focus", "relaxation", "sleep", "energize"]);

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

    // Get user record and verify premium
    const { data: userData } = await supabase
      .from("users")
      .select("id, subscription_tier")
      .single();
    if (!userData) return errorResponse("User not found", 404);
    if (userData.subscription_tier === "free") {
      return errorResponse("Premium subscription required for generation", 403);
    }

    const body = await req.json();
    const { prompt, mode } = body;

    if (!prompt || typeof prompt !== "string") {
      return errorResponse("Missing or invalid prompt");
    }
    if (!mode || !VALID_MODES.has(mode)) {
      return errorResponse("Invalid mode. Must be: focus, relaxation, sleep, energize");
    }

    const durationSeconds = body.duration_seconds ?? 60;
    if (durationSeconds < 15 || durationSeconds > 120) {
      return errorResponse("Duration must be between 15 and 120 seconds");
    }

    // Rate limit: max requests per week
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const { count: weeklyCount } = await supabase
      .from("generation_jobs")
      .select("id", { count: "exact", head: true })
      .gte("created_at", weekAgo);

    if ((weeklyCount ?? 0) >= MAX_REQUESTS_PER_WEEK) {
      return errorResponse(
        `Generation limit reached (${MAX_REQUESTS_PER_WEEK} per week)`,
        429
      );
    }

    // Insert generation job
    const { data: job, error: jobError } = await supabase
      .from("generation_jobs")
      .insert({
        user_id: userData.id,
        prompt,
        mode,
        duration_seconds: durationSeconds,
        target_bpm: body.target_bpm ?? null,
        target_key: body.target_key ?? null,
        target_scale: body.target_scale ?? null,
        target_energy: body.target_energy ?? null,
        target_brightness: body.target_brightness ?? null,
        target_warmth: body.target_warmth ?? null,
        status: "queued",
        priority: 1, // User-initiated jobs get higher priority
      })
      .select("id")
      .single();

    if (jobError || !job) return errorResponse("Failed to create job", 500);

    // Kick off Replicate prediction
    if (REPLICATE_API_TOKEN) {
      try {
        const replicateResponse = await fetch(
          "https://api.replicate.com/v1/predictions",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${REPLICATE_API_TOKEN}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: REPLICATE_ACE_STEP_MODEL,
              input: {
                prompt,
                duration: durationSeconds,
                // ACE-STEP specific parameters
                cfg_scale: 7.0,
                sample_rate: 44100,
                // Additional parameters based on mode
                ...(body.target_bpm ? { bpm: body.target_bpm } : {}),
              },
              webhook: WEBHOOK_URL,
              webhook_events_filter: ["completed", "failed"],
            }),
          }
        );

        if (replicateResponse.ok) {
          const prediction = await replicateResponse.json();

          // Update job with Replicate prediction ID
          await supabaseAdmin
            .from("generation_jobs")
            .update({
              replicate_prediction_id: prediction.id,
              status: "generating",
              started_at: new Date().toISOString(),
            })
            .eq("id", job.id);
        } else {
          const errText = await replicateResponse.text();
          await supabaseAdmin
            .from("generation_jobs")
            .update({
              status: "failed",
              error_message: `Replicate API error: ${errText}`,
            })
            .eq("id", job.id);

          return errorResponse("Failed to start generation", 502);
        }
      } catch (replicateErr) {
        await supabaseAdmin
          .from("generation_jobs")
          .update({
            status: "failed",
            error_message: `Replicate request failed: ${replicateErr}`,
          })
          .eq("id", job.id);

        return errorResponse("Generation service unavailable", 503);
      }
    }

    // Estimate wait time based on queue depth
    const { count: queueDepth } = await supabaseAdmin
      .from("generation_jobs")
      .select("id", { count: "exact", head: true })
      .in("status", ["queued", "generating"]);

    const estimatedWait = (queueDepth ?? 1) * 45; // ~45s per generation on Replicate

    return jsonResponse({
      job_id: job.id,
      estimated_wait_seconds: estimatedWait,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
