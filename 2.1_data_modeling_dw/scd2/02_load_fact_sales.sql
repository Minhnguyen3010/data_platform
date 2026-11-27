DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM stg_sales AS s
        WHERE NOT EXISTS (
            SELECT 1
            FROM dim_date AS d
            WHERE d.calendar_date = s.sale_date
        )
           OR NOT EXISTS (
            SELECT 1
            FROM dim_product AS p
            WHERE p.product_id = s.product_id
        )
           OR (
            SELECT count(*)
            FROM dim_customer AS c
            WHERE c.customer_id = s.customer_id
              AND s.sale_date >= c.valid_from
              AND s.sale_date < c.valid_to
        ) <> 1
    ) THEN
        RAISE EXCEPTION
            'Staged sales contain a missing dimension key or ambiguous customer version';
    END IF;
END
$$;

INSERT INTO fact_sales (
    source_order_id,
    source_line_number,
    date_key,
    customer_sk,
    product_sk,
    quantity,
    unit_price
)
SELECT
    s.source_order_id,
    s.source_line_number,
    d.date_key,
    c.customer_sk,
    p.product_sk,
    s.quantity,
    s.unit_price
FROM stg_sales AS s
JOIN dim_date AS d
  ON d.calendar_date = s.sale_date
JOIN dim_customer AS c
  ON c.customer_id = s.customer_id
 AND s.sale_date >= c.valid_from
 AND s.sale_date < c.valid_to
JOIN dim_product AS p
  ON p.product_id = s.product_id
ON CONFLICT (source_order_id, source_line_number) DO UPDATE
SET date_key = EXCLUDED.date_key,
    customer_sk = EXCLUDED.customer_sk,
    product_sk = EXCLUDED.product_sk,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price;
