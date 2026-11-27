DO $$
DECLARE
    attempts integer := 0;
BEGIN
    LOOP
        EXIT WHEN EXISTS (
            SELECT 1
            FROM public.customers
            WHERE customer_id = 1
              AND customer_name = 'Lan Nguyen Updated'
              AND region = 'Central'
        )
        AND NOT EXISTS (
            SELECT 1 FROM public.customers WHERE customer_id = 2
        )
        AND EXISTS (
            SELECT 1
            FROM public.customers
            WHERE customer_id = 3
              AND is_deleted
        );

        attempts := attempts + 1;
        IF attempts >= 40 THEN
            RAISE EXCEPTION 'CDC changes were not applied to the target in time';
        END IF;
        PERFORM pg_sleep(0.25);
    END LOOP;
END
$$;

SELECT * FROM public.customers ORDER BY customer_id;
