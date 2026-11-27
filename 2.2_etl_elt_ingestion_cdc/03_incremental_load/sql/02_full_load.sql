BEGIN;

TRUNCATE target.sales_by_timestamp, target.sales_by_id;

INSERT INTO target.sales_by_timestamp (
    sale_id, source_event_id, status, amount, is_deleted
)
SELECT DISTINCT ON (sale_id)
    sale_id, event_id, status, amount, is_deleted
FROM source.sales_events
ORDER BY sale_id, event_id DESC;

INSERT INTO target.sales_by_id (
    sale_id, source_event_id, status, amount, is_deleted
)
SELECT DISTINCT ON (sale_id)
    sale_id, event_id, status, amount, is_deleted
FROM source.sales_events
ORDER BY sale_id, event_id DESC;

UPDATE target.load_checkpoint
SET last_event_id = COALESCE((SELECT max(event_id) FROM source.sales_events), 0),
    last_updated_at = COALESCE(
        (SELECT updated_at FROM source.sales_events ORDER BY updated_at DESC, event_id DESC LIMIT 1),
        TIMESTAMPTZ '1970-01-01 00:00:00+00'
    ),
    last_updated_event_id = COALESCE(
        (SELECT event_id FROM source.sales_events ORDER BY updated_at DESC, event_id DESC LIMIT 1),
        0
    );

COMMIT;
