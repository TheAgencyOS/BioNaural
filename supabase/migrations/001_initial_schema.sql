-- BioNaural: Initial database schema
-- Tables: users, sonic_profiles, sessions, stem_packs, variation_sets,
--         generation_jobs, ml_model_parameters, ml_population_models, aggregate_outcomes

-- =============================================================================
-- USERS
-- =============================================================================

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  subscription_tier TEXT NOT NULL DEFAULT 'free'
    CHECK (subscription_tier IN ('free', 'premium', 'lifetime')),
  subscription_expires_at TIMESTAMPTZ,
  device_model TEXT,
  ios_version TEXT,
  app_version TEXT,
  onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  UNIQUE(auth_id)
);

CREATE INDEX idx_users_auth_id ON users(auth_id);

-- =============================================================================
-- SONIC PROFILES (mirrors on-device SoundProfile)
-- =============================================================================

CREATE TABLE sonic_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Instrument preference weights: {"pad": 0.8, "piano": 0.6, "strings": 0.9, ...}
  instrument_weights JSONB NOT NULL DEFAULT '{}',
  -- Per-mode energy preferences: {"focus": 0.4, "relaxation": 0.2, "sleep": 0.1, "energize": 0.7}
  energy_preference JSONB NOT NULL DEFAULT '{}',
  brightness_preference DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  density_preference DOUBLE PRECISION NOT NULL DEFAULT 0.3,
  warmth_preference DOUBLE PRECISION,
  tempo_affinity DOUBLE PRECISION,
  key_preference TEXT,
  sound_dna_sample_count INT NOT NULL DEFAULT 0,
  self_awareness_score DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  -- Sound success/failure tracking
  successful_sounds JSONB NOT NULL DEFAULT '{}',
  disliked_sounds TEXT[] NOT NULL DEFAULT '{}',
  -- Hash of preferences for change detection (SHA256)
  profile_hash TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX idx_sonic_profiles_user_id ON sonic_profiles(user_id);
CREATE INDEX idx_sonic_profiles_hash ON sonic_profiles(profile_hash);

-- =============================================================================
-- VARIATION SETS (groups of related stem packs for long sessions)
-- =============================================================================

CREATE TABLE variation_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('focus', 'relaxation', 'sleep', 'energize')),
  -- Shared musical properties across the set
  key TEXT,
  tempo_min DOUBLE PRECISION,
  tempo_max DOUBLE PRECISION,
  energy_range_min DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  energy_range_max DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  pack_count INT NOT NULL DEFAULT 0,
  -- Long session config
  crossfade_interval_seconds INT NOT NULL DEFAULT 1200, -- 20 min default
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_published BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_variation_sets_mode ON variation_sets(mode) WHERE is_published = true;

-- =============================================================================
-- STEM PACKS (server catalog of generated audio content)
-- =============================================================================

CREATE TABLE stem_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('focus', 'relaxation', 'sleep', 'energize')),
  -- Audio characteristics (0.0-1.0 scales)
  energy DOUBLE PRECISION NOT NULL,
  brightness DOUBLE PRECISION NOT NULL,
  warmth DOUBLE PRECISION NOT NULL,
  density DOUBLE PRECISION,
  tempo DOUBLE PRECISION,
  key TEXT,
  scale TEXT,
  -- Generation metadata
  generated_by TEXT NOT NULL CHECK (generated_by IN ('ace-step-1.5', 'demucs', 'manual')),
  generation_prompt TEXT,
  -- Variation set membership
  variation_set_id UUID REFERENCES variation_sets(id) ON DELETE SET NULL,
  variation_order INT, -- position within the set for sequential playback
  -- Storage references (paths within stem-packs bucket)
  pads_path TEXT NOT NULL,
  texture_path TEXT NOT NULL,
  bass_path TEXT NOT NULL,
  rhythm_path TEXT,
  metadata_path TEXT NOT NULL,
  archive_path TEXT NOT NULL,
  archive_size_bytes BIGINT NOT NULL,
  -- Audio specs
  duration_seconds DOUBLE PRECISION NOT NULL DEFAULT 60.0,
  sample_rate INT NOT NULL DEFAULT 44100,
  bitrate_kbps INT NOT NULL DEFAULT 128,
  lufs_normalized DOUBLE PRECISION DEFAULT -18.0,
  loop_crossfade_ms INT DEFAULT 100,
  -- Quality and curation
  is_curated BOOLEAN NOT NULL DEFAULT false,
  quality_score DOUBLE PRECISION, -- 0-1, set during curation
  -- Lifecycle
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ,
  is_published BOOLEAN NOT NULL DEFAULT false,
  download_count INT NOT NULL DEFAULT 0
);

