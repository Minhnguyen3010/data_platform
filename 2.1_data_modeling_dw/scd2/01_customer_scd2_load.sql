BEGIN;

LOCK TABLE dim_customer IN SHARE ROW EXCLUSIVE MODE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM stg_customer_snapshot AS s
        JOIN dim_customer AS c
          ON c.customer_id = s.customer_id
         AND c.is_current
        WHERE (c.first_name, c.last_name, c.address_line, c.city, c.region)
              IS DISTINCT FROM
              (s.first_name, s.last_name, s.address_line, s.city, s.region)
          AND s.effective_date <= c.valid_from
    ) THEN
        RAISE EXCEPTION
            'SCD2 effective_date must be later than the current version valid_from';
    END IF;
END
$$;

UPDATE dim_customer AS c
SET valid_to = s.effective_date,
    is_current = false
FROM stg_customer_snapshot AS s
WHERE c.customer_id = s.customer_id
  AND c.is_current
  AND s.effective_date > c.valid_from
  AND (c.first_name, c.last_name, c.address_line, c.city, c.region)
      IS DISTINCT FROM
      (s.first_name, s.last_name, s.address_line, s.city, s.region);

INSERT INTO dim_customer (
    customer_id,
    first_name,
    last_name,
    address_line,
    city,
    region,
    valid_from,
    valid_to,
    is_current
)
SELECT
    s.customer_id,
    s.first_name,
    s.last_name,
    s.address_line,
    s.city,
    s.region,
    s.effective_date,
    DATE '9999-12-31',
    true
FROM stg_customer_snapshot AS s
LEFT JOIN dim_customer AS c
  ON c.customer_id = s.customer_id
 AND c.is_current
WHERE c.customer_sk IS NULL;

COMMIT;
