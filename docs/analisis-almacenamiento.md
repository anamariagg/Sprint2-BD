# Análisis de almacenamiento, costo y optimización · Bookly

## 1. Estrategia de almacenamiento e índices y estimación de `bookings`

### 1.1 Tabla analizada

Se analiza **`bookings`** (reservas). Según la estimación de volumen del README es la tabla transaccional que más crece: pasa de 0 a **13 992 registros** en 12 meses (+44 por mes, cada mes) y es la que consultan casi todas las historias de usuario (HU-07, HU-08, HU-09).

### 1.2 Organización de archivo

**Archivo de montículo (heap) con índices B+tree secundarios.** Es la organización nativa de PostgreSQL. Se justifica así:

| Alternativa | Decisión | Motivo |
|---|---|---|
| Heap (registros sin orden) | **Elegida** | Las reservas se insertan de forma continua; en un heap el registro nuevo va al final sin reorganizar nada. |
| Archivo ordenado por `start_time` | Descartada | Las reservas se crean para fechas futuras en cualquier orden; mantener el orden obligaría a reorganizar páginas en cada inserción. |
| Cluster multitabla (`bookings` + `servicios`) | Descartada | `servicios` es un catálogo pequeño y compartido por todos los profesionales; agruparlo con las reservas duplicaría su espacio y encarecería las inserciones. |

### 1.3 Índices elegidos

Todos son B+tree: sirven para igualdad (`professional_id = ?`) y para rangos (`start_time` entre dos fechas), que es lo que piden las consultas de disponibilidad y agenda.

| Índice | Columnas | Para qué sirve | Valoración |
|---|---|---|---|
| `bookings_pkey` | `id` | Búsqueda por identificador (cancelar, consultar una reserva) | Necesario |
| `idx_bookings_professional_start` | `professional_id, start_time DESC` | **Agenda de un profesional y cálculo de disponibilidad (consulta S2-3)** | **Índice analizado**; cubre igualdad por profesional + rango por fecha |
| `idx_bookings_customer` | `customer_id` | «Mis reservas» del cliente (S2-4) | Necesario |
| `unique_booking_per_professional_time` y `booking_no_overlapping_confirmed` | `professional_id, start_time, end_time` (parcial `CONFIRMADA`) y exclusión GiST | Integridad: evitan la doble reserva (ADR-006) | Necesarios por regla de negocio |
| `idx_bookings_professional` | `professional_id` | Búsqueda por profesional | **Redundante**: el índice compuesto ya empieza por esa columna |
| `idx_bookings_status` | `status` | Filtrar por estado | **Poco útil**: solo hay 4 valores, así que cada valor devuelve ≈ 25 % de la tabla (≈ 3 498 filas); casi siempre conviene leer la tabla completa |

> Observación para el equipo: `idx_bookings_professional` e `idx_bookings_status` ocupan espacio y encarecen cada inserción sin aportar mucho. Son candidatos a revisar en el Sprint 3. No se modifican en este sprint.

### 1.4 Supuestos

| # | Supuesto | Valor |
|---|---|---|
| A1 | Tamaño de página / bloque (P = B) | 8 192 bytes (valor por defecto de PostgreSQL) |
| A2 | Número de registros (TR) | 13 992 (mes 12 de la estimación de volumen) |
| A3 | UUID | 16 bytes |
| A4 | `TIMESTAMP` | 8 bytes |
| A5 | Puntero a registro en el índice | 6 bytes |
| A6 | Mapa de bits de nulos | 1 bit por campo |
| A7 | `status` | Promedio de 10 caracteres (`CONFIRMADA` = 10, `CANCELADA` = 9, `RESCHEDULED` = 11, `COMPLETED` = 9) |
| A8 | `cancellation_reason` | Solo existe en el 15 % de las reservas (las canceladas) y mide 40 caracteres cuando existe: 0,15 × 40 = 6 bytes en promedio |
| A9 | Valores distintos de la clave del índice | V = 13 992: cada pareja (profesional, hora de inicio) es casi única |

### 1.5 Longitud típica del registro (L)

Fórmula de referencia:

```
L = 4 · #campos var. + Σ size(campos fijos) + size(mapa de bits) + Σ tamaño estimado(campos var.)
```

`bookings` tiene 11 campos:

