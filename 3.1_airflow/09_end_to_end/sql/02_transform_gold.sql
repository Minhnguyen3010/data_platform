INSERT INTO gold_daily_sales (
    sales_date,
    order_count,
    gross_amount,
    updated_at
)
SELECT
    date(created_at),
    COUNT(*),
    ROUND(SUM(amount), 2),
    CURRENT_TIMESTAMP
FROM bronze_orders
WHERE created_at >= :interval_start
  AND created_at < :interval_end
  AND status = 'COMPLETED'
GROUP BY date(created_at)
ON CONFLICT (sales_date) DO UPDATE SET
    order_count = excluded.order_count,
    gross_amount = excluded.gross_amount,
    updated_at = CURRENT_TIMESTAMP;
