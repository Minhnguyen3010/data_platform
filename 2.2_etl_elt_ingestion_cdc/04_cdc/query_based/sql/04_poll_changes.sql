BEGIN;

CREATE TEMP TABLE pending_customer_changes ON COMMIT DROP AS
SELECT s.*
FROM query_source.customer_changes AS s
JOIN query_target.checkpoint AS c
  ON c.checkpoint_id = 1
WHERE (s.changed_at, s.change_id) > (c.last_changed_at, c.last_change_id);

CREATE TEMP TABLE latest_customer_changes ON COMMIT DROP AS
SELECT DISTINCT ON (customer_id) *
FROM pending_customer_changes
ORDER BY customer_id, change_id DESC;

DELETE FROM query_target.customers AS target
USING latest_customer_changes AS change
WHERE change.operation = 'hard_delete'
  AND target.customer_id = change.customer_id;

INSERT INTO query_target.customers AS current_customer (
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
FROM latest_customer_changes
WHERE operation = 'upsert'
ON CONFLICT (customer_id) DO UPDATE
SET source_change_id = EXCLUDED.source_change_id,
    customer_name = EXCLUDED.customer_name,
    region = EXCLUDED.region,
    is_deleted = EXCLUDED.is_deleted
WHERE EXCLUDED.source_change_id > current_customer.source_change_id;

UPDATE query_target.checkpoint AS checkpoint
SET last_changed_at = latest.changed_at,
    last_change_id = latest.change_id
FROM (
    SELECT changed_at, change_id
    FROM pending_customer_changes
    ORDER BY changed_at DESC, change_id DESC
    LIMIT 1
) AS latest
WHERE checkpoint.checkpoint_id = 1;

COMMIT;
