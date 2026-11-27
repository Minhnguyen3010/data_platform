import os
from datetime import datetime
from pathlib import Path

from airflow.sdk import dag, get_current_context, task
from airflow.timetables.interval import CronDataIntervalTimetable

from interval_writer import write_interval_partition


@dag(
    dag_id="idempotent_interval_load",
    start_date=datetime(2025, 1, 1),
    schedule=CronDataIntervalTimetable("0 0 * * *", timezone="UTC"),
    catchup=False,
    tags=["training", "idempotency"],
)
def idempotent_interval_load():
    @task
    def write_partition() -> str:
        context = get_current_context()
        output_dir = Path(
            os.environ.get(
                "AIRFLOW_LAB_OUTPUT_DIR",
                str(Path(__file__).resolve().parents[1] / "output"),
            )
        )
        records = [
            ("event-001", "12.50"),
            ("event-002", "8.00"),
            ("event-003", "21.25"),
        ]
        output = write_interval_partition(
            context["data_interval_start"],
            context["data_interval_end"],
            records,
            output_dir,
        )
        print("Wrote interval partition: %s" % output)
        return str(output)

    write_partition()


idempotent_interval_load_dag = idempotent_interval_load()
