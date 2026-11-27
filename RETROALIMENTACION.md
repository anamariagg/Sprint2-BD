# Retroalimentación – Bases de Datos

Calificación del Sprint 2 según la rúbrica. Los scripts se ejecutaron en PostgreSQL 16 vacío (con los roles de Supabase simulados).

## Sprint 2 — 5.0 / 5.0

| Criterio | Nivel | Puntos |
|---|---|---|
| C1 MER refinado | Excelente | 0.60 / 0.60 |
| C2 Modelo físico | Excelente | 0.80 / 0.80 |
| C3 schema.sql | Excelente | 0.80 / 0.80 |
| C4 Consultas | Excelente | 0.70 / 0.70 |
| C5 Volumen | Excelente | 0.50 / 0.50 |
| C6 Roles y seguridad | Excelente | 0.60 / 0.60 |
| C7 Almacenamiento e índices | Excelente | 0.40 / 0.40 |
| C8 Costo de una consulta | Excelente | 0.30 / 0.30 |
| C9 Optimización algebraica | Excelente | 0.30 / 0.30 |

- C1: 11 relaciones = 11 FK; la tabla de cambios explica cada tabla nueva con su HU.
- C4: 27 consultas sobre `datos_prueba.sql`, 26 con filas.
- C6: `rol_lectura` no puede leer `password_hash`; RLS en las 11 tablas con 36 políticas.
- C7/C8: buen contraste con PostgreSQL (21 páginas estimadas vs. 20 reales).
- Sugerencias: `bookings` usa `TIMESTAMP` sin zona; retirar los índices redundantes que el propio análisis identificó.
- Repositorio: todos los commits desde una sola cuenta.

El Sprint 3 se calificó en el repositorio del equipo.
