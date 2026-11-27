UPDATE public.customers
SET customer_name = 'Lan Nguyen Updated',
    region = 'Central'
WHERE customer_id = 1;

DELETE FROM public.customers
WHERE customer_id = 2;

INSERT INTO public.customers (customer_id, customer_name, region)
VALUES (3, 'Hoa Pham', 'West');

UPDATE public.customers
SET is_deleted = true
WHERE customer_id = 3;