CREATE INDEX idx_stem_packs_mode ON stem_packs(mode) WHERE is_published = true;
CREATE INDEX idx_stem_packs_mode_energy ON stem_packs(mode, energy) WHERE is_published = true;
CREATE INDEX idx_stem_packs_variation_set ON stem_packs(variation_set_id, variation_order);

-- =============================================================================
-- SESSIONS (mirrors on-device SessionOutcome for ML training)
-- =============================================================================

CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK (mode IN ('focus', 'relaxation', 'sleep', 'energize')),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ,
  duration_seconds INT NOT NULL,
  -- Biometric outcomes (derived scores only, never raw HR samples)
  hr_start DOUBLE PRECISION,
  hr_end DOUBLE PRECISION,
  hr_delta DOUBLE PRECISION,
  hrv_start DOUBLE PRECISION,
  hrv_end DOUBLE PRECISION,
  hrv_delta DOUBLE PRECISION,
  average_heart_rate DOUBLE PRECISION,
  average_hrv DOUBLE PRECISION,
  time_to_calm_seconds DOUBLE PRECISION,
  time_to_sleep_seconds DOUBLE PRECISION,
  adaptation_count INT NOT NULL DEFAULT 0,
  sustained_deep_state_minutes DOUBLE PRECISION NOT NULL DEFAULT 0,
  -- Audio parameters used during session
  entrainment_method TEXT CHECK (entrainment_method IN ('binaural', 'isochronic', 'combined')),
  beat_frequency_start DOUBLE PRECISION NOT NULL,
  beat_frequency_end DOUBLE PRECISION NOT NULL,
  carrier_frequency DOUBLE PRECISION NOT NULL,
  ambient_bed_id TEXT,
  melodic_layer_ids TEXT[] NOT NULL DEFAULT '{}',
  stem_pack_id TEXT,
  -- User feedback
  was_completed BOOLEAN NOT NULL DEFAULT false,
  thumbs_rating TEXT CHECK (thumbs_rating IN ('up', 'down')),
  feedback_tags TEXT[],
  check_in_mood DOUBLE PRECISION,
  check_in_goal TEXT,
  check_in_skipped BOOLEAN NOT NULL DEFAULT false,
  -- Computed scores
  biometric_success_score DOUBLE PRECISION,
  overall_score DOUBLE PRECISION,
  -- Context
  time_of_day TEXT CHECK (time_of_day IN ('morning', 'afternoon', 'evening', 'night')),
  day_of_week INT CHECK (day_of_week BETWEEN 0 AND 6),
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_mode ON sessions(mode);
CREATE INDEX idx_sessions_start_date ON sessions(start_date DESC);
CREATE INDEX idx_sessions_user_mode ON sessions(user_id, mode);
CREATE INDEX idx_sessions_user_score ON sessions(user_id, overall_score DESC);
CREATE INDEX idx_sessions_training_data ON sessions(mode, overall_score)
  WHERE biometric_success_score IS NOT NULL;

-- =============================================================================
-- GENERATION JOBS (ACE-STEP pipeline tracking)
-- =============================================================================

CREATE TABLE generation_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  -- Generation parameters
  prompt TEXT NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('focus', 'relaxation', 'sleep', 'energize')),
  duration_seconds INT NOT NULL DEFAULT 60,
  target_bpm INT,
  target_key TEXT,
  target_scale TEXT,
  target_energy DOUBLE PRECISION,
  target_brightness DOUBLE PRECISION,
  target_warmth DOUBLE PRECISION,
  -- Pipeline status
  status TEXT NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'generating', 'post_processing', 'curating', 'completed', 'failed')),
  priority INT NOT NULL DEFAULT 0,
  -- Replicate integration
  replicate_prediction_id TEXT,
  replicate_output_url TEXT,
  -- Results
  result_pack_id TEXT REFERENCES stem_packs(id),
  error_message TEXT,
  retry_count INT NOT NULL DEFAULT 0,
  -- Timing
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  worker_id TEXT
);

