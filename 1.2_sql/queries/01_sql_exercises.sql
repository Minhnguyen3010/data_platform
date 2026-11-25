-- 01. Chọn cột cần thiết, không dùng SELECT * trong truy vấn ứng dụng.
SELECT employee_id, first_name, last_name, salary
FROM employees;

-- 02. Lọc nhân viên đang làm việc có lương từ 60.000 trở lên.
SELECT employee_id, first_name, last_name, salary
FROM employees
WHERE is_active AND salary >= 60000;

-- 03. Sắp xếp theo lương giảm dần, giới hạn kết quả.
SELECT employee_id, first_name, last_name, salary
FROM employees
ORDER BY salary DESC, employee_id
LIMIT 10;

-- 04. Lọc theo một tập giá trị.
SELECT order_id, status, order_date
FROM orders
WHERE status IN ('shipped', 'completed')
ORDER BY order_date DESC
LIMIT 20;

-- 05. Đếm nhân viên theo phòng ban.
SELECT department_id, count(*) AS employee_count
FROM employees
GROUP BY department_id
ORDER BY department_id;

-- 06. HAVING lọc sau khi nhóm.
SELECT department_id, avg(salary)::numeric(12, 2) AS average_salary
FROM employees
GROUP BY department_id
HAVING avg(salary) > 60000
ORDER BY average_salary DESC;

-- 07. INNER JOIN nhân viên với phòng ban.
SELECT e.employee_id, e.first_name, e.last_name, d.department_name
FROM employees AS e
JOIN departments AS d ON d.department_id = e.department_id
ORDER BY e.employee_id;

-- 08. Nối đơn hàng với khách hàng.
SELECT o.order_id, o.order_date, o.status, c.customer_id, c.email
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
ORDER BY o.order_date DESC
LIMIT 20;

-- 09. Nối nhiều bảng để xem chi tiết đơn hàng.
SELECT oi.order_id, oi.line_number, p.product_name, oi.quantity, oi.unit_price
FROM order_items AS oi
JOIN products AS p ON p.product_id = oi.product_id
WHERE oi.order_id = 42
ORDER BY oi.line_number;

-- 10. Doanh thu theo nhân viên.
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
FROM employees AS e
JOIN orders AS o ON o.employee_id = e.employee_id
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status IN ('shipped', 'completed')
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY revenue DESC;

-- 11. Báo cáo doanh thu theo tháng.
SELECT
    date_trunc('month', o.order_date AT TIME ZONE 'UTC') AS revenue_month,
    count(DISTINCT o.order_id) AS completed_orders,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status IN ('shipped', 'completed')
GROUP BY date_trunc('month', o.order_date AT TIME ZONE 'UTC')
ORDER BY revenue_month;

-- 12. CASE WHEN phân loại đơn hàng.
SELECT
    status,
    CASE
        WHEN status = 'cancelled' THEN 'excluded'
        WHEN status IN ('shipped', 'completed') THEN 'revenue'
        ELSE 'open'
    END AS reporting_group,
    count(*) AS order_count
FROM orders
GROUP BY status
ORDER BY status;

-- 13. CTE tổng hợp doanh thu, sau đó nối với nhân viên.
WITH employee_revenue AS (
    SELECT
        o.employee_id,
        sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status IN ('shipped', 'completed')
    GROUP BY o.employee_id
)
SELECT e.employee_id, e.first_name, e.last_name, er.revenue
FROM employee_revenue AS er
JOIN employees AS e ON e.employee_id = er.employee_id
ORDER BY er.revenue DESC;

-- 14. CTE lồng nhau: doanh thu tháng rồi chọn tháng cao nhất.
WITH monthly AS (
    SELECT
        date_trunc('month', o.order_date AT TIME ZONE 'UTC') AS month_start,
        sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status IN ('shipped', 'completed')
    GROUP BY date_trunc('month', o.order_date AT TIME ZONE 'UTC')
)
SELECT month_start, revenue
FROM monthly
WHERE revenue = (SELECT max(revenue) FROM monthly);

-- 15. Subquery: nhân viên có lương trên trung bình công ty.
SELECT employee_id, first_name, last_name, salary
FROM employees
WHERE salary > (SELECT avg(salary) FROM employees)
ORDER BY salary DESC;

