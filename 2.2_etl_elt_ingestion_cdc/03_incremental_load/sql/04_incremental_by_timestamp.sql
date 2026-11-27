BEGIN;

CREATE TEMP TABLE pending_time_events ON COMMIT DROP AS
SELECT s.*
FROM source.sales_events AS s
JOIN target.load_checkpoint AS c
  ON c.pipeline_name = 'by_timestamp'
WHERE (s.updated_at, s.event_id) > (c.last_updated_at, c.last_updated_event_id);

INSERT INTO target.sales_by_timestamp AS current_sale (
    sale_id, source_event_id, status, amount, is_deleted
)
SELECT DISTINCT ON (sale_id)
    sale_id, event_id, status, amount, is_deleted
FROM pending_time_events
ORDER BY sale_id, event_id DESC
ON CONFLICT (sale_id) DO UPDATE
SET source_event_id = EXCLUDED.source_event_id,
    status = EXCLUDED.status,
    amount = EXCLUDED.amount,
    is_deleted = EXCLUDED.is_deleted
WHERE EXCLUDED.source_event_id > current_sale.source_event_id;

UPDATE target.load_checkpoint AS c
SET last_updated_at = latest.updated_at,
    last_updated_event_id = latest.event_id,
    last_event_id = GREATEST(c.last_event_id, latest.event_id)
FROM (
    SELECT updated_at, event_id
    FROM pending_time_events
    ORDER BY updated_at DESC, event_id DESC
    LIMIT 1
) AS latest
WHERE c.pipeline_name = 'by_timestamp';

COMMIT;