CREATE INDEX idx_generation_jobs_status ON generation_jobs(status, priority DESC)
  WHERE status IN ('queued', 'generating', 'post_processing');
CREATE INDEX idx_generation_jobs_user ON generation_jobs(user_id)
  WHERE user_id IS NOT NULL;
CREATE INDEX idx_generation_jobs_replicate ON generation_jobs(replicate_prediction_id)
  WHERE replicate_prediction_id IS NOT NULL;

-- =============================================================================
-- ML MODEL PARAMETERS (per-user synced weights)
-- =============================================================================

CREATE TABLE ml_model_parameters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  model_type TEXT NOT NULL CHECK (model_type IN (
    'sound_selection_bandit',
    'frequency_tuning_gp',
    'sleep_onset_predictor',
    'signal_quality',
    'user_model',
    'markov_transitions'
  )),
  -- Model-specific serialized weights (structure varies by model_type)
  parameters JSONB NOT NULL,
  -- Versioning for sync conflict resolution (higher version wins)
  version INT NOT NULL DEFAULT 1,
  -- Training metadata
  training_session_count INT NOT NULL DEFAULT 0,
  last_trained_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, model_type)
);

CREATE INDEX idx_ml_params_user ON ml_model_parameters(user_id);

-- =============================================================================
-- ML POPULATION MODELS (server-trained, shared across all users)
-- =============================================================================

CREATE TABLE ml_population_models (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_type TEXT NOT NULL CHECK (model_type IN (
    'markov_transitions',
    'gp_population_prior',
    'thompson_population_weights',
    'gmm_timbre_clusters',
    'vae_composition_space'
  )),
  -- Mode-specific models (null for mode-agnostic models)
  mode TEXT CHECK (mode IN ('focus', 'relaxation', 'sleep', 'energize')),
  -- Serialized model weights
  parameters JSONB NOT NULL,
  -- Training provenance
  version INT NOT NULL DEFAULT 1,
  training_session_count INT NOT NULL DEFAULT 0,
  training_user_count INT NOT NULL DEFAULT 0,
  trained_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Quality metrics
  cross_validation_score DOUBLE PRECISION,
  notes TEXT,
  UNIQUE(model_type, mode)
);

CREATE INDEX idx_ml_population_type_mode ON ml_population_models(model_type, mode);

-- =============================================================================
-- AGGREGATE OUTCOMES (anonymized cross-user data for collaborative filtering)
-- =============================================================================

CREATE TABLE aggregate_outcomes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mode TEXT NOT NULL CHECK (mode IN ('focus', 'relaxation', 'sleep', 'energize')),
  stem_pack_id TEXT REFERENCES stem_packs(id) ON DELETE SET NULL,
  -- Aggregated metrics (NO user identification)
  session_count INT NOT NULL DEFAULT 0,
  avg_biometric_score DOUBLE PRECISION,
  avg_overall_score DOUBLE PRECISION,
  avg_completion_rate DOUBLE PRECISION,
  avg_duration_seconds DOUBLE PRECISION,
  -- Context buckets for collaborative filtering
  time_of_day_bucket TEXT CHECK (time_of_day_bucket IN ('morning', 'afternoon', 'evening', 'night')),
  energy_bucket TEXT CHECK (energy_bucket IN ('low', 'medium', 'high')),
  -- Entrainment method effectiveness
  binaural_avg_score DOUBLE PRECISION,
  binaural_session_count INT DEFAULT 0,
  isochronic_avg_score DOUBLE PRECISION,
  isochronic_session_count INT DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(mode, stem_pack_id, time_of_day_bucket, energy_bucket)
);

CREATE INDEX idx_aggregate_mode ON aggregate_outcomes(mode);
CREATE INDEX idx_aggregate_pack ON aggregate_outcomes(stem_pack_id)
  WHERE stem_pack_id IS NOT NULL;

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER sonic_profiles_updated_at
  BEFORE UPDATE ON sonic_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER ml_params_updated_at
  BEFORE UPDATE ON ml_model_parameters FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER aggregate_outcomes_updated_at
  BEFORE UPDATE ON aggregate_outcomes FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Increment stem_packs download count atomically
