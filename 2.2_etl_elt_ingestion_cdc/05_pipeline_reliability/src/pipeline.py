from __future__ import annotations

import argparse
import csv
import json
import sqlite3
import time
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Callable, TypeVar


MODULE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = MODULE_DIR / "data" / "events.csv"
DEFAULT_DATABASE = MODULE_DIR / "pipeline.db"
T = TypeVar("T")


def _initialize(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        CREATE TABLE IF NOT EXISTS target_events (
            event_id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            amount TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS dead_letter (
            source_offset INTEGER PRIMARY KEY,
            event_id TEXT,
            raw_record TEXT NOT NULL,
            reason TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS checkpoint (
            checkpoint_id INTEGER PRIMARY KEY CHECK (checkpoint_id = 1),
            last_offset INTEGER NOT NULL
        );
        INSERT INTO checkpoint (checkpoint_id, last_offset)
        VALUES (1, 0)
        ON CONFLICT (checkpoint_id) DO NOTHING;
        """
    )
    connection.commit()


def _validate(row: dict[str, str | None]) -> tuple[str, str, str]:
    event_id = str(row.get("event_id") or "").strip()
    customer_id = str(row.get("customer_id") or "").strip()
    amount_text = str(row.get("amount") or "").strip()
    if not event_id or not customer_id:
        raise ValueError("event_id and customer_id are required")

    try:
        amount = Decimal(amount_text)
    except InvalidOperation as error:
        raise ValueError("amount must be a decimal number") from error
    if not amount.is_finite() or amount < 0:
        raise ValueError("amount must be a finite non-negative number")
    return event_id, customer_id, str(amount)


def _retry_sqlite(
    operation: Callable[[], T],
    max_attempts: int = 3,
    delay_seconds: float = 0.05,
) -> T:
    if max_attempts < 1:
        raise ValueError("max_attempts must be at least one")

    for attempt in range(1, max_attempts + 1):
        try:
            return operation()
        except sqlite3.OperationalError:
            if attempt == max_attempts:
                raise
            time.sleep(delay_seconds * attempt)
    raise RuntimeError("unreachable retry state")


def run_pipeline(source_path: Path, database_path: Path) -> tuple[int, int, int]:
    database_path.parent.mkdir(parents=True, exist_ok=True)
    loaded = 0
    rejected = 0

    with sqlite3.connect(database_path) as connection:
        _initialize(connection)
        last_offset = connection.execute(
            "SELECT last_offset FROM checkpoint WHERE checkpoint_id = 1"
        ).fetchone()[0]

        with source_path.open(newline="", encoding="utf-8") as source_file:
            for source_offset, row in enumerate(csv.DictReader(source_file), start=1):
                if source_offset <= last_offset:
                    continue

                raw_record = json.dumps(row, sort_keys=True)
                try:
                    event_id, customer_id, amount = _validate(row)
                except ValueError as error:
                    event_id = str(row.get("event_id") or "").strip() or None

                    def save_rejected() -> None:
                        with connection:
                            connection.execute(
                                """
                                INSERT INTO dead_letter (
                                    source_offset, event_id, raw_record, reason
                                )
                                VALUES (?, ?, ?, ?)
                                ON CONFLICT (source_offset) DO UPDATE
                                SET event_id = excluded.event_id,
                                    raw_record = excluded.raw_record,
                                    reason = excluded.reason
                                """,
                                (source_offset, event_id, raw_record, str(error)),
                            )
                            connection.execute(
                                "UPDATE checkpoint SET last_offset = ? WHERE checkpoint_id = 1",
                                (source_offset,),
                            )

                    _retry_sqlite(save_rejected)
                    rejected += 1
                    continue

                def save_valid() -> None:
                    with connection:
                        connection.execute(
                            """
                            INSERT INTO target_events (event_id, customer_id, amount)
                            VALUES (?, ?, ?)
                            ON CONFLICT (event_id) DO UPDATE
                            SET customer_id = excluded.customer_id,
                                amount = excluded.amount
                            """,
                            (event_id, customer_id, amount),
                        )
                        connection.execute(
                            "UPDATE checkpoint SET last_offset = ? WHERE checkpoint_id = 1",
                            (source_offset,),
                        )

                _retry_sqlite(save_valid)
                loaded += 1

        checkpoint = connection.execute(
            "SELECT last_offset FROM checkpoint WHERE checkpoint_id = 1"
        ).fetchone()[0]

    return loaded, rejected, checkpoint


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run the retry, checkpoint, deduplication and DLQ lab"
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE)
    args = parser.parse_args()

    loaded, rejected, checkpoint = run_pipeline(args.source, args.database)
    print(
        f"Processed {loaded} valid rows and {rejected} rejected rows; "
        f"checkpoint offset is {checkpoint}"
    )


if __name__ == "__main__":
    main()
