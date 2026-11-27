INSERT INTO query_source.customer_changes (
    change_key,
    changed_at,
    customer_id,
    operation,
    customer_name,
    region,
    is_deleted
)
VALUES
    ('customer-1-updated', TIMESTAMPTZ '2024-01-03 10:00:00+00', 'C-001', 'upsert', 'Lan Nguyen Updated', 'Central', false),
    ('customer-2-hard-deleted', TIMESTAMPTZ '2024-01-04 10:00:00+00', 'C-002', 'hard_delete', NULL, NULL, true),
    ('customer-3-soft-deleted', TIMESTAMPTZ '2024-01-05 10:00:00+00', 'C-003', 'upsert', 'Hoa Pham', 'West', true)
ON CONFLICT (change_key) DO NOTHING;
