-- =====================================================================
-- Bookly · Datos de demostración para las evidencias de las consultas
-- Ejecutar DESPUÉS de schema.sql, en una base de PRUEBA (no en producción).
-- Se puede ejecutar varias veces: cada INSERT usa ON CONFLICT DO NOTHING.
-- Los UUID son fijos para que coincidan con los parámetros de ejemplo del
-- README (cliente ...0001, profesional ...0002, servicio ...00a1,
-- reserva ...00b1). Ejecutarlo justo antes de tomar las capturas.
-- =====================================================================

INSERT INTO platform (id, name, status, created_at) VALUES
 ('00000000-0000-0000-0000-0000000000f1', 'Bookly Demo', 'ACTIVE', now())
ON CONFLICT DO NOTHING;

-- Cuentas ------------------------------------------------------------
INSERT INTO app_user (id, email, password_hash, full_name, role, enabled,
                      failed_login_attempts, locked_until, created_at, updated_at, mfa_enabled) VALUES
 ('00000000-0000-0000-0000-000000000001','cliente1@bookly.local','hash-demo','Cliente Uno','CUSTOMER',true,0,NULL,'2026-10-20 10:00+00',now(),false),
 ('00000000-0000-0000-0000-000000000005','juan@example.com','hash-demo','Juan Pérez','CUSTOMER',true,3,NULL,'2026-10-21 09:30+00',now(),false),
 ('00000000-0000-0000-0000-000000000006','maria@example.com','hash-demo','María Gómez','CUSTOMER',true,5,now() + interval '1 day','2026-10-21 15:00+00',now(),false),
 ('00000000-0000-0000-0000-000000000007','luis@example.com','hash-demo','Luis Torres','CUSTOMER',false,0,NULL,'2026-10-22 11:00+00',now(),false),
 ('00000000-0000-0000-0000-000000000002','fisio@bookly.local','hash-demo','Laura Ríos','PROFESSIONAL',true,0,NULL,'2026-10-18 08:00+00',now(),false),
 ('00000000-0000-0000-0000-000000000004','nutri@bookly.local','hash-demo','Carlos Mejía','PROFESSIONAL',true,0,NULL,'2026-10-18 08:30+00',now(),false),
 ('00000000-0000-0000-0000-000000000008','estetica@bookly.local','hash-demo','Sofía Vélez','PROFESSIONAL',true,0,NULL,'2026-10-19 09:00+00',now(),false),
 ('00000000-0000-0000-0000-000000000003','admin@bookly.local','hash-demo','Administrador Uno','ADMIN',true,0,NULL,'2026-10-15 08:00+00',now(),false),
 ('00000000-0000-0000-0000-000000000009','admin2@bookly.local','hash-demo','Administrador Dos','ADMIN',true,0,NULL,'2026-10-15 08:30+00',now(),true)
ON CONFLICT DO NOTHING;

INSERT INTO profesionales (id, especialidad, created_at, updated_at) VALUES
 ('00000000-0000-0000-0000-000000000002','Fisioterapia',now(),now()),
 ('00000000-0000-0000-0000-000000000004','Nutrición',now(),now()),
 ('00000000-0000-0000-0000-000000000008','Estética',now(),now())
ON CONFLICT DO NOTHING;

-- Catálogo -----------------------------------------------------------
INSERT INTO servicios (id, nombre, descripcion, categoria, duracion_minutos, precio, estado, created_at, updated_at) VALUES
 ('00000000-0000-0000-0000-0000000000a1','Masaje relajante','Masaje de cuerpo completo','Spa',60,50000.00,'ACTIVO',now(),now()),
 ('00000000-0000-0000-0000-0000000000a2','Consulta nutricional','Plan de alimentación personalizado','Nutrición',90,80000.00,'ACTIVO',now(),now()),
 ('00000000-0000-0000-0000-0000000000a3','Corte de cabello',NULL,'Belleza',30,20000.00,'ACTIVO',now(),now()),
 ('00000000-0000-0000-0000-0000000000a4','Terapia física','Sesión de rehabilitación','Fisioterapia',75,70000.00,'INACTIVO',now(),now())
ON CONFLICT DO NOTHING;

INSERT INTO profesional_servicio (id, profesional_id, servicio_id, created_at) VALUES
 ('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1',now()),
 ('00000000-0000-0000-0000-0000000000c2','00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-0000000000a2',now()),
 ('00000000-0000-0000-0000-0000000000c3','00000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-0000000000a3',now())
ON CONFLICT DO NOTHING;

-- El profesional ...0008 no tiene horario (lo muestra la consulta S2-13)
INSERT INTO horario_semanal (id, profesional_id, dia_semana, hora_inicio, hora_fin, created_at, updated_at) VALUES
 ('00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-000000000002','MONDAY','09:00','12:00',now(),now()),
 ('00000000-0000-0000-0000-0000000000d2','00000000-0000-0000-0000-000000000002','TUESDAY','14:00','18:00',now(),now()),
 ('00000000-0000-0000-0000-0000000000d3','00000000-0000-0000-0000-000000000004','WEDNESDAY','08:00','12:00',now(),now())
ON CONFLICT DO NOTHING;

