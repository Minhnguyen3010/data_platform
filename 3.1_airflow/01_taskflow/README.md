# Lab 01 — TaskFlow và dependency

## Mục tiêu

Tạo DAG bằng `@dag` và `@task` từ `airflow.sdk`; nối TaskFlow task với
`EmptyOperator` để biểu diễn cả hai dạng operator trong một workflow.

## Chạy

Copy `dags/taskflow_basics.py` vào thư mục DAG của Airflow, đợi DAG được parse,
rồi trigger `taskflow_basics` từ UI.

## Kiểm tra

Graph view phải thể hiện `start >> extract >> transform >> finish`. Xem task
logs và XCom để xác nhận `transform` nhận kết quả từ `extract`.