CREATE OR REPLACE FUNCTION increment_download_count(pack_id TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE stem_packs SET download_count = download_count + 1 WHERE id = pack_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update variation_sets.pack_count when stem_packs change
CREATE OR REPLACE FUNCTION sync_variation_set_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.variation_set_id IS NOT NULL THEN
      UPDATE variation_sets
      SET pack_count = (
        SELECT COUNT(*) FROM stem_packs WHERE variation_set_id = NEW.variation_set_id
      )
      WHERE id = NEW.variation_set_id;
    END IF;
  END IF;
  IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
    IF OLD.variation_set_id IS NOT NULL THEN
      UPDATE variation_sets
      SET pack_count = (
        SELECT COUNT(*) FROM stem_packs WHERE variation_set_id = OLD.variation_set_id
      )
      WHERE id = OLD.variation_set_id;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER stem_packs_variation_count
  AFTER INSERT OR UPDATE OR DELETE ON stem_packs
  FOR EACH ROW EXECUTE FUNCTION sync_variation_set_count();

-- Auto-create user record on auth signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (auth_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

-- Helper: get user's internal id from auth.uid()
CREATE OR REPLACE FUNCTION get_user_id()
RETURNS UUID AS $$
  SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- USERS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_select ON users
  FOR SELECT USING (auth_id = auth.uid());

CREATE POLICY users_update ON users
  FOR UPDATE USING (auth_id = auth.uid());

-- SONIC PROFILES
ALTER TABLE sonic_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY sp_select ON sonic_profiles
  FOR SELECT USING (user_id = get_user_id());

CREATE POLICY sp_insert ON sonic_profiles
  FOR INSERT WITH CHECK (user_id = get_user_id());

CREATE POLICY sp_update ON sonic_profiles
  FOR UPDATE USING (user_id = get_user_id());

CREATE POLICY sp_delete ON sonic_profiles
  FOR DELETE USING (user_id = get_user_id());

-- SESSIONS
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY sessions_select ON sessions
  FOR SELECT USING (user_id = get_user_id());

CREATE POLICY sessions_insert ON sessions
  FOR INSERT WITH CHECK (user_id = get_user_id());

-- STEM PACKS (published packs readable by all authenticated users)
ALTER TABLE stem_packs ENABLE ROW LEVEL SECURITY;

CREATE POLICY packs_select ON stem_packs
  FOR SELECT USING (is_published = true);
-- INSERT/UPDATE/DELETE: service_role only (no policy = denied for anon/authenticated)

-- VARIATION SETS (published sets readable by all authenticated users)
ALTER TABLE variation_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY vsets_select ON variation_sets
  FOR SELECT USING (is_published = true);

-- GENERATION JOBS (users see only own jobs)
ALTER TABLE generation_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY jobs_select ON generation_jobs
  FOR SELECT USING (user_id = get_user_id());

CREATE POLICY jobs_insert ON generation_jobs
  FOR INSERT WITH CHECK (user_id = get_user_id());

-- ML MODEL PARAMETERS (own data only)
ALTER TABLE ml_model_parameters ENABLE ROW LEVEL SECURITY;

CREATE POLICY ml_select ON ml_model_parameters
  FOR SELECT USING (user_id = get_user_id());

CREATE POLICY ml_insert ON ml_model_parameters
  FOR INSERT WITH CHECK (user_id = get_user_id());

CREATE POLICY ml_update ON ml_model_parameters
  FOR UPDATE USING (user_id = get_user_id());

CREATE POLICY ml_delete ON ml_model_parameters
  FOR DELETE USING (user_id = get_user_id());

-- ML POPULATION MODELS (readable by all authenticated users)
ALTER TABLE ml_population_models ENABLE ROW LEVEL SECURITY;

CREATE POLICY pop_models_select ON ml_population_models
  FOR SELECT TO authenticated USING (true);
-- INSERT/UPDATE/DELETE: service_role only

-- AGGREGATE OUTCOMES (readable by all authenticated users, anonymized data)
ALTER TABLE aggregate_outcomes ENABLE ROW LEVEL SECURITY;

CREATE POLICY agg_select ON aggregate_outcomes
  FOR SELECT TO authenticated USING (true);
-- INSERT/UPDATE/DELETE: service_role only
