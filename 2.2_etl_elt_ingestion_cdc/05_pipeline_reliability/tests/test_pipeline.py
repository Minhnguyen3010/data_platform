import csv
import sqlite3

from pipeline import _retry_sqlite, run_pipeline


def write_events(path, rows):
    with path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=["event_id", "customer_id", "amount"])
        writer.writeheader()
        writer.writerows(rows)


def test_pipeline_checkpoints_rejects_bad_rows_and_upserts_duplicates(tmp_path):
    source = tmp_path / "events.csv"
    database = tmp_path / "state.db"
    write_events(
        source,
        [
            {"event_id": "evt-1", "customer_id": "C-1", "amount": "12.50"},
            {"event_id": "evt-2", "customer_id": "C-2", "amount": "bad"},
            {"event_id": "evt-1", "customer_id": "C-1", "amount": "15.00"},
        ],
    )

    assert run_pipeline(source, database) == (2, 1, 3)
    assert run_pipeline(source, database) == (0, 0, 3)

    with sqlite3.connect(database) as connection:
        assert connection.execute("SELECT count(*) FROM target_events").fetchone()[0] == 1
        assert connection.execute(
            "SELECT amount FROM target_events WHERE event_id = 'evt-1'"
        ).fetchone()[0] == "15.00"
        assert connection.execute("SELECT count(*) FROM dead_letter").fetchone()[0] == 1


def test_retry_retries_transient_database_operation():
    attempts = 0

    def operation():
        nonlocal attempts
        attempts += 1
        if attempts < 3:
            raise sqlite3.OperationalError("temporary lock")
        return "done"

    assert _retry_sqlite(operation, max_attempts=3, delay_seconds=0) == "done"
    assert attempts == 3