| Tipo de campo | Campos | Cálculo | Bytes |
|---|---|---|---:|
| Fijos UUID | `id`, `customer_id`, `professional_id`, `service_id` | 4 × 16 | 64 |
| Fijos TIMESTAMP | `start_time`, `end_time`, `created_at`, `updated_at`, `cancelled_at` | 5 × 8 | 40 |
| Variables (2) | `status`, `cancellation_reason` | 4 × 2 | 8 |
| Mapa de bits | 11 campos | ⌈11 / 8⌉ | 2 |
| Contenido variable | `status` (10) + `cancellation_reason` (6) | 10 + 6 | 16 |

```
L = 8 + (64 + 40) + 2 + 16 = 130 bytes
```

### 1.6 Registros por bloque (FR)

Fórmula de referencia: `FR = ⌊(P − 2) / (4 + L)⌋`

```
FR = ⌊(8192 − 2) / (4 + 130)⌋ = ⌊8190 / 134⌋ = ⌊61,12⌋ = 61 registros por página
```

### 1.7 Páginas de la tabla (BR)

Fórmula de referencia: `BR = ⌈TR / FR⌉`

```
BR = ⌈13 992 / 61⌉ = ⌈229,38⌉ = 230 páginas
Espacio de la tabla = 230 × 8 192 = 1 884 160 bytes ≈ 1,80 MiB
```

### 1.8 Índice `idx_bookings_professional_start`

**Longitud de una entrada.** Clave (`professional_id` 16 bytes + `start_time` 8 bytes) más el puntero:

```
L_I = 16 + 8 + 6 = 30 bytes
```

**Entradas por nodo y orden del árbol.** Fórmulas: `FR = ⌊B / L⌋` y `2d − 1 = FR`, con `d ≥ 3`.

```
FR_I = ⌊8192 / 30⌋ = ⌊273,07⌋ = 273 entradas por nodo
2d − 1 = 273  →  d = (273 + 1) / 2 = 137   (cumple d ≥ 3)
```

**Altura.** Fórmula: `H ≤ log_d V(a,R)`

```
H ≤ log_137(13 992) = ln(13 992) / ln(137) = 9,546 / 4,920 = 1,94  →  H = 2 niveles
```

**Nodos por nivel.** Fórmula: `nodos del nivel k ≈ V(a,R) / d^k`

| Nivel | Cálculo | Nodos |
|---|---|---:|
| 1 (hojas) | ⌈13 992 / 137⌉ = ⌈102,13⌉ | 103 |
| 2 (raíz) | ⌈13 992 / 137²⌉ = ⌈0,745⌉ | 1 |
| **Total** | 103 + 1 | **104** |

**Espacio del índice.** Fórmula: `Espacio = (Σ nodos de todos los niveles) × B`

```
Espacio = 104 × 8 192 = 851 968 bytes ≈ 832 KiB
```

### 1.9 Resumen

| Concepto | Valor |
|---|---:|
| Longitud del registro (L) | 130 bytes |
| Registros por página (FR) | 61 |
| Páginas de la tabla (BR) | 230 (≈ 1,80 MiB) |
| Longitud de entrada del índice (L_I) | 30 bytes |
| Orden del árbol (d) | 137 |
| Altura del índice (H) | 2 |
| Nodos del índice | 104 (≈ 832 KiB) |

**Lectura.** Con H = 2, encontrar las reservas de un profesional exige recorrer 2 nodos del índice más las páginas de la tabla que contengan sus registros, en lugar de leer las 230 páginas de la tabla completa. El índice ocupa cerca del 45 % del espacio de la tabla, un costo razonable por el beneficio en las consultas de agenda.

### 1.10 Validación contra PostgreSQL real

Para comprobar el modelo se creó una copia de `bookings` con 13 992 filas (15 % canceladas) y el mismo índice, y se midió el tamaño real:

| Concepto | Modelo teórico | PostgreSQL real |
|---|---:|---:|
| Páginas de la tabla | 230 | 269 |
| Páginas del índice | 104 | 71 |

Las diferencias son esperables, porque la fórmula del curso es una simplificación:

- **La tabla real ocupa más** porque PostgreSQL añade a cada registro un encabezado de unos 23 bytes, alineación de campos y un prefijo de longitud en los campos de texto, que la fórmula no cuenta.
- **El índice real ocupa menos** porque el modelo supone nodos con la ocupación mínima (la mitad llenos, con `d` entradas), mientras que PostgreSQL llena las hojas al 90 %. Por eso la estimación teórica del índice es una **cota superior** (el peor caso de espacio).

