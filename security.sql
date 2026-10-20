-- =====================================================================
-- Bookly · Roles y privilegios (GRANT / REVOKE) · Sprint 2
-- Ejecutar DESPUÉS de schema.sql, con un usuario dueño del esquema.
-- Principio de mínimo privilegio: cada rol recibe solo lo que necesita.
-- =====================================================================

-- 1. Crear los roles (NOLOGIN: grupos de privilegios; el usuario real de
--    conexión se crea aparte y hereda el rol, ver ejemplo al final)
CREATE ROLE rol_admin   NOLOGIN;  -- administración y cambios de esquema
CREATE ROLE rol_app     NOLOGIN;  -- backend Spring Boot en funcionamiento
CREATE ROLE rol_lectura NOLOGIN;  -- reportes y consultas (solo lectura)
CREATE ROLE rol_auditor NOLOGIN;  -- consulta de la bitácora (HU-19)

-- 2. Esquema: nadie crea objetos salvo el dueño; todos pueden "ver" el esquema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO rol_admin, rol_app, rol_lectura, rol_auditor;

-- 3. Partir de cero: quitar todo privilegio a PUBLIC sobre las tablas
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- ---------------------------------------------------------------------
-- rol_admin: todo, EXCEPTO modificar la bitácora (es append-only)
-- ---------------------------------------------------------------------
GRANT ALL ON ALL TABLES IN SCHEMA public TO rol_admin;
REVOKE UPDATE, DELETE, TRUNCATE ON audit_log FROM rol_admin;

-- ---------------------------------------------------------------------
-- rol_app: lo mínimo que usa la aplicación. Sin DELETE salvo donde el
-- flujo lo exige (reemplazo de horario, regeneración de códigos MFA,
-- renovación de dispositivos de confianza, vínculo profesional-servicio).
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE         ON app_user              TO rol_app;
GRANT SELECT, INSERT, UPDATE         ON platform              TO rol_app;
GRANT SELECT, INSERT, UPDATE         ON servicios             TO rol_app;
GRANT SELECT, INSERT, UPDATE         ON profesionales         TO rol_app;
GRANT SELECT, INSERT, DELETE         ON profesional_servicio  TO rol_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON horario_semanal       TO rol_app;
GRANT SELECT, INSERT, UPDATE         ON bookings              TO rol_app;
GRANT SELECT, INSERT, UPDATE         ON notification_delivery TO rol_app;
GRANT SELECT, INSERT                 ON audit_log             TO rol_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON mfa_recovery_code     TO rol_app;
GRANT SELECT, INSERT, DELETE         ON mfa_trusted_device    TO rol_app;

-- ---------------------------------------------------------------------
-- rol_lectura: reportes. Sin datos de seguridad ni bitácora.
-- En app_user solo columnas no sensibles (nada de password_hash,
-- mfa_secret_encrypted, intentos fallidos ni bloqueo).
-- ---------------------------------------------------------------------
GRANT SELECT ON platform, servicios, profesionales, profesional_servicio,
                horario_semanal, bookings, notification_delivery
      TO rol_lectura;
GRANT SELECT (id, email, full_name, role, enabled, created_at, updated_at)
      ON app_user TO rol_lectura;

-- ---------------------------------------------------------------------
-- rol_auditor: solo la bitácora y el nombre de quien actuó
-- ---------------------------------------------------------------------
GRANT SELECT ON audit_log TO rol_auditor;
GRANT SELECT (id, full_name, role) ON app_user TO rol_auditor;

-- ---------------------------------------------------------------------
-- Ejemplo (NO ejecutar tal cual): usuario de conexión del backend.
-- La contraseña se define fuera del repositorio (variable de entorno).
-- ---------------------------------------------------------------------
-- CREATE ROLE usuario_backend LOGIN PASSWORD '<definir-fuera-del-repo>' IN ROLE rol_app;
