import logging
from datetime import datetime

from airflow.sdk import Variable, dag, task

logger = logging.getLogger(__name__)


def log_task_failure(context: dict) -> None:
    task_instance = context.get("task_instance")
    exception = context.get("exception")
    logger.error(
        "Task failed: dag_id=%s task_id=%s run_id=%s error=%s",
        context.get("dag").dag_id if context.get("dag") else None,
        task_instance.task_id if task_instance else None,
        context.get("run_id"),
        exception,
    )


@dag(
    dag_id="observe_failure",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    tags=["training", "operations"],
)
def observe_failure():
    @task(on_failure_callback=log_task_failure)
    def process() -> str:
        should_fail = Variable.get(
            "training_force_failure", default_var="false"
        ).lower()
        if should_fail == "true":
            raise RuntimeError("Intentional failure enabled by Airflow Variable.")
        if should_fail != "false":
            raise ValueError(
                "Variable 'training_force_failure' must be 'true' or 'false'."
            )
        logger.info("Training task completed.")
        return "ok"

    process()


observe_failure_dag = observe_failure()
