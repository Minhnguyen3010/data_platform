from datetime import datetime, timezone
from decimal import Decimal

import pytest

from etl import transform_row


def test_transform_normalizes_fields_and_timestamp_to_utc():
    transformed = transform_row(
        {
            "order_id": "O-1",
            "line_number": "1",
            "sold_at": "2024-05-01T12:00:00+02:00",
            "customer_id": "c-001",
            "product_id": "p-101",
            "quantity": "2",
            "unit_price": "4.50",
        }
    )

    assert transformed == (
        "O-1",
        1,
        datetime(2024, 5, 1, 10, 0, tzinfo=timezone.utc),
        "C-001",
        "P-101",
        2,
        Decimal("4.50"),
    )


@pytest.mark.parametrize(
    ("field", "invalid_value"),
    [("quantity", "0"), ("unit_price", "-1"), ("sold_at", "not-a-date")],
)
def test_transform_rejects_invalid_values(field, invalid_value):
    row = {
        "order_id": "O-1",
        "line_number": "1",
        "sold_at": "2024-05-01T10:00:00+00:00",
        "customer_id": "c-001",
        "product_id": "p-101",
        "quantity": "2",
        "unit_price": "4.50",
    }
    row[field] = invalid_value

    with pytest.raises(ValueError):
        transform_row(row)
