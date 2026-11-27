import logging
from datetime import datetime, timedelta

from airflow.sdk import dag, get_current_context, task
from airflow.sdk.definitions.deadline import (
    AsyncCallback,
    DeadlineAlert,
    DeadlineReference,
)
from airflow.task.trigger_rule import TriggerRule

logger = logging.getLogger(__name__)


async def log_deadline_missed(context: dict) -> None:
    logger.warning(
        "DAG deadline missed: dag_id=%s run_id=%s",
        context.get("dag_id"),
        context.get("run_id"),
    )


@dag(
    dag_id="reliability_controls",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    deadline=DeadlineAlert(
        reference=DeadlineReference.DAGRUN_LOGICAL_DATE,
        interval=timedelta(minutes=30),
        callback=AsyncCallback(callback_callable=log_deadline_missed),
    ),
    tags=["training", "reliability"],
)
def reliability_controls():
    @task(
        retries=1,
        retry_delay=timedelta(seconds=5),
        execution_timeout=timedelta(minutes=1),
    )
    def retry_once() -> str:
        context = get_current_context()
        if context["ti"].try_number == 1:
            raise RuntimeError("Intentional first-attempt failure for the lab.")
        return "succeeded after retry"

    @task(trigger_rule=TriggerRule.ALL_DONE)
    def summarize() -> None:
        print("Summary task ran after the upstream task reached a terminal state.")

    summarize_task = summarize()
    retry_once() >> summarize_task


reliability_controls_dag = reliability_controls()
