DO $$
BEGIN
    IF (SELECT count(*) FROM query_target.customers) <> 2 THEN
        RAISE EXCEPTION 'Expected two customers after query-based CDC';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM query_target.customers
        WHERE customer_id = 'C-001'
          AND customer_name = 'Lan Nguyen Updated'
          AND region = 'Central'
          AND NOT is_deleted
    ) THEN
        RAISE EXCEPTION 'Customer update was not applied';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM query_target.customers
        WHERE customer_id = 'C-002'
    ) THEN
        RAISE EXCEPTION 'Hard-delete event was not applied';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM query_target.customers
        WHERE customer_id = 'C-003'
          AND is_deleted
    ) THEN
        RAISE EXCEPTION 'Soft-delete flag was not applied';
    END IF;
END
$$;

SELECT * FROM query_target.customers ORDER BY customer_id;