-- 16. EXISTS: khách hàng đã có ít nhất một đơn.
SELECT c.customer_id, c.first_name, c.last_name
FROM customers AS c
WHERE EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
);

-- 17. NOT EXISTS: khách hàng chưa có đơn hàng.
SELECT c.customer_id, c.first_name, c.last_name
FROM customers AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
);

-- 18. Hàm cửa sổ: xếp hạng nhân viên trong từng phòng ban.
SELECT
    employee_id,
    department_id,
    salary,
    rank() OVER (PARTITION BY department_id ORDER BY salary DESC) AS salary_rank
FROM employees;

-- 19. Xếp hạng nhân viên theo doanh thu, xử lý đồng hạng.
WITH employee_revenue AS (
    SELECT
        o.employee_id,
        sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status IN ('shipped', 'completed')
    GROUP BY o.employee_id
)
SELECT
    employee_id,
    revenue,
    dense_rank() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM employee_revenue
ORDER BY revenue_rank, employee_id;

-- 20. Tổng lũy kế doanh thu theo tháng.
WITH monthly AS (
    SELECT
        date_trunc('month', o.order_date AT TIME ZONE 'UTC') AS month_start,
        sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status IN ('shipped', 'completed')
    GROUP BY date_trunc('month', o.order_date AT TIME ZONE 'UTC')
)
SELECT
    month_start,
    revenue,
    sum(revenue) OVER (ORDER BY month_start) AS running_revenue
FROM monthly
ORDER BY month_start;

-- 21. So sánh doanh thu tháng hiện tại với tháng trước.
WITH monthly AS (
    SELECT
        date_trunc('month', o.order_date AT TIME ZONE 'UTC') AS month_start,
        sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status IN ('shipped', 'completed')
    GROUP BY date_trunc('month', o.order_date AT TIME ZONE 'UTC')
)
SELECT
    month_start,
    revenue,
    lag(revenue) OVER (ORDER BY month_start) AS previous_month_revenue,
    revenue - lag(revenue) OVER (ORDER BY month_start) AS revenue_change
FROM monthly
ORDER BY month_start;

-- 22. Chọn đơn hàng mới nhất của mỗi khách bằng DISTINCT ON (PostgreSQL).
SELECT DISTINCT ON (customer_id)
    customer_id, order_id, order_date, status
FROM orders
ORDER BY customer_id, order_date DESC, order_id DESC;

-- 23. Cùng kết quả trên bằng ROW_NUMBER, dễ mở rộng điều kiện xếp hạng.
WITH ranked_orders AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        status,
        row_number() OVER (
            PARTITION BY customer_id
            ORDER BY order_date DESC, order_id DESC
        ) AS row_num
    FROM orders
)
SELECT customer_id, order_id, order_date, status
FROM ranked_orders
WHERE row_num = 1;

-- 24. Dùng đệ quy để đi theo cây quản lý nhân viên.
WITH RECURSIVE employee_tree AS (
    SELECT employee_id, manager_id, first_name, last_name, 0 AS depth
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, e.manager_id, e.first_name, e.last_name, t.depth + 1
    FROM employees AS e
    JOIN employee_tree AS t ON e.manager_id = t.employee_id
)
SELECT employee_id, manager_id, first_name, last_name, depth
FROM employee_tree
ORDER BY depth, employee_id;

-- 25. LEFT JOIN giữ cả khách hàng không có đơn.
SELECT c.customer_id, c.email, count(o.order_id) AS order_count
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.email
ORDER BY order_count DESC, c.customer_id;

-- 26. Điều kiện của bảng phải đặt trong ON nếu cần giữ hàng không khớp.
SELECT c.customer_id, count(o.order_id) AS completed_order_count
FROM customers AS c
LEFT JOIN orders AS o
    ON o.customer_id = c.customer_id
    AND o.status = 'completed'
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- 27. Khoảng thời gian nửa mở: tất cả đơn trong năm 2025 theo UTC.
SELECT order_id, customer_id, order_date
FROM orders
WHERE order_date >= timestamptz '2025-01-01 00:00:00+00'
  AND order_date < timestamptz '2026-01-01 00:00:00+00'
ORDER BY order_date;

-- 28. Đếm giá trị NULL đúng cách; manager_id NULL biểu thị nhân viên gốc.
SELECT employee_id, first_name, last_name
FROM employees
WHERE manager_id IS NULL;