En ambos casos el orden de magnitud coincide: la tabla cabe en unos pocos cientos de páginas y el índice tiene 2 niveles.

---

## 2. Análisis de costo de una consulta

### 2.1 Consulta analizada (S2-4 simplificada)

**Pregunta que responde:** ¿qué reservas confirmadas tiene un cliente y de qué servicio son? (HU-08). Es la consulta que alimenta la pantalla «Mis reservas» y contiene una reunión (`bookings ⋈ servicios`).

```sql
SELECT b.start_time, b.end_time, s.nombre
FROM bookings b
JOIN servicios s ON s.id = b.service_id
WHERE b.customer_id = :cliente
  AND b.status = 'CONFIRMADA';
```

Para aislar el costo de la reunión se omite la unión con `app_user` que tiene la versión completa de S2-4.

### 2.2 Estadísticas usadas y de dónde salen

| Símbolo | Valor | Origen |
|---|---:|---|
| P = B | 8 192 bytes | Supuesto A1 (sección 1.4) |
| M (páginas de memoria disponibles) | 10 | Supuesto B1: valor conservador para un solo proceso |
| TR (tuplas de `bookings`) | 13 992 | Estimación de volumen del README, mes 12 |
| BR (páginas de `bookings`) | 230 | Sección 1.7 |
| L, FR de `bookings` | 130 bytes, 61 | Secciones 1.5 y 1.6 |
| TS (tuplas de `servicios`) | 42 | Estimación de volumen del README, mes 12 |
| L de `servicios` | 210 bytes | Cálculo en 2.2.1 |
| FS (tuplas por página de `servicios`) | 38 | `⌊(8192 − 2) / (4 + 210)⌋ = ⌊38,27⌋` |
| BS (páginas de `servicios`) | 2 | `⌈42 / 38⌉ = ⌈1,11⌉` |
| V(customer_id, bookings) | 920 | Supuesto B2: los 920 clientes del mes 12 tienen reservas |
| S(customer_id, bookings) | 15,2 → 16 | `TR / V = 13 992 / 920 = 15,21`, redondeado a 16 tuplas |
| Fracción con `status = 'CONFIRMADA'` | 40 % | Supuesto B3: 40 % confirmadas, 35 % completadas, 15 % canceladas, 10 % reprogramadas |
| Índice `idx_bookings_customer` | L_I = 22 bytes, d = 186, **H_I = 2** | Cálculo en 2.2.2 |

**Supuestos propios de esta sección:** B1 (M = 10), B2 (todos los clientes tienen reservas) y B3 (distribución de estados). Con otros valores cambian las cifras, no el método.

#### 2.2.1 Longitud de la tupla de `servicios`

Mismo método de la sección 1.5. `servicios` tiene 9 campos: `id` (16), `duracion_minutos` (4), `created_at` y `updated_at` (8 + 8) son fijos; `nombre`, `descripcion`, `categoria`, `precio` (NUMERIC, longitud variable) y `estado` son variables.

```
Fijos          = 16 + 4 + 8 + 8 = 36
Variables (5)  = 4 · 5 = 20
Mapa de bits   = ⌈9 / 8⌉ = 2
Contenido var. = 25 (nombre) + 100 (descripción) + 12 (categoría) + 8 (precio) + 7 (estado) = 152
L = 20 + 36 + 2 + 152 = 210 bytes
```

#### 2.2.2 Índice `idx_bookings_customer`

```
L_I  = 16 (customer_id) + 6 (puntero) = 22 bytes
FR_I = ⌊8192 / 22⌋ = 372 entradas por nodo
d    = (372 + 1) / 2 → 186
H_I ≤ log_186(920) = ln 920 / ln 186 = 6,824 / 5,226 = 1,31  →  H_I = 2
```

### 2.3 Fórmulas aplicadas y por qué

