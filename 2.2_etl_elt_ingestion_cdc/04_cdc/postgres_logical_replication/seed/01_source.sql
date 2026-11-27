CREATE TABLE IF NOT EXISTS public.customers (
    customer_id integer PRIMARY KEY,
    customer_name text NOT NULL,
    region text NOT NULL,
    is_deleted boolean NOT NULL DEFAULT false
);

INSERT INTO public.customers (customer_id, customer_name, region)
VALUES
    (1, 'Lan Nguyen', 'North'),
    (2, 'Minh Tran', 'South')
ON CONFLICT (customer_id) DO UPDATE
SET customer_name = EXCLUDED.customer_name,
    region = EXCLUDED.region;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'customers_pub'
    ) THEN
        EXECUTE 'CREATE PUBLICATION customers_pub FOR TABLE public.customers';
    END IF;
END
$$;
