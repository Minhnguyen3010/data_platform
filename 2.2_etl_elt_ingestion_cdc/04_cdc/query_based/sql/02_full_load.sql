BEGIN;

TRUNCATE query_target.customers;

INSERT INTO query_target.customers (
    customer_id,
    source_change_id,
    customer_name,
    region,
    is_deleted
)
SELECT
    customer_id,
    change_id,
    customer_name,
    region,
    is_deleted
FROM (
    SELECT DISTINCT ON (customer_id)
        customer_id,
        change_id,
        operation,
        customer_name,
        region,
        is_deleted
    FROM query_source.customer_changes
    ORDER BY customer_id, change_id DESC
) AS latest
WHERE operation = 'upsert';

UPDATE query_target.checkpoint
SET last_changed_at = COALESCE(
        (SELECT changed_at
         FROM query_source.customer_changes
         ORDER BY changed_at DESC, change_id DESC
         LIMIT 1),
        TIMESTAMPTZ '1970-01-01 00:00:00+00'
    ),
    last_change_id = COALESCE(
        (SELECT change_id
         FROM query_source.customer_changes
         ORDER BY changed_at DESC, change_id DESC
         LIMIT 1),
        0
    )
WHERE checkpoint_id = 1;

COMMIT;
