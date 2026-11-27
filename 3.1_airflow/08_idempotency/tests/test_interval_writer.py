import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

SOURCE_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SOURCE_DIR))

from interval_writer import write_interval_partition


def test_rerunning_interval_replaces_partition_without_duplicate_rows(tmp_path):
    start = datetime(2025, 1, 1, tzinfo=timezone.utc)
    end = start + timedelta(days=1)
    records = [("event-001", "12.50"), ("event-002", "8.00")]

    first_path = write_interval_partition(start, end, records, tmp_path)
    first_content = first_path.read_text(encoding="utf-8")
    second_path = write_interval_partition(start, end, records, tmp_path)

    assert second_path == first_path
    assert second_path.read_text(encoding="utf-8") == first_content
    assert len(list(tmp_path.glob("*.csv"))) == 1
    assert len(first_content.splitlines()) == 3


@pytest.mark.parametrize(
    ("start", "end"),
    [
        (datetime(2025, 1, 1), datetime(2025, 1, 2)),
        (
            datetime(2025, 1, 2, tzinfo=timezone.utc),
            datetime(2025, 1, 1, tzinfo=timezone.utc),
        ),
    ],
)
def test_rejects_invalid_interval(start, end, tmp_path):
    with pytest.raises(ValueError):
        write_interval_partition(start, end, [], tmp_path)
