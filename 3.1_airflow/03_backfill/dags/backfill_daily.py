from datetime import datetime

from airflow.sdk import dag, get_current_context, task
from airflow.timetables.interval import CronDataIntervalTimetable


@dag(
    dag_id="backfill_daily",
    start_date=datetime(2025, 1, 1),
    schedule=CronDataIntervalTimetable("0 0 * * *", timezone="UTC"),
    catchup=False,
    tags=["training", "backfill"],
)
def backfill_daily():
    @task
    def process_interval() -> str:
        context = get_current_context()
        start = context["data_interval_start"]
        end = context["data_interval_end"]
        result = "processing interval [%s, %s)" % (start, end)
        print(result)
        return result

    process_interval()


backfill_daily_dag = backfill_daily()
