# Lab 07 — Logging, monitoring, DAG versioning và xử lý lỗi

## Mục tiêu

Tạo một task có thể bật/tắt lỗi, ghi failure context qua callback và theo dõi
run bằng Airflow UI. Mỗi thay đổi nội dung DAG sau khi parse tạo một phiên bản
DAG mới để có thể so sánh trên UI.

## Chạy

Copy `dags/observe_failure.py` vào thư mục DAG của Airflow rồi trigger
`observe_failure`. Mặc định task thành công. Để tạo một run lỗi, đặt Airflow
Variable `training_force_failure` thành `true` rồi trigger lại. Đặt về `false`
để khôi phục.

## Kiểm tra

- Xem trạng thái Dag Run, task instance và log trong UI.
- Với run lỗi, xác nhận callback ghi `dag_id`, `task_id`, `run_id` và lỗi; sau
  đó xóa Variable hoặc đặt `false`, rồi clear task để chạy lại.
- Thay đổi một dòng trong DAG, đợi DAG processor parse lại và xem DAG version
  trong UI.
- Quan sát các run lỗi/thành công qua trang DAG. Metrics hệ thống cần được cấu
  hình riêng theo môi trường triển khai.
