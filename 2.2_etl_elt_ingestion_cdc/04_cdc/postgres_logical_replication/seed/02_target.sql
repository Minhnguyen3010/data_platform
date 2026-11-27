CREATE TABLE IF NOT EXISTS public.customers (
    customer_id integer PRIMARY KEY,
    customer_name text NOT NULL,
    region text NOT NULL,
    is_deleted boolean NOT NULL DEFAULT false
);
