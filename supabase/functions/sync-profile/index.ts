// sync-profile: Bidirectional sync of sonic profile and ML model parameters.
// Conflict resolution: higher version number wins for ML params; later
// updated_at wins for sonic profile.
//
// POST /functions/v1/sync-profile
// Body: {
//   sonic_profile: { ...fields },
//   ml_parameters: [{ model_type, parameters, version }],
//   last_sync_at: ISO8601
// }
// Returns: {
//   sonic_profile?: { ...updated fields } | null,
//   ml_parameters?: [{ model_type, parameters, version }],
//   population_models?: [{ model_type, mode, parameters, version }]
// }

import {
  supabaseAdmin,
  supabaseForUser,
  getAuthHeader,
} from "../_shared/supabase-client.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

interface MLParam {
  model_type: string;
  parameters: Record<string, unknown>;
  version: number;
  training_session_count?: number;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const authHeader = getAuthHeader(req);
    const supabase = supabaseForUser(authHeader);

    // Verify authentication and get user
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
    const clientProfile = body.sonic_profile;
    const clientMLParams: MLParam[] = body.ml_parameters ?? [];
    const lastSyncAt: string | null = body.last_sync_at ?? null;

    // --- Sonic Profile Sync ---
    let profileResponse = null;

    if (clientProfile) {
      // Check existing server profile
      const { data: serverProfile } = await supabase
        .from("sonic_profiles")
        .select("*")
        .single();

      if (!serverProfile) {
        // No server profile — create from client
        const { error: insertError } = await supabase
          .from("sonic_profiles")
          .insert({
            user_id: userId,
            ...clientProfile,
          });
        if (insertError) return errorResponse(insertError.message, 500);
      } else {
        // Compare updated_at timestamps — latest wins
        const clientUpdatedAt = clientProfile.updated_at
          ? new Date(clientProfile.updated_at)
          : new Date(0);
        const serverUpdatedAt = new Date(serverProfile.updated_at);

        if (clientUpdatedAt > serverUpdatedAt) {
          // Client wins — update server
          const { updated_at: _, user_id: __, id: ___, ...profileFields } = clientProfile;
          await supabase
            .from("sonic_profiles")
            .update(profileFields)
            .eq("user_id", userId);
        } else if (serverUpdatedAt > clientUpdatedAt) {
          // Server wins — return server profile for client to adopt
          profileResponse = serverProfile;
        }
        // Equal timestamps = no action needed
      }
    }

    // --- ML Model Parameters Sync ---
    const mlResponse: MLParam[] = [];

    for (const clientParam of clientMLParams) {
      const { data: serverParam } = await supabase
        .from("ml_model_parameters")
        .select("*")
        .eq("model_type", clientParam.model_type)
        .single();

      if (!serverParam) {
        // No server param — create from client
        await supabase.from("ml_model_parameters").insert({
          user_id: userId,
          model_type: clientParam.model_type,
          parameters: clientParam.parameters,
          version: clientParam.version,
          training_session_count: clientParam.training_session_count ?? 0,
        });
      } else if (clientParam.version > serverParam.version) {
        // Client version is newer — update server
        await supabase
          .from("ml_model_parameters")
          .update({
            parameters: clientParam.parameters,
            version: clientParam.version,
            training_session_count: clientParam.training_session_count ?? serverParam.training_session_count,
            last_trained_at: new Date().toISOString(),
          })
          .eq("user_id", userId)
          .eq("model_type", clientParam.model_type);
      } else if (serverParam.version > clientParam.version) {
        // Server version is newer — return for client to adopt
        mlResponse.push({
          model_type: serverParam.model_type,
          parameters: serverParam.parameters,
          version: serverParam.version,
          training_session_count: serverParam.training_session_count,
        });
      }
      // Equal versions = no action needed
    }

    // Also check for server params the client doesn't have yet
    const { data: allServerParams } = await supabase
      .from("ml_model_parameters")
      .select("model_type, parameters, version, training_session_count");

    const clientTypes = new Set(clientMLParams.map((p) => p.model_type));
    for (const sp of allServerParams ?? []) {
      if (!clientTypes.has(sp.model_type)) {
        mlResponse.push(sp);
      }
    }

    // --- Population Models (always return latest for cold-start) ---
    const { data: populationModels } = await supabaseAdmin
      .from("ml_population_models")
      .select("model_type, mode, parameters, version");

    return jsonResponse({
      sonic_profile: profileResponse,
      ml_parameters: mlResponse.length > 0 ? mlResponse : null,
      population_models: populationModels ?? [],
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return errorResponse(message, 500);
  }
});
