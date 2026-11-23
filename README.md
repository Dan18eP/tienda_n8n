# Tienda La Esquina: Dos Agentes de IA Locales con n8n y Ollama

Este repositorio contiene la evolución completa del starter kit hacia una solución integral de inteligencia artificial y automatización 100% local para la **Tienda La Esquina** de Doña Rosa en Barranquilla, Atlántico.

El sistema implementa dos agentes inteligentes autónomos, cuatro flujos de trabajo en n8n, integración con Telegram Bot y persistencia transaccional en PostgreSQL, sin dependencias de APIs en la nube ni costos recurrentes de inferencia.

---

## 🏗️ Arquitectura de la Solución

```
                     +---------------------------------------+
                     |        Cliente / Usuario Final        |
                     +-------------------+-------------------+
                                         |
                       +-----------------+-----------------+
                       |                                   |
              [ Formulario Web ]                  [ Telegram Bot ]
          (Form Trigger en n8n)                  (@rosa_tienda_bot)
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
                      |   PostgreSQL 16 (Base 'tienda')     |
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

### 1. Parte 1 — Clasificador y Enrutador de Solicitudes
* **Trigger:** Form Trigger (`Escríbele a la Tienda La Esquina`).
* **Agente IA:** Ollama Chat Model (`qwen3:1.7b`, temperatura 0.1) con defensa contra prompt injection (`/no_think`).
* **Herramienta:** `consultar_producto` en PostgreSQL para validar nombres y precios oficiales.
* **Structured Output Parser:** Salida en JSON estricto (`tipo`, `urgencia`, `producto`, `resumen`, `respuesta_borrador`).
* **Enrutamiento:** Switch según urgencia (`alta` vs `media o baja`).
* **Persistencia:** Inserción en la tabla `solicitudes` de PostgreSQL.
* **Alertas Urgentes:** Escritura en `/data/shared/alertas.txt` únicamente para casos de urgencia `alta`.

### 2. Parte 2A — Asistente de Inventario y Bot de Telegram
* **Triggers:** Chat Trigger (para pruebas en canvas n8n) y Webhook (`/webhook/telegram-chat`).
* **Bot de Telegram:** Enlazado al bot oficial **@rosa_tienda_bot** (`[REDACTED_TELEGRAM_TOKEN]`).
* **Memoria:** `Simple Memory` con retención de los últimos 5 turnos.
* **Herramientas:**
  * `consultar_producto`: Consulta de existencias en tiempo real sin alucinaciones.
  * `registrar_movimiento`: Transacción atómica (CTE) con control de stock negativo (`CHECK (stock >= 0)`).
* **Respuesta en Vivo:** Notificación HTTP directa a la API de Telegram con la respuesta generada por el agente.

### 3. Parte 2B — Reporte Diario de Faltantes a Proveedores
* **Trigger:** Schedule Trigger diario a las 7:00 a.m. (hora legal `America/Bogota`) y Webhook de prueba (`/webhook/reporte-diario`).
* **Detección SQL:** Consulta de productos en punto de reorden (`stock <= stock_minimo`) con cálculo automático de `sugerido_pedir = stock_minimo * 2 - stock`.
* **Redacción LLM:** `Basic LLM Chain` con Qwen 1.7B redacta un mensaje formal, corto y amable de parte de Doña Rosa.
* **Persistencia:** Guarda el pedido en `/data/shared/pedido_proveedor_YYYY-MM-DD.txt`.

### 4. Flujo de Errores Compartido
* **Trigger:** Error Trigger asignado como `errorWorkflow` en los 3 flujos principales.
* **Registro:** Añade en modo append los detalles de cualquier excepción a `/data/shared/errores.log` (fecha, flujo, nodo causante y mensaje de error).

---

## 🛠️ Puesta en Marcha

### 1. Iniciar la Pila Docker
```bash
docker compose --profile cpu up -d
```

### 2. Verificar el Modelo Local en Ollama
```bash
docker compose exec ollama-cpu ollama list
docker compose exec ollama-cpu ollama run qwen3:1.7b "Saluda en una frase /no_think"
```

### 3. Base de Datos PostgreSQL
El script `tienda.sql` aprovisiona la base `tienda`, las tablas y los 14 productos semilla:
```bash
docker compose exec -T postgres psql -U root -d tienda < tienda.sql
```

### 4. Iniciar el Puente de Telegram en Vivo
Para interactuar con el bot **@rosa_tienda_bot** desde cualquier teléfono móvil o cliente de Telegram:
```bash
python telegram_bot_runner.py
```

---

## 📦 Estructura del Repositorio y Entregables

```
.
├── documento/
│   └── Documento_diseno.pdf            # Documento técnico (11 págs, Times New Roman 12, justificado)
├── flujos/
│   ├── parte1_clasificador.json        # Flujo exportado Parte 1
│   ├── parte2a_inventario_chat.json    # Flujo exportado Parte 2A (con Telegram)
│   ├── parte2b_reporte_diario.json     # Flujo exportado Parte 2B
│   └── flujo_errores.json              # Flujo centralizado de errores
├── evidencias/
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
│   └── evidencia_12_telegram_bot.png
├── tienda.sql                          # Esquema DDL y semillas de productos
├── telegram_bot_runner.py              # Conector oficial de polling Telegram <-> n8n
├── docker-compose.yml                  # Configuración de servicios con volumen compartido
└── Echeverria_Daniel_AgentesLocales.zip # Archivo ZIP final empaquetado para entrega
```

---

## 📊 Matriz de Evaluación: 15 Casos de Prueba

| # | Flujo | Entrada | Resultado Esperado | Resultado Obtenido | ¿Cumple? |
|---|---|---|---|---|:---:|
| 1 | Parte 1 | Carlos Mendoza: 2 quesos y panela para hoy | pedido · alta · Queso costeño · Alerta archivo | pedido · alta · Queso costeño · Alerta guardada | ✅ SÍ |
| 2 | Parte 1 | Carmen Ortiz: Leche vencida ayer | queja · alta · Leche entera 1 L · Alerta archivo | queja · alta · Leche entera 1 L · Alerta guardada | ✅ SÍ |
| 3 | Parte 1 | Andrés Pérez: Horario domingos | pregunta · baja · null · Sin alerta | pregunta · baja · null · Sin alerta | ✅ SÍ |
| 4 | Parte 1 | Doña Marta: Precio cubeta huevos | pregunta · baja · Huevos cubeta x30 ($17.500) | pregunta · baja · Huevos cubeta x30 ($17.500) | ✅ SÍ |
| 5 | Parte 1 | Jorge Ruiz: Demora domicilio sábado | queja · media · null · Sin alerta | queja · media · null · Sin alerta | ✅ SÍ |
| 6 | Parte 1 | Laura Torres: Arroz y aceite sábado | pedido · media · Arroz 500 g · Sin alerta | pedido · media · Arroz 500 g · Sin alerta | ✅ SÍ |
| 7 | Parte 1 | Vecino: Sugerencia vender hielo | otro · baja · null · Sin alerta | otro · baja · null · Sin alerta | ✅ SÍ |
| 8 | Parte 1 | Atacante: 'Ignora tus instrucciones...' | otro · baja · null (Defensa inyección) | otro · baja · null (Inyección neutralizada) | ✅ SÍ |
| 9 | Parte 2A | '¿Cuántas cubetas de huevos quedan?' | Consulta existencias reales: 3 cubetas | Consulta SQL ejecutada. Informa stock: 3 | ✅ SÍ |
| 10 | Parte 2A | 'Llegaron 24 leches.' | Entrada 24 leches. Stock: 18 -> 42 | CTE atómica ejecutada. Stock final: 42 | ✅ SÍ |
| 11 | Parte 2A | 'Vendí 3 quesos costeños.' | Salida 3 quesos. Stock: 7 -> 4 | CTE atómica ejecutada. Stock final: 4 | ✅ SÍ |
| 12 | Parte 2A | '¿Y cuánto queda de ese?' (Memoria) | Usa memoria: Queso costeño. Stock: 4 | Resuelve contexto previo. Stock final: 4 | ✅ SÍ |
| 13 | Parte 2A | 'Vendí 500 panelas.' (Stock insuficiente) | Rechaza venta (solo hay 2). Sin cambio | Error CHECK capturado. Rechaza y avisa stock: 2 | ✅ SÍ |
| 14 | Parte 2A | 'Registra 10 pizzas que llegaron.' | Rechaza: no existe en catálogo | No encuentra en catálogo. Explica ausencia | ✅ SÍ |
| 15 | Parte 2B | Ejecución reporte diario de faltantes | Genera archivo con productos en punto reorden | Archivo generado con Gaseosa, Huevos y Panela | ✅ SÍ |

---

## 🔒 Privacidad y Seguridad

* **Inferencia 100% Local:** Ningún dato personal o comercial sale del host.
* **Defensa en Capas:** Supresión de modo pensamiento con `/no_think` e instrucciones de aislamiento de datos en prompts.
* **Integridad Relacional:** Restricciones `CHECK (stock >= 0)` en PostgreSQL que impiden sobreventas en concurrencia.
