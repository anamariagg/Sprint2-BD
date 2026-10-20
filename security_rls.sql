-- =====================================================================
-- Bookly · Row Level Security (RLS) · SOLO para Supabase
-- Ejecutar DESPUÉS de schema.sql y security.sql.
-- Requiere los roles anon / authenticated y la función auth.uid() que
-- Supabase ya provee. El backend se conecta con rol_app (no con la API
-- REST de Supabase); RLS protege el acceso directo por la API.
-- =====================================================================

-- 1. Activar RLS en TODAS las tablas del esquema público
ALTER TABLE app_user              ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform              ENABLE ROW LEVEL SECURITY;
ALTER TABLE servicios             ENABLE ROW LEVEL SECURITY;
ALTER TABLE profesionales         ENABLE ROW LEVEL SECURITY;
ALTER TABLE profesional_servicio  ENABLE ROW LEVEL SECURITY;
ALTER TABLE horario_semanal       ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings              ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_delivery ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log             ENABLE ROW LEVEL SECURITY;
ALTER TABLE mfa_recovery_code     ENABLE ROW LEVEL SECURITY;
ALTER TABLE mfa_trusted_device    ENABLE ROW LEVEL SECURITY;

-- 2. Roles internos: RLS no les quita filas; los límites los fijan los
--    GRANT de security.sql (qué comandos puede ejecutar cada rol).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['app_user','platform','servicios','profesionales',
     'profesional_servicio','horario_semanal','bookings',
     'notification_delivery','audit_log','mfa_recovery_code',
     'mfa_trusted_device']
  LOOP
    EXECUTE format('CREATE POLICY %I ON %I FOR ALL TO rol_admin USING (true) WITH CHECK (true)', t||'_admin', t);
    EXECUTE format('CREATE POLICY %I ON %I FOR ALL TO rol_app   USING (true) WITH CHECK (true)', t||'_app',   t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['app_user','platform','servicios','profesionales',
     'profesional_servicio','horario_semanal','bookings','notification_delivery']
  LOOP
    EXECUTE format('CREATE POLICY %I ON %I FOR SELECT TO rol_lectura USING (true)', t||'_lectura', t);
  END LOOP;
END $$;
CREATE POLICY audit_log_auditor ON audit_log FOR SELECT TO rol_auditor USING (true);
CREATE POLICY app_user_auditor  ON app_user  FOR SELECT TO rol_auditor USING (true);

-- 3. API de Supabase (anon / authenticated): partir sin ningún privilegio
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- 3a. anon (sin sesión): no accede a nada (sin GRANT y sin políticas).

-- 3b. authenticated (sesión iniciada): solo lo propio y el catálogo
GRANT SELECT ON servicios, profesionales, bookings TO authenticated;
GRANT SELECT (id, email, full_name, role) ON app_user TO authenticated;

CREATE POLICY servicios_catalogo ON servicios
    FOR SELECT TO authenticated USING (estado = 'ACTIVO');

CREATE POLICY profesionales_publicos ON profesionales
    FOR SELECT TO authenticated USING (true);

CREATE POLICY bookings_propias ON bookings
    FOR SELECT TO authenticated
    USING (customer_id = auth.uid() OR professional_id = auth.uid());

CREATE POLICY app_user_propio ON app_user
    FOR SELECT TO authenticated USING (id = auth.uid());

-- Sin políticas ni GRANT para authenticated en: platform, horario_semanal,
-- profesional_servicio, notification_delivery, audit_log, mfa_recovery_code,
-- mfa_trusted_device (solo accede el backend por rol_app).
