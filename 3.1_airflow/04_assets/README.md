# Lab 04 — Asset scheduling

## Mục tiêu

Mô phỏng producer cập nhật bảng `training.public.orders` và phát Asset event
sau khi task thành công. DAG consumer được lên lịch bởi event đó.

## Chạy

Copy cả hai file trong `dags` vào thư mục DAG của Airflow. Đợi hai DAG được
parse, sau đó trigger `asset_orders_producer` từ UI. Không trigger consumer
trực tiếp.

## Kiểm tra

Xác nhận producer thành công, asset event xuất hiện trong UI và scheduler tạo
run cho `asset_orders_consumer`. Trong hệ thống thật, chỉ phát event sau khi
transaction cập nhật bảng nguồn commit thành công.