| Operación | Fórmula de referencia | Por qué esa fórmula |
|---|---|---|
| Selección `customer_id = :cliente` con índice | Secundario: `H_I + S(a,R)` | `customer_id` no es único (un cliente tiene muchas reservas) y el índice no ordena la tabla: en el peor caso cada reserva está en una página distinta, por eso se suma `S(a,R)` |
| Selección con búsqueda lineal (alternativa) | Peor caso: `BR` | Como la igualdad no es sobre una clave, hay que recorrer toda la tabla (el promedio `⌈BR/2⌉` solo vale cuando se detiene en el primer acierto) |
| Segundo predicado `status = 'CONFIRMADA'` | Conjunción: `Tuplas = TR · s1 · s2`, con `s_i = S(a_i,R) / TR` | Se aplica en memoria sobre las tuplas ya leídas; estima cuántas quedan |
| Reunión con `servicios` | Hash join en memoria: `BR' + BS` (equivalente a nested-loop: `BR' + BS · ⌈BR' / (M − 2)⌉`) | La relación pequeña (`servicios`, 2 páginas) cabe en memoria, así que cada relación se lee una sola vez |
| Tamaño de la salida de `R ⋈ S` | Si `b` es clave de `S`: `≤ TR` | `servicios.id` es clave primaria, cada reserva une con exactamente un servicio |

### 2.4 Plan elegido (Plan 1): selección por índice y luego reunión

**Paso 1. Selección con el índice `idx_bookings_customer`.**

```
Costo = H_I + S(a,R) = 2 + 16 = 18 páginas
```

**Paso 2. Tuplas que sobreviven al segundo predicado** (se evalúa en memoria sobre las 16 tuplas leídas, sin E/S adicional):

```
s1 = S(customer_id,R) / TR = 15,21 / 13 992 = 1/920
s2 = 0,40
Tuplas = TR · s1 · s2 = 13 992 · (1/920) · 0,40 = 6,08 ≈ 7 tuplas
```

Esas 7 tuplas de 130 bytes ocupan 910 bytes: `BR' = ⌈910 / 8192⌉ = 1` página.

**Paso 3. Reunión con `servicios` mediante hash join en memoria.** La relación pequeña (`servicios`, BS = 2 < M = 10) se carga en memoria:

```
Costo = BR' + BS = 1 + 2 = 3 páginas
```

Con nested-loop daría lo mismo: `BR' + BS · ⌈BR' / (M − 2)⌉ = 1 + 2 · ⌈1/8⌉ = 3`.

**Paso 4. Tamaño de la salida.** Como `servicios.id` es clave, la salida es `≤ 7` tuplas.

**Costo total del Plan 1:**

```
18 + 3 = 21 páginas de E/S
```

### 2.5 Alternativas de ejecución

**Plan 2: selección por búsqueda lineal (sin índice) y luego reunión.**

```
Selección lineal = BR = 230 páginas
Reunión (hash join en memoria) = BR' + BS = 1 + 2 = 3 páginas
Total = 230 + 3 = 233 páginas
```

**Plan 3: reunión primero y selección después.** Se une toda `bookings` con `servicios` y luego se filtra:

```
Hash join en memoria        = BR + BS = 230 + 2 = 232 páginas
Nested-loop (bookings externa) = BR + BS · ⌈BR / (M − 2)⌉ = 230 + 2 · ⌈230/8⌉ = 288 páginas
Nested-loop (servicios externa) = BS + BR · ⌈BS / (M − 2)⌉ = 2 + 230 · 1 = 232 páginas
```

La mejor variante cuesta **232 páginas** y además genera un resultado intermedio de 13 992 tuplas que luego se descarta casi por completo.

**Plan 1b (descartado): intersección de dos índices** (`customer_id` y `status`). La fórmula de conjunción `Σ H_I + tuplas leídas` daría `2 + 1 + 7 = 10`, pero subestima el costo real: el índice de `status` tiene solo 4 valores y devolvería ≈ 5 597 punteros (40 % de la tabla) que habría que leer y cruzar. Por eso el Plan 1 usa solo el índice selectivo, y el segundo filtro se aplica en memoria.

### 2.6 Comparación

| Plan | Estrategia | Páginas de E/S | Veces el Plan 1 |
|---|---|---:|---:|
| **1** | Índice por `customer_id` + hash join | **21** | 1× |
| 2 | Lectura lineal + hash join | 233 | ≈ 11× |
| 3 | Reunión primero + selección | 232 | ≈ 11× |

**Conclusión.** Aplicar la selección antes de la reunión y usar el índice por cliente reduce el costo de 232 a 21 páginas (**≈ 91 % menos**). La ventaja viene de dos decisiones: filtrar temprano (solo 7 tuplas llegan a la reunión en lugar de 13 992) y usar `idx_bookings_customer`, que ya existe en el esquema.

