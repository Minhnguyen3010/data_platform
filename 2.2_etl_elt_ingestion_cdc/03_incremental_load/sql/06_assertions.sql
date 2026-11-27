DO $$
BEGIN
    IF EXISTS (
        SELECT sale_id, source_event_id, status, amount, is_deleted
        FROM target.sales_by_timestamp
        EXCEPT
        SELECT sale_id, source_event_id, status, amount, is_deleted
        FROM target.sales_by_id
    ) OR EXISTS (
        SELECT sale_id, source_event_id, status, amount, is_deleted
        FROM target.sales_by_id
        EXCEPT
        SELECT sale_id, source_event_id, status, amount, is_deleted
        FROM target.sales_by_timestamp
    ) THEN
        RAISE EXCEPTION 'Timestamp and increasing-ID targets do not match';
    END IF;

    IF (SELECT count(*) FROM target.sales_by_timestamp) <> 3 THEN
        RAISE EXCEPTION 'Expected three distinct current sale records';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM target.sales_by_timestamp
        WHERE sale_id = 'S-002'
          AND is_deleted
    ) THEN
        RAISE EXCEPTION 'Expected a deletion tombstone for S-002';
    END IF;
END
$$;

SELECT * FROM target.sales_by_timestamp ORDER BY sale_id;
