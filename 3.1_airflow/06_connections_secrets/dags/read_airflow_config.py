from datetime import datetime

from airflow.sdk import BaseHook, Variable, dag, task


@dag(
    dag_id="read_airflow_config",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    tags=["training", "connections", "secrets"],
)
def read_airflow_config():
    @task
    def read_config() -> dict[str, str | int]:
        connection = BaseHook.get_connection("training_api")
        batch_size = int(Variable.get("training_batch_size", default_var="100"))

        if not connection.host:
            raise ValueError("Connection 'training_api' must define a host.")

        print("Using configured endpoint: %s" % connection.host)
        return {"host": connection.host, "batch_size": batch_size}

    read_config()


read_airflow_config_dag = read_airflow_config()
