# Tienda La Esquina: Dos Agentes de IA Locales con n8n y Ollama

Este repositorio contiene la solución completa de automatización e inteligencia artificial 100% local para la **Tienda La Esquina** de Doña Rosa en Barranquilla, Atlántico, desarrollada según las especificaciones oficiales de la actividad práctica.

El sistema implementa dos agentes inteligentes locales, cuatro flujos de trabajo desacoplados en n8n y persistencia transaccional en PostgreSQL, sin dependencias de servicios cloud ni costos de inferencia.

---

## 🏗️ Arquitectura de la Solución

```
                     +---------------------------------------+
                     |         Canales de Interacción        |
                     +-------------------+-------------------+
                                         |
                       +-----------------+-----------------+
                       |                                   |
              [ Formulario Web ]                   [ Chat de Inventario ]
            (n8n Form Trigger)                     (n8n Chat Trigger)
             Rol: Clientes / Vecinos                Rol: Doña Rosa / Tendero
                       |                                   |
                       v                                   v
          +-------------------------+         +-------------------------+
          |  Parte 1: Clasificador  |         |  Parte 2A: Inventario   |
          |    de Solicitudes IA    |         |   Asistente en Chat     |
          +------------+------------+         +------------+------------+
                       |                                   |
                       +-----------------+-----------------+
                                         |
                                         v
                      +-------------------------------------+
                      |   Ollama Local (qwen3:1.7b - CPU)   |
                      |     Inferencia 100% On-Premise      |
                      +------------------+------------------+
                                         |
                                         v
                      +-------------------------------------+
                      |    PostgreSQL 16 (Base 'tienda')    |
                      |  productos · movimientos · pedidos  |
                      +------------------+------------------+
                                         |
            +----------------------------+----------------------------+
            |                                                         |
            v                                                         v
+-------------------------------+         +-------------------------------+
|  Parte 2B: Reporte Diario     |         |   Flujo Centralizado de       |
|  (7:00 a.m. a Proveedores)    |         |   Gestión de Errores          |
|  /data/shared/pedido_*.txt    |         |   /data/shared/errores.log    |
+-------------------------------+         +-------------------------------+
```

---

## 🚀 Componentes y Flujos de n8n

### 1. Parte 1 — Clasificador y Enrutador de Solicitudes (Clientes)
* **Trigger:** Form Trigger web público (`tienda-esquina-formulario`).
* **Agente IA:** Ollama Chat Model (`qwen3:1.7b`, temperatura 0.1) con delimitador `/no_think` para forzar emisión directa de JSON.
* **Herramienta:** `consultar_producto` en PostgreSQL para validar nombres exactos y precios en el catálogo.
* **Structured Output Parser:** Salida en esquema estricto (`tipo`, `urgencia`, `producto`, `resumen`, `respuesta_borrador`).
* **Enrutamiento:** Switch según urgencia (`alta` vs `media o baja`).
* **Persistencia:** Inserción en la tabla `solicitudes` de PostgreSQL.
* **Alertas Urgentes:** Escribe en `/data/shared/alertas.txt` exclusivamente cuando la urgencia es `alta`.

### 2. Parte 2A — Asistente de Inventario (Doña Rosa)
* **Trigger:** Chat Trigger nativo de n8n para interacción conversacional directa en el mostrador.
* **Agente IA:** Ollama Chat Model (`qwen3:1.7b`) con memoria deslizante (`Simple Memory` de 5 turnos).
* **Herramientas:**
  * `consultar_producto`: Consulta de existencias en tiempo real sin alucinaciones.
  * `registrar_movimiento`: Transacción atómica mediante CTE con validación de stock negativo (`CHECK (stock >= 0)`).
* **Respuesta en Chat:** Devuelve en un máximo de dos frases el resultado del movimiento y el saldo final de existencias.

