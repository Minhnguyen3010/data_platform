INSERT INTO source.sales_events (
    event_key, sale_id, updated_at, status, amount, is_deleted
)
VALUES
    ('event-004', 'S-002', TIMESTAMPTZ '2024-01-04 10:00:00+00', 'deleted', 0.00, true),
    ('event-005', 'S-003', TIMESTAMPTZ '2024-01-05 10:00:00+00', 'paid', 25.00, false)
ON CONFLICT (event_key) DO NOTHING;
