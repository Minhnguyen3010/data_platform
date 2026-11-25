-- Chạy trên database riêng sau khi nạp data/01_seed.sql.
-- Lưu output của mỗi EXPLAIN để so sánh execution time, rows và buffers.
-- Xóa các index benchmark lần trước để phần đầu luôn đo baseline chưa có index.
DROP INDEX IF EXISTS idx_orders_revenue_date;
DROP INDEX IF EXISTS idx_orders_employee_revenue;
DROP INDEX IF EXISTS idx_orders_customer_latest;

ANALYZE orders;
ANALYZE order_items;

-- Truy vấn chậm 1: doanh thu theo tháng.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_trunc('month', o.order_date AT TIME ZONE 'UTC') AS revenue_month,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status IN ('shipped', 'completed')
  AND o.order_date >= timestamptz '2024-01-01 00:00:00+00'
  AND o.order_date < timestamptz '2026-01-01 00:00:00+00'
GROUP BY date_trunc('month', o.order_date AT TIME ZONE 'UTC')
ORDER BY revenue_month;

-- Truy vấn chậm 2: xếp hạng nhân viên theo doanh thu.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.employee_id,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status IN ('shipped', 'completed')
GROUP BY o.employee_id
ORDER BY revenue DESC;

-- Truy vấn chậm 3: đơn hàng gần nhất của mỗi khách hàng.
EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT ON (customer_id)
    customer_id, order_id, order_date, status
FROM orders
ORDER BY customer_id, order_date DESC, order_id DESC;

-- Index tối ưu cho đúng các điều kiện lọc, nhóm và sắp xếp ở trên.
CREATE INDEX IF NOT EXISTS idx_orders_revenue_date
    ON orders (order_date)
    INCLUDE (order_id)
    WHERE status IN ('shipped', 'completed');

CREATE INDEX IF NOT EXISTS idx_orders_employee_revenue
    ON orders (employee_id)
    INCLUDE (order_id)
    WHERE status IN ('shipped', 'completed');

CREATE INDEX IF NOT EXISTS idx_orders_customer_latest
    ON orders (customer_id, order_date DESC, order_id DESC)
    INCLUDE (status);

ANALYZE orders;
ANALYZE order_items;

-- Chạy lại truy vấn 1 sau index.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_trunc('month', o.order_date AT TIME ZONE 'UTC') AS revenue_month,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status IN ('shipped', 'completed')
  AND o.order_date >= timestamptz '2024-01-01 00:00:00+00'
  AND o.order_date < timestamptz '2026-01-01 00:00:00+00'
GROUP BY date_trunc('month', o.order_date AT TIME ZONE 'UTC')
ORDER BY revenue_month;

-- Chạy lại truy vấn 2 sau index.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.employee_id,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status IN ('shipped', 'completed')
GROUP BY o.employee_id
ORDER BY revenue DESC;

-- Chạy lại truy vấn 3 sau index.
EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT ON (customer_id)
    customer_id, order_id, order_date, status
FROM orders
ORDER BY customer_id, order_date DESC, order_id DESC;