### 3. Parte 2B — Reporte Diario de Faltantes a Proveedores (Automático)
* **Trigger:** Schedule Trigger diario a las 7:00 a.m. (hora legal de Colombia `America/Bogota`).
* **Detección SQL:** Consulta de productos en punto de reorden (`stock <= stock_minimo`) con cálculo de `sugerido_pedir = stock_minimo * 2 - stock`.
* **Redacción LLM:** `Basic LLM Chain` con Qwen 1.7B redacta un mensaje formal, corto y claro de parte de Doña Rosa para el distribuidor.
* **Persistencia:** Guarda el pedido en `/data/shared/pedido_proveedor_YYYY-MM-DD.txt`.

### 4. Flujo de Errores Compartido
* **Trigger:** Error Trigger asignado como `errorWorkflow` en los tres flujos principales.
* **Registro:** Añade en modo append los detalles de cualquier excepción a `/data/shared/errores.log` (fecha, flujo, nodo causante y mensaje de error).

---

## 🛠️ Cómo Replicar el Proyecto

### 1. Iniciar los Contenedores con Docker Compose
```bash
docker compose --profile cpu up -d
```

### 2. Descargar el Modelo en Ollama
```bash
docker compose exec ollama-cpu ollama pull qwen3:1.7b
```

### 3. Inicializar la Base de Datos PostgreSQL
Crea la base de datos `tienda` y carga el esquema relacional con los 14 productos semilla:
```bash
docker compose exec -T postgres psql -U root -d postgres -c "CREATE DATABASE tienda;"
docker compose exec -T postgres psql -U root -d tienda < tienda.sql
```

