// generation-webhook: Receives Replicate prediction completion webhooks.
// On success: triggers post-processing pipeline.
// On failure: marks job as failed.
//
// POST /functions/v1/generation-webhook
// Body: Replicate webhook payload

import { supabaseAdmin } from "../_shared/supabase-client.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const POST_PROCESSING_URL = Deno.env.get("POST_PROCESSING_SERVICE_URL");

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const body = await req.json();
    const predictionId: string = body.id;
    const status: string = body.status; // "succeeded" or "failed"
    const output = body.output; // URL(s) to generated audio

    if (!predictionId) return errorResponse("Missing prediction ID");

    // Find the generation job by Replicate prediction ID
    const { data: job, error: jobError } = await supabaseAdmin
      .from("generation_jobs")
      .select("id, mode, prompt, duration_seconds, target_bpm, target_key, target_scale, target_energy, target_brightness, target_warmth, user_id")
      .eq("replicate_prediction_id", predictionId)
      .single();

    if (jobError || !job) {
      return errorResponse(`No job found for prediction ${predictionId}`, 404);
    }

    if (status === "failed") {
      await supabaseAdmin
        .from("generation_jobs")
        .update({
          status: "failed",
          error_message: body.error ?? "Replicate prediction failed",
          completed_at: new Date().toISOString(),
        })
        .eq("id", job.id);

      return jsonResponse({ ok: true, action: "marked_failed" });
    }

    if (status !== "succeeded" || !output) {
      return jsonResponse({ ok: true, action: "ignored", status });
    }

    // Get the audio output URL from Replicate
    // Output format varies by model — could be a URL string or array of URLs
    const audioUrl = typeof output === "string"
      ? output
      : Array.isArray(output)
        ? output[0]
        : output.audio ?? output.url;

    if (!audioUrl) {
      await supabaseAdmin
        .from("generation_jobs")
        .update({
          status: "failed",
          error_message: "No audio URL in Replicate output",
          completed_at: new Date().toISOString(),
        })
        .eq("id", job.id);
      return errorResponse("No audio URL in output", 500);
    }

    // Update job status to post_processing
    await supabaseAdmin
      .from("generation_jobs")
      .update({
        status: "post_processing",
        replicate_output_url: audioUrl,
      })
      .eq("id", job.id);

    // Trigger post-processing pipeline
    if (POST_PROCESSING_URL) {
      try {
        const ppResponse = await fetch(POST_PROCESSING_URL + "/process", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            job_id: job.id,
            audio_url: audioUrl,
            mode: job.mode,
            prompt: job.prompt,
            duration_seconds: job.duration_seconds,
            target_bpm: job.target_bpm,
            target_key: job.target_key,
            target_scale: job.target_scale,
            target_energy: job.target_energy,
            target_brightness: job.target_brightness,
            target_warmth: job.target_warmth,
          }),
        });

        if (!ppResponse.ok) {
          const errText = await ppResponse.text();
          await supabaseAdmin
            .from("generation_jobs")
            .update({
              status: "failed",
              error_message: `Post-processing failed: ${errText}`,
              completed_at: new Date().toISOString(),
            })
            .eq("id", job.id);
        }
      } catch (ppErr) {
        await supabaseAdmin
          .from("generation_jobs")
          .update({
            status: "failed",
            error_message: `Post-processing service unreachable: ${ppErr}`,
            completed_at: new Date().toISOString(),
          })
          .eq("id", job.id);
      }
    } else {
      // No post-processing service configured — mark for manual processing
      await supabaseAdmin
        .from("generation_jobs")
        .update({
          status: "curating",
          error_message: "Post-processing service not configured. Manual processing required.",
        })
        .eq("id", job.id);
    }

    return jsonResponse({ ok: true, action: "post_processing_triggered" });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