-- Reservas -----------------------------------------------------------
INSERT INTO bookings (id, customer_id, professional_id, service_id, start_time, end_time, status, cancelled_at, cancellation_reason) VALUES
 ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','2026-11-02 09:00','2026-11-02 10:00','CONFIRMADA',NULL,NULL),
 ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','2026-11-03 14:00','2026-11-03 15:00','CANCELADA','2026-10-24 16:00','Cambio de agenda'),
 ('00000000-0000-0000-0000-0000000000b3','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','2026-10-19 09:00','2026-10-19 10:00','COMPLETED',NULL,NULL),
 ('00000000-0000-0000-0000-0000000000b4','00000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-0000000000a2','2026-11-04 08:00','2026-11-04 09:30','CONFIRMADA',NULL,NULL),
 ('00000000-0000-0000-0000-0000000000b5','00000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','2026-11-09 09:00','2026-11-09 10:00','CONFIRMADA',NULL,NULL),
 ('00000000-0000-0000-0000-0000000000b6','00000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-0000000000a3','2026-11-05 10:00','2026-11-05 10:30','CANCELADA','2026-10-25 12:00','El cliente no puede asistir'),
 ('00000000-0000-0000-0000-0000000000b7','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-0000000000a2','2026-11-11 08:00','2026-11-11 09:30','RESCHEDULED',NULL,NULL),
 ('00000000-0000-0000-0000-0000000000b8','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-0000000000a2','2026-11-12 08:00','2026-11-12 09:30','CONFIRMADA',NULL,NULL)
ON CONFLICT DO NOTHING;

-- Notificaciones -----------------------------------------------------
INSERT INTO notification_delivery (id, event_id, booking_id, event_type, recipient_email, subject, status, attempts, created_at, sent_at, last_attempt_at, error_message) VALUES
 ('00000000-0000-0000-0000-0000000000e1','00000000-0000-0000-0000-0000000000f2','00000000-0000-0000-0000-0000000000b1','BOOKING_CREATED','cliente1@bookly.local','Reserva confirmada','SENT',1,'2026-10-22 10:05+00','2026-10-22 10:05+00','2026-10-22 10:05+00',NULL),
 ('00000000-0000-0000-0000-0000000000e2','00000000-0000-0000-0000-0000000000f3','00000000-0000-0000-0000-0000000000b1','BOOKING_RESCHEDULED','cliente1@bookly.local','Reserva reprogramada','PENDING',0,'2026-10-26 08:00+00',NULL,NULL,NULL),
 ('00000000-0000-0000-0000-0000000000e3','00000000-0000-0000-0000-0000000000f4','00000000-0000-0000-0000-0000000000b2','BOOKING_CANCELLED','cliente1@bookly.local','Reserva cancelada','FAILED',3,'2026-10-24 16:01+00',NULL,'2026-10-24 16:30+00','SMTP timeout'),
 ('00000000-0000-0000-0000-0000000000e4','00000000-0000-0000-0000-0000000000f5','00000000-0000-0000-0000-0000000000b4','BOOKING_CREATED','juan@example.com','Reserva confirmada','SENT',1,'2026-10-25 09:00+00','2026-10-25 09:00+00','2026-10-25 09:00+00',NULL)
ON CONFLICT DO NOTHING;

-- Bitácora -----------------------------------------------------------
INSERT INTO audit_log (id, actor_user_id, action_type, resource_type, resource_id, occurred_at, source_ip, metadata) VALUES
 ('00000000-0000-0000-0000-000000000a01','00000000-0000-0000-0000-000000000001','BOOKING_CREATED','BOOKING','00000000-0000-0000-0000-0000000000b1','2026-10-22 10:05+00','190.1.1.10','{}'),
 ('00000000-0000-0000-0000-000000000a02','00000000-0000-0000-0000-000000000003','ROLE_CHANGED','USER','00000000-0000-0000-0000-000000000002','2026-10-23 09:00+00','190.1.1.20','{"nuevo_rol":"PROFESSIONAL"}'),
 ('00000000-0000-0000-0000-000000000a03','00000000-0000-0000-0000-000000000001','BOOKING_CANCELLED','BOOKING','00000000-0000-0000-0000-0000000000b2','2026-10-24 16:00+00','190.1.1.10','{}'),
 ('00000000-0000-0000-0000-000000000a04','00000000-0000-0000-0000-000000000005','BOOKING_CREATED','BOOKING','00000000-0000-0000-0000-0000000000b4','2026-10-25 09:00+00','190.1.1.30','{}'),
 ('00000000-0000-0000-0000-000000000a05','00000000-0000-0000-0000-000000000003','ROLE_CHANGED','USER','00000000-0000-0000-0000-000000000004','2026-10-26 07:30+00','190.1.1.20','{"nuevo_rol":"PROFESSIONAL"}')
ON CONFLICT DO NOTHING;

-- MFA (el administrador Uno no tiene MFA; el Dos sí) ------------------
INSERT INTO mfa_recovery_code (id, user_id, code_hash, used_at, created_at) VALUES
 ('00000000-0000-0000-0000-000000000b01','00000000-0000-0000-0000-000000000009','hash-codigo-1',NULL,now()),
 ('00000000-0000-0000-0000-000000000b02','00000000-0000-0000-0000-000000000009','hash-codigo-2',NULL,now()),
 ('00000000-0000-0000-0000-000000000b03','00000000-0000-0000-0000-000000000009','hash-codigo-3','2026-10-25 10:00+00',now())
ON CONFLICT DO NOTHING;

INSERT INTO mfa_trusted_device (id, user_id, token_hash, created_at, expires_at) VALUES
 ('00000000-0000-0000-0000-000000000c01','00000000-0000-0000-0000-000000000009','hash-dispositivo-1',now(),now() + interval '30 days')
ON CONFLICT DO NOTHING;
