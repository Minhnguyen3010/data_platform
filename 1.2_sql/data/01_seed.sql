INSERT INTO departments (department_id, department_name)
SELECT department_id, 'Department ' || lpad(department_id::text, 2, '0')
FROM generate_series(1, 8) AS series(department_id)
ON CONFLICT (department_id) DO NOTHING;

INSERT INTO employees (
    employee_id, department_id, manager_id, first_name, last_name,
    email, hired_at, salary, is_active
)
SELECT
    n,
    ((n - 1) % 8) + 1,
    CASE WHEN n = 1 THEN NULL ELSE 1 END,
    'Employee',
    lpad(n::text, 3, '0'),
    'employee' || n || '@example.test',
    date '2018-01-01' + ((n * 17) % 2500),
    (35000 + ((n * 1379) % 65000))::numeric(12, 2),
    n % 17 <> 0
FROM generate_series(1, 100) AS series(n)
ON CONFLICT (employee_id) DO NOTHING;

INSERT INTO customers (customer_id, first_name, last_name, email, created_at)
SELECT
    n,
    'Customer',
    lpad(n::text, 5, '0'),
    'customer' || n || '@example.test',
    timestamptz '2020-01-01 00:00:00+00' + (n % 1500) * interval '1 day'
FROM generate_series(1, 5000) AS series(n)
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO products (product_id, product_name, category, list_price, is_active)
SELECT
    n,
    'Product ' || lpad(n::text, 3, '0'),
    'Category ' || lpad((((n - 1) % 10) + 1)::text, 2, '0'),
    (5 + ((n * 23) % 995))::numeric(10, 2),
    n % 19 <> 0
FROM generate_series(1, 200) AS series(n)
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO orders (
    order_id, customer_id, employee_id, order_date, status, shipped_at
)
SELECT
    n,
    ((n * 37 - 1) % 5000) + 1,
    ((n * 7 - 1) % 100) + 1,
    timestamptz '2024-01-01 00:00:00+00'
        + ((n - 1) % 730) * interval '1 day'
        + ((n * 7919) % 86400) * interval '1 second',
    CASE
        WHEN n % 10 IN (0, 1) THEN 'cancelled'
        WHEN n % 10 IN (2, 3) THEN 'new'
        WHEN n % 10 IN (4, 5) THEN 'processing'
        WHEN n % 10 IN (6, 7) THEN 'shipped'
        ELSE 'completed'
    END,
    CASE
        WHEN n % 10 IN (6, 7, 8, 9) THEN
            timestamptz '2024-01-01 00:00:00+00'
                + ((n - 1) % 730) * interval '1 day'
                + ((n * 7919) % 86400) * interval '1 second'
                + interval '2 days'
        ELSE NULL
    END
FROM generate_series(1, 60000) AS series(n)
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO order_items (order_id, line_number, product_id, quantity, unit_price)
SELECT
    o.order_id,
    line.line_number::smallint,
    ((o.order_id * 13 + line.line_number * 17 - 1) % 200) + 1,
    ((o.order_id + line.line_number) % 5) + 1,
    round(
        p.list_price
            * (0.90 + ((o.order_id + line.line_number) % 21)::numeric / 100),
        2
    )
FROM orders AS o
CROSS JOIN LATERAL generate_series(1, ((o.order_id - 1) % 4) + 1) AS line(line_number)
JOIN products AS p
    ON p.product_id = ((o.order_id * 13 + line.line_number * 17 - 1) % 200) + 1
ON CONFLICT (order_id, line_number) DO NOTHING;

SELECT setval(
    pg_get_serial_sequence('departments', 'department_id'),
    (SELECT max(department_id) FROM departments),
    true
);
SELECT setval(
    pg_get_serial_sequence('employees', 'employee_id'),
    (SELECT max(employee_id) FROM employees),
    true
);
SELECT setval(
    pg_get_serial_sequence('customers', 'customer_id'),
    (SELECT max(customer_id) FROM customers),
    true
);
SELECT setval(
    pg_get_serial_sequence('products', 'product_id'),
    (SELECT max(product_id) FROM products),
    true
);
SELECT setval(
    pg_get_serial_sequence('orders', 'order_id'),
    (SELECT max(order_id) FROM orders),
    true
);