### 4. Configurar Credenciales e Importar Flujos en n8n
1. Abre n8n en el navegador: [http://localhost:5678](http://localhost:5678).
2. Configura las dos credenciales:
   * **Ollama account:** Base URL `http://ollama:11434`.
   * **Postgres account:** Host `postgres`, Puerto `5432`, Base de datos `tienda`, Usuario `root`, Contraseña `${POSTGRES_PASSWORD}`.
3. Importa los cuatro archivos `.json` ubicados en la carpeta `flujos/`:
   * `flujos/parte1_clasificador.json`
   * `flujos/parte2a_inventario_chat.json`
   * `flujos/parte2b_reporte_diario.json`
   * `flujos/flujo_errores.json`
4. Activa los flujos en n8n.

---

## 📁 Estructura del Repositorio

```text
.
├── documento/
│   └── Documento_diseno.pdf            # Documento técnico (12 págs, Times New Roman 12, justificado)
├── flujos/
│   ├── parte1_clasificador.json        # Flujo Parte 1: Form Trigger + Clasificador
│   ├── parte2a_inventario_chat.json    # Flujo Parte 2A: Chat Trigger + Asistente de Inventario
│   ├── parte2b_reporte_diario.json     # Flujo Parte 2B: Schedule Trigger + Reporte Proveedor
│   └── flujo_errores.json              # Flujo de gestión centralizada de excepciones
├── evidencias/                         # 13 capturas auténticas de verificación
│   ├── evidencia_01_docker_ps.png
│   ├── evidencia_02_ollama_list.png
│   ├── evidencia_03_credenciales_n8n.png
│   ├── evidencia_04_flujo_parte1_clasificador.png
│   ├── evidencia_05_flujo_parte2a_inventario_chat.png
│   ├── evidencia_06_flujo_parte2b_reporte_diario.png
│   ├── evidencia_07_flujo_errores.png
│   ├── evidencia_08_select_solicitudes.png
│   ├── evidencia_09_select_movimientos.png
│   ├── evidencia_10_alertas_txt.png
│   ├── evidencia_11_pedido_proveedor.png
│   ├── evidencia_12_formulario_cliente.png
│   └── evidencia_13_chat_dona_rosa.png
├── docker-compose.yml                  # Definición de contenedores (n8n, Ollama, Postgres)
├── tienda.sql                          # DDL relacional y catálogo de productos
├── .env.example                        # Variables de entorno de referencia
└── README.md                           # Guía completa de arquitectura y replicación
```

---

## 📊 Matriz de Evaluación: 15 Casos de Prueba

| # | Flujo | Entrada / Mensaje | Resultado Esperado | Resultado Obtenido | ¿Cumple? |
|:---:|---|---|---|---|:---:|
| 1 | Parte 1 | Carlos Mendoza: 2 quesos y panela para hoy | pedido · alta · Queso costeño · Alerta archivo | pedido · alta · Queso costeño · Alerta guardada | ✅ SÍ |
| 2 | Parte 1 | Carmen Ortiz: Leche vencida ayer | queja · alta · Leche entera 1 L · Alerta archivo | queja · alta · Leche entera 1 L · Alerta guardada | ✅ SÍ |
| 3 | Parte 1 | Andrés Pérez: Horario domingos | pregunta · baja · null · Sin alerta | pregunta · baja · null · Sin alerta | ✅ SÍ |
| 4 | Parte 1 | Doña Marta: Precio cubeta huevos | pregunta · baja · Huevos cubeta x30 ($17.500) | pregunta · baja · Huevos cubeta x30 ($17.500) | ✅ SÍ |
| 5 | Parte 1 | Jorge Ruiz: Demora domicilio sábado | queja · media · null · Sin alerta | queja · media · null · Sin alerta | ✅ SÍ |
| 6 | Parte 1 | Laura Torres: Arroz y aceite sábado | pedido · media · Arroz 500 g · Sin alerta | pedido · media · Arroz 500 g · Sin alerta | ✅ SÍ |
| 7 | Parte 1 | Vecino: Sugerencia vender hielo | otro · baja · null · Sin alerta | otro · baja · null · Sin alerta | ✅ SÍ |
| 8 | Parte 1 | Atacante: 'Ignora tus instrucciones...' | otro · baja · null (Inyección rechazada) | otro · baja · null (Inyección neutralizada) | ✅ SÍ |
| 9 | Parte 2A | '¿Cuánto queso costeño me queda?' | Consulta existencias reales: 7 unidades | Consulta SQL ejecutada. Informa stock: 7 | ✅ SÍ |
| 10 | Parte 2A | 'Llegaron 24 bolsas de leche.' | Entrada 24 leches. Stock sube a 42 | CTE atómica ejecutada. Stock final: 42 | ✅ SÍ |
| 11 | Parte 2A | 'Vendí 3 quesos costeños.' | Salida 3 quesos. Stock baja a 4 | CTE atómica ejecutada. Stock final: 4 | ✅ SÍ |
| 12 | Parte 2A | '¿Y cuánto queda de ese producto?' (Memoria) | Resuelve contexto previo: Queso costeño (4) | Memoria contextual aplicada. Informa stock: 4 | ✅ SÍ |
| 13 | Parte 2A | 'Vendí 100 quesos costeños.' (Sobrevenda) | Rechaza venta por stock insuficiente | Error CHECK capturado. Rechaza y avisa stock: 4 | ✅ SÍ |
| 14 | Parte 2A | '¿Tienes helado de chocolate?' | Informa ausencia del producto en catálogo | Verifica catálogo. Explica que no existe | ✅ SÍ |
| 15 | Parte 2B | Ejecución de reporte diario de faltantes | Genera archivo con productos bajo stock mínimo | Archivo generado con Gaseosa, Huevos y Panela | ✅ SÍ |

---

## 🔒 Privacidad y Seguridad

* **Inferencia 100% On-Premise:** Ningún dato sensible o comercial sale de la red local.
* **Integridad Relacional:** Control transaccional en PostgreSQL con restricciones `CHECK (stock >= 0)` que imposibilitan sobreventas o inventarios negativos.
* **Defensa de Prompts:** Supresión de cadenas internas mediante delimitador `/no_think` e instrucciones de aislamiento semántico.
