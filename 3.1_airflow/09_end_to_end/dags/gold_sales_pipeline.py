import logging
from datetime import datetime, timedelta
from pathlib import Path

from airflow.sdk import Asset, dag, get_current_context, task
from airflow.timetables.interval import CronDataIntervalTimetable

from gold_pipeline import (
    assert_gold_interval,
    get_database_path,
    initialize_database,
    ingest_interval,
    open_database,
    transform_interval,
    validate_interval,
)

logger = logging.getLogger(__name__)
gold_sales_asset = Asset("training://warehouse/gold_daily_sales")
lab_dir = Path(__file__).resolve().parents[1]


@dag(
    dag_id="gold_sales_pipeline",
    start_date=datetime(2025, 1, 1),
    schedule=CronDataIntervalTimetable("0 0 * * *", timezone="UTC"),
    catchup=False,
    max_active_runs=1,
    max_active_tasks=1,
    tags=["training", "end-to-end", "gold"],
)
def gold_sales_pipeline():
    @task
    def ingest_orders() -> int:
        context = get_current_context()
        with open_database(get_database_path()) as connection:
            initialize_database(connection, lab_dir / "sql" / "01_setup.sql")
            count = ingest_interval(
                connection,
                context["data_interval_start"],
                context["data_interval_end"],
            )
        logger.info("Ingested %s deterministic source orders.", count)
        return count

    @task
    def validate_orders() -> int:
        context = get_current_context()
        with open_database(get_database_path()) as connection:
            count = validate_interval(
                connection,
                context["data_interval_start"],
                context["data_interval_end"],
            )
        logger.info("Validated %s source orders.", count)
        return count

    @task(retries=1, retry_delay=timedelta(seconds=5))
    def retry_demo() -> None:
        context = get_current_context()
        if context["ti"].try_number == 1:
            raise RuntimeError("Intentional first-attempt failure for retry/log lab.")
        logger.info(
            "Intentional retry check passed on attempt %s.",
            context["ti"].try_number,
        )

    @task
    def transform_gold() -> None:
        context = get_current_context()
        with open_database(get_database_path()) as connection:
            transform_interval(
                connection,
                context["data_interval_start"],
                context["data_interval_end"],
                lab_dir / "sql" / "02_transform_gold.sql",
            )
        logger.info("Gold SQL transformation completed for this interval.")

    @task(outlets=[gold_sales_asset])
    def assert_gold_updated() -> dict[str, int | float]:
        context = get_current_context()
        with open_database(get_database_path()) as connection:
            summary = assert_gold_interval(
                connection,
                context["data_interval_start"],
                context["data_interval_end"],
            )
        logger.info("Gold assertion passed: %s", summary)
        return summary

    ingestion = ingest_orders()
    validation = validate_orders()
    retry_check = retry_demo()
    gold_transform = transform_gold()
    gold_assertion = assert_gold_updated()
    ingestion >> validation >> retry_check >> gold_transform >> gold_assertion


@dag(
    dag_id="gold_sales_downstream",
    start_date=datetime(2025, 1, 1),
    schedule=[gold_sales_asset],
    catchup=False,
    tags=["training", "asset", "gold"],
)
def gold_sales_downstream():
    @task
    def read_gold_after_asset() -> int:
        with open_database(get_database_path()) as connection:
            count = connection.execute(
                "SELECT COUNT(*) FROM gold_daily_sales"
            ).fetchone()[0]
        if count == 0:
            raise ValueError("Gold table has no rows after the asset event.")
        logger.info("Downstream observed %s Gold daily rows.", count)
        return count

    read_gold_after_asset()


gold_sales_pipeline_dag = gold_sales_pipeline()
gold_sales_downstream_dag = gold_sales_downstream()
