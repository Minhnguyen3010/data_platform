BEGIN;

CREATE TEMP TABLE pending_id_events ON COMMIT DROP AS
SELECT s.*
FROM source.sales_events AS s
JOIN target.load_checkpoint AS c
  ON c.pipeline_name = 'by_id'
WHERE s.event_id > c.last_event_id;

INSERT INTO target.sales_by_id AS current_sale (
    sale_id, source_event_id, status, amount, is_deleted
)
SELECT DISTINCT ON (sale_id)
    sale_id, event_id, status, amount, is_deleted
FROM pending_id_events
ORDER BY sale_id, event_id DESC
ON CONFLICT (sale_id) DO UPDATE
SET source_event_id = EXCLUDED.source_event_id,
    status = EXCLUDED.status,
    amount = EXCLUDED.amount,
    is_deleted = EXCLUDED.is_deleted
WHERE EXCLUDED.source_event_id > current_sale.source_event_id;

UPDATE target.load_checkpoint AS c
SET last_event_id = latest.event_id,
    last_updated_at = latest.updated_at,
    last_updated_event_id = latest.event_id
FROM (
    SELECT event_id, updated_at
    FROM pending_id_events
    ORDER BY event_id DESC
    LIMIT 1
) AS latest
WHERE c.pipeline_name = 'by_id';

COMMIT;
