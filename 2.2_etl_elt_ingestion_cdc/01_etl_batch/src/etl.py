from __future__ import annotations

import argparse
import csv
import os
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import TYPE_CHECKING, Mapping

if TYPE_CHECKING:
    from psycopg import Connection


MODULE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = MODULE_DIR / "data" / "sales.csv"
DEFAULT_REJECTS = MODULE_DIR / "output" / "rejected.csv"


def transform_row(row: Mapping[str, str | None]) -> tuple[object, ...]:
    def value(field: str) -> str:
        return str(row.get(field) or "").strip()

    order_id = value("order_id")
    customer_id = value("customer_id").upper()
    product_id = value("product_id").upper()
    if not order_id or not customer_id or not product_id:
        raise ValueError("order_id, customer_id and product_id are required")

    try:
        line_number = int(value("line_number"))
        quantity = int(value("quantity"))
        unit_price = Decimal(value("unit_price"))
        sold_at = datetime.fromisoformat(value("sold_at").replace("Z", "+00:00"))
    except (ValueError, InvalidOperation) as error:
        raise ValueError("line_number, quantity, unit_price or sold_at is invalid") from error

    if line_number <= 0 or quantity <= 0:
        raise ValueError("line_number and quantity must be positive")
    if not unit_price.is_finite() or unit_price < 0:
        raise ValueError("unit_price must be a finite non-negative amount")
    if sold_at.tzinfo is None:
        raise ValueError("sold_at must include a timezone")

    return (
        order_id,
        line_number,
        sold_at.astimezone(timezone.utc),
        customer_id,
        product_id,
        quantity,
        unit_price,
    )


def run(
    connection: Connection,
    source_path: Path,
    rejects_path: Path,
) -> tuple[int, int]:
    rejects_path.parent.mkdir(parents=True, exist_ok=True)
    loaded = 0
    rejected = 0

    with source_path.open(newline="", encoding="utf-8") as source_file:
        reader = csv.DictReader(source_file)
        with rejects_path.open("w", newline="", encoding="utf-8") as reject_file:
            reject_writer = csv.DictWriter(
                reject_file,
                fieldnames=["line_number", "reason", "source_record"],
            )
            reject_writer.writeheader()
            with connection.transaction():
                with connection.cursor() as cursor:
                    for line_number, row in enumerate(reader, start=2):
                        try:
                            transformed = transform_row(row)
                        except (ValueError, KeyError) as error:
                            reject_writer.writerow(
                                {
                                    "line_number": line_number,
                                    "reason": str(error),
                                    "source_record": row,
                                }
                            )
                            rejected += 1
                            continue

                        cursor.execute(
                            """
                            INSERT INTO etl_sales (
                                order_id, line_number, sold_at, customer_id,
                                product_id, quantity, unit_price
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s)
                            ON CONFLICT (order_id, line_number) DO UPDATE
                            SET sold_at = EXCLUDED.sold_at,
                                customer_id = EXCLUDED.customer_id,
                                product_id = EXCLUDED.product_id,
                                quantity = EXCLUDED.quantity,
                                unit_price = EXCLUDED.unit_price
                            """,
                            transformed,
                        )
                        loaded += 1

    return loaded, rejected


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the CSV-to-PostgreSQL ETL lab")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--rejects", type=Path, default=DEFAULT_REJECTS)
    args = parser.parse_args()

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("Set DATABASE_URL before running this ETL lab")

    import psycopg

    with psycopg.connect(database_url) as connection:
        loaded, rejected = run(connection, args.source, args.rejects)
    print(f"Loaded {loaded} rows; rejected {rejected} rows to {args.rejects}")


if __name__ == "__main__":
    main()
