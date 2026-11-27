# Lab 06 — Connections, Variables và secrets backend

## Mục tiêu

Đọc Connection và Variable trong task runtime qua Airflow SDK. Connection chỉ
được dùng để lấy thông tin cấu hình; task không in password hoặc đưa secret
vào XCom.

## Chuẩn bị

Trong UI, tạo Connection có ID `training_api`, host `https://example.invalid`
và password là một giá trị giả để thực hành. Tạo Variable
`training_batch_size` với giá trị `100`. Không dùng credential thật trong lab.

## Chạy và kiểm tra

Copy `dags/read_airflow_config.py` vào thư mục DAG của Airflow rồi trigger
`read_airflow_config`. Task log chỉ in host và batch size. Có thể cấu hình
secrets backend của môi trường Airflow và tạo lại cùng connection/variable để
kiểm tra cơ chế phân giải; không commit secrets backend credentials vào repo.