### 2.7 Verificación con `EXPLAIN (ANALYZE, BUFFERS)`

Se cargó en PostgreSQL una réplica con 13 992 reservas, 920 clientes y 42 servicios, y se ejecutó la consulta:

| Concepto | Modelo | PostgreSQL real |
|---|---:|---:|
| Páginas del índice leídas (H_I) | 2 | 2 |
| Páginas de `bookings` leídas | 16 | 16 |
| Filas que cumplen ambos predicados | ≈ 6 (6,08) | 6 |
| Páginas de `servicios` leídas | 2 | 2 |
| **Total Plan 1** | **21** | **20** |
| **Total sin índices (Plan 2)** | **233** | **257** |

Las cifras coinciden en estructura. PostgreSQL eligió por sí solo un plan equivalente al Plan 1 (índice por cliente y hash join). La diferencia de 1 página en el Plan 1 viene de que el modelo cuenta 1 página para las 7 tuplas intermedias, mientras PostgreSQL las mantiene en memoria. La diferencia de 24 páginas en el Plan 2 viene de que la tabla real ocupa 255 páginas y no 230 (en esta réplica las reservas no llevan motivo de cancelación, por eso son 255 y no las 269 de la sección 1.10; en ambos casos el encabezado de cada registro que PostgreSQL añade explica el exceso sobre el modelo).

---

## 3. Optimización algebraica de una consulta

Se usa la **misma consulta de la sección 2** (S2-4 simplificada), para que el resultado algebraico se conecte con el costo en páginas ya calculado.

### 3.1 SQL original

```sql
SELECT b.start_time, b.end_time, s.nombre
FROM bookings b
JOIN servicios s ON s.id = b.service_id
WHERE b.customer_id = :cliente
  AND b.status = 'CONFIRMADA';
```

### 3.2 Expresión algebraica inicial

Traducción directa del SQL: primero la reunión de las dos tablas completas, luego la selección y al final la proyección.

```
π start_time, end_time, nombre (
    σ customer_id = :c  ∧  status = 'CONFIRMADA' (
        bookings  ⋈ service_id = id  servicios
    )
)
```

Notación: `π` proyección, `σ` selección, `⋈` reunión. Los predicados `customer_id` y `status` usan solo atributos de `bookings`; `nombre` es el único atributo de `servicios` que sale en el resultado.

### 3.3 Transformaciones, una por una

**Heurística general:** aplicar selecciones y proyecciones lo antes posible (hacia las hojas del árbol), antes de las reuniones.

**T1. Ley 2 (selección conjunta):** `σ p1∧p2 (E) ≡ σ p1 (σ p2 (E))`. Se separa la conjunción en dos selecciones en cascada para poder moverlas por separado:

```
π ...( σ customer_id=:c ( σ status='CONFIRMADA' ( bookings ⋈ servicios ) ) )
```

**T2. Leyes 4 y 5 (selección sobre una reunión):** `σ p (E1 ⋈ E2) ≡ σ p1 (E1) ⋈ σ p2 (E2)`, si `p1` usa solo atributos de `E1` y `p2` solo de `E2`. Los dos predicados usan solo atributos de `bookings` (`E1`) y ninguno de `servicios` (`p2` = verdadero), así que ambas selecciones bajan hasta `bookings`, antes de la reunión:

```
π ...( σ customer_id=:c ( σ status='CONFIRMADA' ( bookings ) )  ⋈  servicios )
```

**T3. Ley 2 otra vez (orden de las selecciones):** como `σ p1 (σ p2 (E)) ≡ σ p2 (σ p1 (E))`, se aplica primero `customer_id`, el predicado más selectivo (1 de cada 920 reservas) y el que usa el índice `idx_bookings_customer`:

```
σ status='CONFIRMADA' ( σ customer_id=:c ( bookings ) )
```

**T4. Ley 9 (proyección sobre una reunión) y Ley 3:** `π x,y (E1 ⋈ E2) ≡ π x (E1) ⋈ π y (E2)`, si `x` pertenece a `E1` y `y` a `E2` e incluyen los atributos de la reunión.

