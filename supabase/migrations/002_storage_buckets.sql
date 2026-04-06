-- BioNaural: Storage buckets for audio content and ML models

-- Public bucket for published stem pack archives (CDN-cached)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'stem-packs',
  'stem-packs',
  true,
  52428800, -- 50MB max per file
  ARRAY['application/zip', 'audio/mp4', 'audio/x-m4a', 'audio/aac', 'application/json']
);

-- Private bucket for generation pipeline working files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'generation-workspace',
  'generation-workspace',
  false,
  209715200, -- 200MB max (raw WAV files can be large)
  ARRAY['audio/wav', 'audio/mp4', 'audio/x-m4a', 'application/json', 'application/zip']
);

-- Private bucket for ML model checkpoints and matrices
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ml-models',
  'ml-models',
  false,
  10485760, -- 10MB max (JSON matrices are small)
  ARRAY['application/json', 'application/octet-stream']
);

-- Storage policies for stem-packs (public read, service-role write)
CREATE POLICY stem_packs_public_read ON storage.objects
  FOR SELECT USING (bucket_id = 'stem-packs');

-- Storage policies for generation-workspace (service-role only)
-- No policy = no access for anon/authenticated; service_role bypasses RLS

-- Storage policies for ml-models (authenticated read for global models)
CREATE POLICY ml_models_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'ml-models'
    AND (storage.foldername(name))[1] = 'global'
  );
