from datetime import datetime

from airflow.sdk import dag, get_current_context, task
from airflow.timetables.interval import CronDataIntervalTimetable


@dag(
    dag_id="data_interval_daily",
    start_date=datetime(2025, 1, 1),
    schedule=CronDataIntervalTimetable("0 2 * * *", timezone="UTC"),
    catchup=False,
    tags=["training", "data-interval"],
)
def data_interval_daily():
    @task
    def inspect_interval() -> dict[str, str]:
        context = get_current_context()
        start = context["data_interval_start"]
        end = context["data_interval_end"]
        print(
            "logical_date=%s data_interval=[%s, %s)"
            % (context["logical_date"], start, end)
        )
        return {"start": start.isoformat(), "end": end.isoformat()}

    inspect_interval()


data_interval_daily_dag = data_interval_daily()
