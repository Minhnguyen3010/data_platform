DO $$
DECLARE
    raw_checksum text;
    mart_checksum text;
BEGIN
    IF (SELECT count(*) FROM analytics.sales_mart) <> 2 THEN
        RAISE EXCEPTION 'Expected two transformed sales rows';
    END IF;

    IF (SELECT sum(sales_amount) FROM analytics.sales_mart) <> 122.50 THEN
        RAISE EXCEPTION 'Unexpected sales total after applying optional discount';
    END IF;

    SELECT md5(coalesce(string_agg(
        concat_ws(
            '|',
            payload ->> 'order_id',
            (payload ->> 'line_number')::smallint::text,
            (payload ->> 'sold_at')::timestamptz::text,
            upper(payload ->> 'customer_id'),
            upper(payload ->> 'product_id'),
            (payload ->> 'quantity')::integer::text,
            (payload ->> 'unit_price')::numeric(12, 2)::text,
            coalesce(nullif(payload ->> 'discount', '')::numeric(12, 2), 0)::text,
            (
                (payload ->> 'quantity')::numeric
                * (payload ->> 'unit_price')::numeric
                - coalesce(nullif(payload ->> 'discount', '')::numeric, 0)
            )::numeric(14, 2)::text
        ),
        E'\n' ORDER BY payload ->> 'order_id', (payload ->> 'line_number')::smallint
    ), ''))
    INTO raw_checksum
    FROM raw.sales_events;

    SELECT md5(coalesce(string_agg(
        concat_ws(
            '|',
            order_id,
            line_number::text,
            sold_at::text,
            customer_id,
            product_id,
            quantity::text,
            unit_price::text,
            discount::text,
            sales_amount::text
        ),
        E'\n' ORDER BY order_id, line_number
    ), ''))
    INTO mart_checksum
    FROM analytics.sales_mart;

    IF raw_checksum IS DISTINCT FROM mart_checksum THEN
        RAISE EXCEPTION 'Raw source and sales mart checksums do not match';
    END IF;
END
$$;

SELECT order_id, line_number, discount, sales_amount
FROM analytics.sales_mart
ORDER BY order_id, line_number;
