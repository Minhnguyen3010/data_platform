INSERT INTO analytics.sales_mart (
    order_id,
    line_number,
    sold_at,
    customer_id,
    product_id,
    quantity,
    unit_price,
    discount,
    sales_amount
)
SELECT
    payload ->> 'order_id',
    (payload ->> 'line_number')::smallint,
    (payload ->> 'sold_at')::timestamptz,
    upper(payload ->> 'customer_id'),
    upper(payload ->> 'product_id'),
    (payload ->> 'quantity')::integer,
    (payload ->> 'unit_price')::numeric(12, 2),
    coalesce(nullif(payload ->> 'discount', '')::numeric(12, 2), 0),
    (
        (payload ->> 'quantity')::numeric
        * (payload ->> 'unit_price')::numeric
        - coalesce(nullif(payload ->> 'discount', '')::numeric, 0)
    )::numeric(14, 2)
FROM raw.sales_events
ON CONFLICT (order_id, line_number) DO UPDATE
SET sold_at = EXCLUDED.sold_at,
    customer_id = EXCLUDED.customer_id,
    product_id = EXCLUDED.product_id,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    discount = EXCLUDED.discount,
    sales_amount = EXCLUDED.sales_amount;
