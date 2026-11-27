CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS raw.sales_events (
    event_id text PRIMARY KEY,
    payload jsonb NOT NULL,
    ingested_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS analytics.sales_mart (
    order_id text NOT NULL,
    line_number smallint NOT NULL,
    sold_at timestamptz NOT NULL,
    customer_id text NOT NULL,
    product_id text NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12, 2) NOT NULL,
    discount numeric(12, 2) NOT NULL DEFAULT 0,
    sales_amount numeric(14, 2) NOT NULL,
    PRIMARY KEY (order_id, line_number)
);
