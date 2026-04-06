// population-models: Returns latest server-trained ML model weights
// for cold-start and population priors.
//
// GET /functions/v1/population-models?mode=focus&model_type=markov_transitions
// Both parameters are optional — omit for all models.
// Returns: { models: [{ model_type, mode, parameters, version, training_session_count }] }

import {
  supabaseAdmin,
  supabaseForUser,
  getAuthHeader,
} from "../_shared/supabase-client.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

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
    const mode = url.searchParams.get("mode");
    const modelType = url.searchParams.get("model_type");

    let query = supabaseAdmin
      .from("ml_population_models")
      .select(
        "model_type, mode, parameters, version, training_session_count, training_user_count, trained_at, cross_validation_score"
      );

    if (mode) {
      // Include mode-specific models AND mode-agnostic models (mode IS NULL)
      query = query.or(`mode.eq.${mode},mode.is.null`);
    }

    if (modelType) {
      query = query.eq("model_type", modelType);
    }

    const { data: models, error } = await query;
    if (error) return errorResponse(error.message, 500);

    return jsonResponse({ models: models ?? [] });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