-- 29. So sánh NULL an toàn: IS NOT DISTINCT FROM cho kết quả boolean.
SELECT
    NULL::integer = NULL::integer AS ordinary_equality,
    NULL::integer IS NOT DISTINCT FROM NULL::integer AS null_safe_equality;

-- 30. COALESCE thay giá trị NULL khi trình bày; không thay đổi dữ liệu gốc.
SELECT
    c.customer_id,
    coalesce(max(o.order_date)::text, 'Chưa có đơn') AS latest_order
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY c.customer_id
LIMIT 20;

-- 31. Dùng NUMERIC cho tiền; cast kết quả để thể hiện độ chính xác báo cáo.
SELECT
    avg(oi.unit_price)::numeric(12, 2) AS average_unit_price,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS gross_revenue
FROM order_items AS oi;

-- 32. Đọc view đã định nghĩa trong schema.
SELECT revenue_month, order_count, revenue
FROM monthly_revenue
ORDER BY revenue_month;

-- 33. INSERT, sau đó ROLLBACK để giữ nguyên dữ liệu mẫu.
BEGIN;
INSERT INTO customers (first_name, last_name, email)
VALUES ('Test', 'Insert', 'sql-insert@example.test');
ROLLBACK;

-- 34. UPDATE có điều kiện, hủy thay đổi bằng ROLLBACK.
BEGIN;
UPDATE employees
SET salary = salary * 1.05
WHERE employee_id = 1 AND is_active;
ROLLBACK;

-- 35. DELETE một khách hàng thử nghiệm trong transaction.
BEGIN;
INSERT INTO customers (first_name, last_name, email)
VALUES ('Test', 'Delete', 'sql-delete@example.test');
DELETE FROM customers
WHERE email = 'sql-delete@example.test';
ROLLBACK;

-- 36. UPSERT: ON CONFLICT cập nhật khi khóa duy nhất đã tồn tại.
BEGIN;
INSERT INTO customers (customer_id, first_name, last_name, email)
VALUES (1, 'Updated', 'Customer', 'customer1@example.test')
ON CONFLICT (customer_id) DO UPDATE
SET first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    email = EXCLUDED.email;
ROLLBACK;

-- 37. MERGE yêu cầu PostgreSQL 15+; ROLLBACK giữ nguyên dữ liệu.
BEGIN;
MERGE INTO customers AS target
USING (VALUES (1, 'Merged', 'Customer', 'customer1@example.test'))
    AS source(customer_id, first_name, last_name, email)
ON target.customer_id = source.customer_id
WHEN MATCHED THEN
    UPDATE SET first_name = source.first_name,
               last_name = source.last_name,
               email = source.email
WHEN NOT MATCHED THEN
    INSERT (customer_id, first_name, last_name, email)
    VALUES (source.customer_id, source.first_name, source.last_name, source.email);
ROLLBACK;

-- 38. Transaction và savepoint: chỉ phần sau savepoint bị hủy trước đó.
BEGIN;
UPDATE employees SET salary = salary + 1 WHERE employee_id = 1;
SAVEPOINT after_salary_update;
UPDATE employees SET salary = salary + 1 WHERE employee_id = 2;
ROLLBACK TO SAVEPOINT after_salary_update;
ROLLBACK;

-- 39. Tìm các phòng ban có nhiều hơn 10 nhân viên đang làm việc.
SELECT d.department_id, d.department_name, count(e.employee_id) AS active_count
FROM departments AS d
JOIN employees AS e ON e.department_id = d.department_id
WHERE e.is_active
GROUP BY d.department_id, d.department_name
HAVING count(e.employee_id) > 10
ORDER BY active_count DESC;

-- 40. Xem 20 sản phẩm có doanh thu cao nhất trên các đơn hợp lệ.
SELECT
    p.product_id,
    p.product_name,
    sum(oi.quantity * oi.unit_price)::numeric(14, 2) AS revenue
FROM products AS p
JOIN order_items AS oi ON oi.product_id = p.product_id
JOIN orders AS o ON o.order_id = oi.order_id
WHERE o.status IN ('shipped', 'completed')
GROUP BY p.product_id, p.product_name
ORDER BY revenue DESC
LIMIT 20;
