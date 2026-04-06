// ingest-session: Uploads session outcomes for ML training and
// updates anonymized aggregate_outcomes for cross-user learning.
//
// POST /functions/v1/ingest-session
// Body: { session: SessionOutcome }
// Returns: { ok: boolean }

import {
  supabaseAdmin,
  supabaseForUser,
  getAuthHeader,
} from "../_shared/supabase-client.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const MAX_SESSIONS_PER_DAY = 50;

/** Classify time of day into buckets for aggregate_outcomes. */
function timeOfDayBucket(hour: number): string {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 21) return "evening";
  return "night";
}

/** Classify energy into buckets for aggregate_outcomes. */
function energyBucket(energy: number | null): string {
  if (energy === null) return "medium";
  if (energy < 0.33) return "low";
  if (energy < 0.67) return "medium";
  return "high";
}

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

    // Get internal user_id
    const { data: userData } = await supabase
      .from("users")
      .select("id")
      .single();
    if (!userData) return errorResponse("User not found", 404);
    const userId = userData.id;

    const body = await req.json();
    const session = body.session;
    if (!session) return errorResponse("Missing session data");

    // Rate limit: max sessions per day
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const { count } = await supabase
      .from("sessions")
      .select("id", { count: "exact", head: true })
      .gte("created_at", todayStart.toISOString());

    if ((count ?? 0) >= MAX_SESSIONS_PER_DAY) {
      return errorResponse("Daily session upload limit reached", 429);
    }

    // Insert session (user_id is validated by RLS)
    const { error: insertError } = await supabase.from("sessions").insert({
      id: session.id,
      user_id: userId,
      mode: session.mode,
      start_date: session.start_date,
      end_date: session.end_date,
      duration_seconds: session.duration_seconds,
      hr_start: session.hr_start,
      hr_end: session.hr_end,
      hr_delta: session.hr_delta,
      hrv_start: session.hrv_start,
      hrv_end: session.hrv_end,
      hrv_delta: session.hrv_delta,
      average_heart_rate: session.average_heart_rate,
      average_hrv: session.average_hrv,
      time_to_calm_seconds: session.time_to_calm_seconds,
      time_to_sleep_seconds: session.time_to_sleep_seconds,
      adaptation_count: session.adaptation_count ?? 0,
      sustained_deep_state_minutes: session.sustained_deep_state_minutes ?? 0,
      entrainment_method: session.entrainment_method,
      beat_frequency_start: session.beat_frequency_start,
      beat_frequency_end: session.beat_frequency_end,
      carrier_frequency: session.carrier_frequency,
      ambient_bed_id: session.ambient_bed_id,
      melodic_layer_ids: session.melodic_layer_ids ?? [],
      stem_pack_id: session.stem_pack_id,
      was_completed: session.was_completed ?? false,
      thumbs_rating: session.thumbs_rating,
      feedback_tags: session.feedback_tags,
      check_in_mood: session.check_in_mood,
      check_in_goal: session.check_in_goal,
      check_in_skipped: session.check_in_skipped ?? false,
      biometric_success_score: session.biometric_success_score,
      overall_score: session.overall_score,
      time_of_day: session.time_of_day,
      day_of_week: session.day_of_week,
    });

    if (insertError) return errorResponse(insertError.message, 500);

    // Update anonymized aggregate_outcomes (service_role bypasses RLS)
    if (session.stem_pack_id && session.biometric_success_score != null) {
      const startDate = new Date(session.start_date);
      const todBucket = timeOfDayBucket(startDate.getHours());
      const enBucket = energyBucket(session.check_in_mood);

      // Upsert aggregate row
      const { data: existing } = await supabaseAdmin
        .from("aggregate_outcomes")
        .select("id, session_count, avg_biometric_score, avg_overall_score, avg_completion_rate, avg_duration_seconds, binaural_avg_score, binaural_session_count, isochronic_avg_score, isochronic_session_count")
        .eq("mode", session.mode)
        .eq("stem_pack_id", session.stem_pack_id)
        .eq("time_of_day_bucket", todBucket)
        .eq("energy_bucket", enBucket)
        .single();

      if (existing) {
        // Incremental average update
        const n = existing.session_count;
        const newCount = n + 1;
        const newAvgBio =
          (existing.avg_biometric_score * n + session.biometric_success_score) / newCount;
        const newAvgOverall = session.overall_score != null
          ? (((existing.avg_overall_score ?? 0) * n + session.overall_score) / newCount)
          : existing.avg_overall_score;
        const completedNum = session.was_completed ? 1 : 0;
        const newCompletionRate =
          (((existing.avg_completion_rate ?? 0) * n + completedNum) / newCount);
        const newAvgDuration =
          (((existing.avg_duration_seconds ?? 0) * n + session.duration_seconds) / newCount);

        // Entrainment method tracking
        const updates: Record<string, unknown> = {
          session_count: newCount,
          avg_biometric_score: newAvgBio,
          avg_overall_score: newAvgOverall,
          avg_completion_rate: newCompletionRate,
          avg_duration_seconds: newAvgDuration,
        };

        if (session.entrainment_method === "binaural") {
          const bc = existing.binaural_session_count ?? 0;
          updates.binaural_session_count = bc + 1;
          updates.binaural_avg_score =
            ((existing.binaural_avg_score ?? 0) * bc + session.biometric_success_score) / (bc + 1);
        } else if (session.entrainment_method === "isochronic") {
          const ic = existing.isochronic_session_count ?? 0;
          updates.isochronic_session_count = ic + 1;
          updates.isochronic_avg_score =
            ((existing.isochronic_avg_score ?? 0) * ic + session.biometric_success_score) / (ic + 1);
        }

        await supabaseAdmin
          .from("aggregate_outcomes")
          .update(updates)
          .eq("id", existing.id);
      } else {
        // Insert new aggregate row
        await supabaseAdmin.from("aggregate_outcomes").insert({
          mode: session.mode,
          stem_pack_id: session.stem_pack_id,
          time_of_day_bucket: todBucket,
          energy_bucket: enBucket,
          session_count: 1,
          avg_biometric_score: session.biometric_success_score,
          avg_overall_score: session.overall_score,
          avg_completion_rate: session.was_completed ? 1.0 : 0.0,
          avg_duration_seconds: session.duration_seconds,
          binaural_avg_score: session.entrainment_method === "binaural" ? session.biometric_success_score : null,
          binaural_session_count: session.entrainment_method === "binaural" ? 1 : 0,
          isochronic_avg_score: session.entrainment_method === "isochronic" ? session.biometric_success_score : null,
          isochronic_session_count: session.entrainment_method === "isochronic" ? 1 : 0,
        });
      }
    }

    return jsonResponse({ ok: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
