import csv
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Sequence


def write_interval_partition(
    interval_start: datetime,
    interval_end: datetime,
    records: Iterable[Sequence[str]],
    output_dir: Path,
) -> Path:
    if interval_start.tzinfo is None or interval_end.tzinfo is None:
        raise ValueError("Interval boundaries must be timezone-aware.")
    if interval_start >= interval_end:
        raise ValueError("Interval start must be before interval end.")

    start = interval_start.astimezone(timezone.utc)
    end = interval_end.astimezone(timezone.utc)
    partition_name = "%s__%s.csv" % (
        start.strftime("%Y%m%dT%H%M%SZ"),
        end.strftime("%Y%m%dT%H%M%SZ"),
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / partition_name

    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=partition_name + ".",
        suffix=".tmp",
        dir=str(output_dir),
        text=True,
    )
    try:
        with os.fdopen(file_descriptor, "w", newline="", encoding="utf-8") as file:
            writer = csv.writer(file)
            writer.writerow(["event_id", "amount"])
            writer.writerows(records)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary_name, destination)
    except Exception:
        if os.path.exists(temporary_name):
            os.remove(temporary_name)
        raise

    return destination
