-- Tienda La Esquina · Base de datos para la actividad de agentes locales
-- Ejecutar dentro de la base "tienda" 

DROP TABLE IF EXISTS movimientos;
DROP TABLE IF EXISTS solicitudes;
DROP TABLE IF EXISTS productos;

-- Catálogo e inventario
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    nombre TEXT NOT NULL UNIQUE,
    categoria TEXT NOT NULL,
    precio INTEGER NOT NULL CHECK (precio > 0), -- pesos colombianos
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    stock_minimo INTEGER NOT NULL DEFAULT 5
);

-- Entradas y salidas de mercancía (Parte 2)
CREATE TABLE movimientos (
    id SERIAL PRIMARY KEY,
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    tipo TEXT NOT NULL CHECK (tipo IN ('entrada', 'salida')),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    nota TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Solicitudes de clientes clasificadas por el agente (Parte 1)
CREATE TABLE solicitudes (
    id SERIAL PRIMARY KEY,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    cliente TEXT NOT NULL,
    contacto TEXT,
    mensaje TEXT NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('pedido', 'queja', 'pregunta', 'otro')),
    urgencia TEXT NOT NULL CHECK (urgencia IN ('alta', 'media', 'baja')),
    producto TEXT,
    resumen TEXT NOT NULL,
    respuesta_borrador TEXT NOT NULL,
    estado TEXT NOT NULL DEFAULT 'pendiente'
);

INSERT INTO productos (nombre, categoria, precio, stock, stock_minimo) VALUES
    ('Arroz 500 g', 'Granos', 2900, 40, 10),
    ('Aceite 1 L', 'Despensa', 11500, 12, 5),
    ('Azúcar 1 kg', 'Despensa', 4800, 20, 8),
    ('Panela 500 g', 'Despensa', 3200, 2, 6),
    ('Café molido 250 g', 'Despensa', 9800, 9, 4),
    ('Huevos cubeta x30', 'Lácteos y huevos', 17500, 3, 5),
    ('Leche entera 1 L', 'Lácteos y huevos', 4600, 18, 10),
    ('Queso costeño 500 g', 'Lácteos y huevos', 12000, 7, 4),
    ('Pan tajado', 'Panadería', 6500, 10, 5),
    ('Bollo de yuca', 'Panadería', 2500, 15, 8),
    ('Gaseosa 1.5 L', 'Bebidas', 5200, 4, 10),
    ('Agua 600 ml', 'Bebidas', 1800, 30, 12),
    ('Jabón en barra', 'Aseo', 3500, 14, 6),
    ('Papel higiénico x4', 'Aseo', 7900, 8, 5);
