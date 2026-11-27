from datetime import datetime

from airflow.sdk import Asset, dag, task

orders_asset = Asset("training://warehouse/public/orders")


@dag(
    dag_id="asset_orders_consumer",
    start_date=datetime(2025, 1, 1),
    schedule=[orders_asset],
    catchup=False,
    tags=["training", "assets"],
)
def asset_orders_consumer():
    @task
    def build_report() -> None:
        print("Building report after the orders asset was updated.")

    build_report()


asset_orders_consumer_dag = asset_orders_consumer()
