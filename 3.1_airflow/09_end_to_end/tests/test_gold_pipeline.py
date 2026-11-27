import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

SOURCE_DIR = Path(__file__).resolve().parents[1] / "src"
LAB_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE_DIR))

from gold_pipeline import (
    _utc_bounds,
    assert_gold_interval,
    initialize_database,
    ingest_interval,
    open_database,
    transform_interval,
    validate_interval,
)


def test_replaying_seven_daily_intervals_does_not_duplicate_gold_rows(tmp_path):
    database_path = tmp_path / "gold.sqlite"
    first_day = datetime(2025, 1, 1, tzinfo=timezone.utc)

    for _ in range(2):
        for day_offset in range(7):
            start = first_day + timedelta(days=day_offset)
            end = start + timedelta(days=1)
            with open_database(database_path) as connection:
                initialize_database(
                    connection, LAB_DIR / "sql" / "01_setup.sql"
                )
                ingest_interval(connection, start, end)
                assert validate_interval(connection, start, end) == 2
                transform_interval(
                    connection,
                    start,
                    end,
                    LAB_DIR / "sql" / "02_transform_gold.sql",
                )
                assert assert_gold_interval(connection, start, end) == {
                    "gold_days": 1,
                    "order_count": 2,
                    "gross_amount": 20.0,
                }

    with open_database(database_path) as connection:
        bronze_count = connection.execute(
            "SELECT COUNT(*) FROM bronze_orders"
        ).fetchone()[0]
        gold_count, unique_days = connection.execute(
            "SELECT COUNT(*), COUNT(DISTINCT sales_date) FROM gold_daily_sales"
        ).fetchone()

    assert bronze_count == 14
    assert gold_count == unique_days == 7


@pytest.mark.parametrize(
    ("start", "end", "message"),
    [
        (
            datetime(2025, 1, 1),
            datetime(2025, 1, 2, tzinfo=timezone.utc),
            "timezone-aware",
        ),
        (
            datetime(2025, 1, 1, 1, tzinfo=timezone.utc),
            datetime(2025, 1, 2, 1, tzinfo=timezone.utc),
            "midnight",
        ),
    ],
)
def test_rejects_invalid_interval_boundaries(start, end, message):
    with pytest.raises(ValueError, match=message):
        _utc_bounds(start, end)
