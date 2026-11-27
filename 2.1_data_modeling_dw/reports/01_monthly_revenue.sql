SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    p.product_id,
    p.product_name,
    p.category,
    c.region,
    sum(f.quantity) AS units_sold,
    sum(f.sales_amount)::numeric(14, 2) AS revenue
FROM fact_sales AS f
JOIN dim_date AS d
  ON d.date_key = f.date_key
JOIN dim_product AS p
  ON p.product_sk = f.product_sk
JOIN dim_customer AS c
  ON c.customer_sk = f.customer_sk
GROUP BY
    d.year_number,
    d.month_number,
    d.month_name,
    p.product_id,
    p.product_name,
    p.category,
    c.region
ORDER BY
    d.year_number,
    d.month_number,
    p.product_name,
    c.region;
