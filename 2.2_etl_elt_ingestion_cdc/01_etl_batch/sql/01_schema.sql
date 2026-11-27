CREATE TABLE IF NOT EXISTS etl_sales (
    order_id text NOT NULL,
    line_number smallint NOT NULL CHECK (line_number > 0),
    sold_at timestamptz NOT NULL,
    customer_id text NOT NULL,
    product_id text NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
    sales_amount numeric(14, 2)
        GENERATED ALWAYS AS ((quantity * unit_price)::numeric(14, 2)) STORED,
    PRIMARY KEY (order_id, line_number)
);
