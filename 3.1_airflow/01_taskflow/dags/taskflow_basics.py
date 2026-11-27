from datetime import datetime

from airflow.providers.standard.operators.empty import EmptyOperator
from airflow.sdk import dag, task


@dag(
    dag_id="taskflow_basics",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    tags=["training", "taskflow"],
)
def taskflow_basics():
    start = EmptyOperator(task_id="start")

    @task
    def extract() -> list[int]:
        return [10, 20, 30]

    @task
    def transform(values: list[int]) -> int:
        return sum(values)

    finish = EmptyOperator(task_id="finish")
    start >> transform(extract()) >> finish


taskflow_basics_dag = taskflow_basics()