- De `servicios` solo se necesitan `id` (atributo de la reunión) y `nombre`: `π id, nombre (servicios)`.
- De `bookings` solo se necesitan `start_time`, `end_time` y `service_id` (atributo de la reunión). La proyección se coloca **después** de las selecciones y no antes. La Ley 3 (`π x (σ p (E)) ≡ σ p (π x (E))`) exige que `p` use solo atributos de `x`, y aquí `p` usa `customer_id` y `status`, que no están en `x`. Subir la proyección por debajo de la selección eliminaría columnas que la selección todavía necesita.

```
π start_time, end_time, service_id ( σ status ( σ customer_id ( bookings ) ) )
⋈ service_id = id
π id, nombre ( servicios )
```

**T5. Ley 8 (proyecciones en cascada):** `π x (π y (E)) ≡ π x (E)`, si `x ⊆ y`. La proyección final `π start_time, end_time, nombre` se aplica sobre una reunión que ya trae `service_id` e `id` de más; se mantiene solo la proyección externa, que descarta esas columnas sobrantes.

**T6. Leyes 11 y 12 (orden de las reuniones):** `E1 ⋈ E2 ≡ E2 ⋈ E1`. Con solo dos relaciones no hay reordenamiento de reuniones que optimizar, pero la conmutatividad permite poner la relación pequeña (`servicios`, 42 tuplas) como lado que se carga en memoria (hash join) o como relación interna, que es lo que se usa en la sección 2.

### 3.4 Expresión optimizada

```
π start_time, end_time, nombre (
      π start_time, end_time, service_id (
          σ status = 'CONFIRMADA' ( σ customer_id = :c ( bookings ) )
      )
      ⋈ service_id = id
      π id, nombre ( servicios )
)
```

### 3.5 Por qué es más barata

Tuplas y bytes intermedios con las estadísticas de la sección 2 (`bookings`: 13 992 tuplas de 130 bytes; `servicios`: 42 tuplas de 210 bytes):

| Paso | Expresión inicial | Expresión optimizada |
|---|---|---|
| Resultado de la reunión (el mayor intermedio) | `bookings ⋈ servicios`: **13 992 tuplas × 340 bytes ≈ 4,54 MiB** | No se materializa una reunión de tablas completas |
| Tras `σ customer_id` | — | 16 tuplas × 130 bytes = 2 080 bytes |
| Tras `σ status` | ≈ 7 tuplas (al final) | ≈ 7 tuplas (6,08) |
| `π` de `bookings` | — | 7 tuplas × 32 bytes = 224 bytes |
| `π` de `servicios` | — | 42 tuplas × 41 bytes = 1 722 bytes |
| Reunión | 13 992 tuplas de entrada | 7 tuplas contra 42 → ≈ 7 tuplas × 73 bytes = 511 bytes |
| **Mayor resultado intermedio** | **4 757 280 bytes** | **2 080 bytes** |

- **Tuplas que llegan a la reunión:** de 13 992 a 7 en el lado de `bookings`. La reunión deja de procesar casi 14 000 filas que se descartan después.
- **Tamaño del mayor intermedio:** de ≈ 4,54 MiB a ≈ 2 KiB, unas **2 300 veces menos** (4 757 280 / 2 080 ≈ 2 287).
- **Tuplas más angostas:** las proyecciones tempranas reducen cada tupla que viaja a la reunión de 340 a 73 bytes.
- **Costo en páginas de E/S** (sección 2): la expresión inicial se ejecuta leyendo toda la tabla, 232 páginas. La optimizada permite usar `idx_bookings_customer` y cuesta 21 páginas, cerca de **91 % menos**.

### 3.6 Verificación

Se ejecutaron ambas formas sobre la réplica de PostgreSQL (13 992 reservas, 920 clientes, 42 servicios):

| Comprobación | Resultado |
|---|---|
| Tuplas de `bookings ⋈ servicios` | 13 992 |
| Tuplas tras `σ customer_id` | 16 |
| Tuplas tras `σ customer_id ∧ status` | 6 (el modelo estima 6,08) |
| Filas que están en la forma original y no en la optimizada (`EXCEPT`) | 0 |
| Filas que están en la forma optimizada y no en la original (`EXCEPT`) | 0 |

Ambas expresiones devuelven exactamente las mismas 6 filas, lo que confirma que las transformaciones son equivalencias y no cambian el resultado. El plan que PostgreSQL eligió solo (sección 2.7: filtro sobre `bookings` por debajo de la reunión) aplica la misma idea: el optimizador del motor realiza estas equivalencias automáticamente.
