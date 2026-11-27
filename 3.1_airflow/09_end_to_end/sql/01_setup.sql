CREATE TABLE IF NOT EXISTS bronze_orders (
    order_id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    amount REAL NOT NULL CHECK (amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('COMPLETED', 'CANCELLED'))
);

CREATE TABLE IF NOT EXISTS gold_daily_sales (
    sales_date TEXT PRIMARY KEY,
    order_count INTEGER NOT NULL CHECK (order_count >= 0),
    gross_amount REAL NOT NULL CHECK (gross_amount >= 0),
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
