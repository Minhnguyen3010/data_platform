INSERT INTO dim_date (
    date_key,
    calendar_date,
    day_of_month,
    day_of_week,
    month_number,
    month_name,
    quarter_number,
    year_number,
    is_weekend
)
SELECT
    to_char(d::date, 'YYYYMMDD')::integer,
    d::date,
    extract(day FROM d)::smallint,
    extract(isodow FROM d)::smallint,
    extract(month FROM d)::smallint,
    to_char(d::date, 'FMMonth'),
    extract(quarter FROM d)::smallint,
    extract(year FROM d)::integer,
    extract(isodow FROM d) IN (6, 7)
FROM generate_series(DATE '2024-01-01', DATE '2024-12-31', INTERVAL '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO dim_customer (
    customer_id,
    first_name,
    last_name,
    address_line,
    city,
    region,
    valid_from
)
SELECT
    seed.customer_id,
    seed.first_name,
    seed.last_name,
    seed.address_line,
    seed.city,
    seed.region,
    DATE '2024-01-01'
FROM (
    VALUES
        ('C001', 'An', 'Nguyen', '10 Oak Street', 'Harbor City', 'North'),
        ('C002', 'Binh', 'Tran', '25 River Road', 'Hill Town', 'South')
) AS seed(customer_id, first_name, last_name, address_line, city, region)
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_customer AS existing
    WHERE existing.customer_id = seed.customer_id
);

INSERT INTO dim_product (product_id, product_name, category)
VALUES
    ('P001', 'Coffee Maker', 'Appliances'),
    ('P002', 'Travel Mug', 'Accessories')
ON CONFLICT (product_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS stg_customer_snapshot (
    customer_id text NOT NULL,
    effective_date date NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    address_line text NOT NULL,
    city text NOT NULL,
    region text NOT NULL,
    PRIMARY KEY (customer_id)
);

INSERT INTO stg_customer_snapshot (
    customer_id,
    effective_date,
    first_name,
    last_name,
    address_line,
    city,
    region
)
VALUES
    ('C001', DATE '2024-07-01', 'An', 'Nguyen', '88 Pine Avenue', 'Lake City', 'Central'),
    ('C002', DATE '2024-07-01', 'Binh', 'Tran', '25 River Road', 'Hill Town', 'South')
ON CONFLICT (customer_id) DO UPDATE
SET first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    address_line = EXCLUDED.address_line,
    city = EXCLUDED.city,
    region = EXCLUDED.region,
    effective_date = EXCLUDED.effective_date;

CREATE TABLE IF NOT EXISTS stg_sales (
    source_order_id text NOT NULL,
    source_line_number smallint NOT NULL CHECK (source_line_number > 0),
    sale_date date NOT NULL,
    customer_id text NOT NULL,
    product_id text NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (source_order_id, source_line_number)
);

INSERT INTO stg_sales (
    source_order_id,
    source_line_number,
    sale_date,
    customer_id,
    product_id,
    quantity,
    unit_price
)
VALUES
    ('O1001', 1, DATE '2024-03-15', 'C001', 'P001', 2, 45.00),
    ('O1002', 1, DATE '2024-08-20', 'C001', 'P002', 3, 12.50),
    ('O1003', 1, DATE '2024-09-05', 'C002', 'P001', 1, 45.00)
ON CONFLICT (source_order_id, source_line_number) DO UPDATE
SET sale_date = EXCLUDED.sale_date,
    customer_id = EXCLUDED.customer_id,
    product_id = EXCLUDED.product_id,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price;
