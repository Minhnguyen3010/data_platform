INSERT INTO raw.sales_events (event_id, payload)
VALUES
    (
        'evt-001',
        '{"order_id":"O-200","line_number":1,"sold_at":"2024-06-01T10:00:00Z","customer_id":"C-001","product_id":"P-101","quantity":2,"unit_price":45.00,"discount":5.00}'
    ),
    (
        'evt-002',
        '{"order_id":"O-201","line_number":1,"sold_at":"2024-06-02T10:00:00Z","customer_id":"C-002","product_id":"P-102","quantity":3,"unit_price":12.50,"campaign":"summer"}'
    )
ON CONFLICT (event_id) DO UPDATE
SET payload = EXCLUDED.payload,
    ingested_at = now();
