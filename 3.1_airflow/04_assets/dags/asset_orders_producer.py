from datetime import datetime

from airflow.sdk import Asset, dag, task

orders_asset = Asset("training://warehouse/public/orders")


@dag(
    dag_id="asset_orders_producer",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    tags=["training", "assets"],
)
def asset_orders_producer():
    @task(outlets=[orders_asset])
    def update_orders_table() -> int:
        row_count = 3
        print("Simulated source table update: %s rows" % row_count)
        return row_count

    update_orders_table()


asset_orders_producer_dag = asset_orders_producer()
