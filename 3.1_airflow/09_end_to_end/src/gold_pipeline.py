import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterator


def _utc_bounds(
    interval_start: datetime, interval_end: datetime
) -> tuple[datetime, datetime]:
    if interval_start.tzinfo is None or interval_end.tzinfo is None:
        raise ValueError("Data interval boundaries must be timezone-aware.")

    start = interval_start.astimezone(timezone.utc)
    end = interval_end.astimezone(timezone.utc)
    if start >= end:
        raise ValueError("Data interval start must be before its end.")
    if start.time() != datetime.min.time() or end.time() != datetime.min.time():
        raise ValueError("This lab expects UTC midnight data interval boundaries.")
    return start, end


def get_database_path() -> Path:
    output_dir = Path(
        os.environ.get(
            "AIRFLOW_LAB_OUTPUT_DIR",
            str(Path(__file__).resolve().parents[1] / "output"),
        )
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir / "gold_pipeline.sqlite"


@contextmanager
def open_database(database_path: Path) -> Iterator[sqlite3.Connection]:
    database_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(str(database_path), timeout=30)
    try:
        with connection:
            yield connection
    finally:
        connection.close()


def initialize_database(connection: sqlite3.Connection, setup_sql_path: Path) -> None:
    connection.executescript(setup_sql_path.read_text(encoding="utf-8"))


def ingest_interval(
    connection: sqlite3.Connection,
    interval_start: datetime,
    interval_end: datetime,
) -> int:
    start, end = _utc_bounds(interval_start, interval_end)
    rows = []
    current = start
    while current < end:
        day = current.strftime("%Y-%m-%d")
        created_at = current.isoformat(timespec="seconds")
        rows.extend(
            [
                ("order-%s-001" % day, created_at, 12.50, "COMPLETED"),
                ("order-%s-002" % day, created_at, 7.50, "COMPLETED"),
            ]
        )
        current += timedelta(days=1)

    connection.executemany(
        """
        INSERT INTO bronze_orders (order_id, created_at, amount, status)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (order_id) DO UPDATE SET
            created_at = excluded.created_at,
            amount = excluded.amount,
            status = excluded.status
        """,
        rows,
    )
    return len(rows)


def validate_interval(
    connection: sqlite3.Connection,
    interval_start: datetime,
    interval_end: datetime,
) -> int:
    start, end = _utc_bounds(interval_start, interval_end)
    rows = connection.execute(
        """
        SELECT order_id, amount, status
        FROM bronze_orders
        WHERE created_at >= ? AND created_at < ?
        ORDER BY order_id
        """,
        (start.isoformat(timespec="seconds"), end.isoformat(timespec="seconds")),
    ).fetchall()
    expected_count = (end.date() - start.date()).days * 2
    if len(rows) != expected_count:
        raise ValueError(
            "Expected %s orders in interval, found %s."
            % (expected_count, len(rows))
        )
    if any(
        not order_id
        or amount < 0
        or status not in {"COMPLETED", "CANCELLED"}
        for order_id, amount, status in rows
    ):
        raise ValueError("Source interval contains invalid order data.")
    return len(rows)


def transform_interval(
    connection: sqlite3.Connection,
    interval_start: datetime,
    interval_end: datetime,
    transform_sql_path: Path,
) -> None:
    start, end = _utc_bounds(interval_start, interval_end)
    connection.execute(
        transform_sql_path.read_text(encoding="utf-8"),
        {
            "interval_start": start.isoformat(timespec="seconds"),
            "interval_end": end.isoformat(timespec="seconds"),
        },
    )


def assert_gold_interval(
    connection: sqlite3.Connection,
    interval_start: datetime,
    interval_end: datetime,
) -> dict[str, int | float]:
    start, end = _utc_bounds(interval_start, interval_end)
    rows = connection.execute(
        """
        SELECT sales_date, order_count, gross_amount
        FROM gold_daily_sales
        WHERE sales_date >= ? AND sales_date < ?
        ORDER BY sales_date
        """,
        (start.date().isoformat(), end.date().isoformat()),
    ).fetchall()
    expected_dates = []
    current = start
    while current < end:
        expected_dates.append(current.date().isoformat())
        current += timedelta(days=1)

    if [row[0] for row in rows] != expected_dates:
        raise AssertionError(
            "Gold dates do not match interval: expected %s, got %s."
            % (expected_dates, [row[0] for row in rows])
        )
    if any(
        order_count != 2 or abs(gross_amount - 20.0) > 0.001
        for _, order_count, gross_amount in rows
    ):
        raise AssertionError("Gold order count or amount does not match source.")

    return {
        "gold_days": len(rows),
        "order_count": sum(row[1] for row in rows),
        "gross_amount": round(sum(row[2] for row in rows), 2),
    }
