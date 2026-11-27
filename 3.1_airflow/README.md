# 3.1 Apache Airflow

Các lab nhỏ chạy trên Apache Airflow 3.1.7 qua Docker Compose. Compose dùng
CeleryExecutor với một worker, metadata database riêng và Redis; đây là stack
đơn máy để luyện tập, không có HA và không phải cấu hình production được Airflow
đảm bảo an toàn. Mỗi chủ đề có DAG riêng; DAG dùng TaskFlow API của Airflow 3
(`airflow.sdk`).

## Cấu trúc

```text
3.1_airflow/
├── 01_taskflow/
│   ├── dags/
│   └── README.md
├── 02_data_intervals/
│   ├── dags/
│   └── README.md
├── 03_backfill/
│   ├── dags/
│   └── README.md
├── 04_assets/
│   ├── dags/
│   └── README.md
├── 05_reliability/
│   ├── dags/
│   └── README.md
├── 06_connections_secrets/
│   ├── dags/
│   └── README.md
├── 07_observability/
│   ├── dags/
│   └── README.md
├── 08_idempotency/
│   ├── dags/
│   ├── src/
│   ├── tests/
│   └── README.md
└── 09_end_to_end/
    ├── dags/
    ├── sql/
    ├── src/
    ├── tests/
    └── README.md
```

## Yêu cầu và cách chạy

- Docker Desktop với ít nhất 4 GB RAM cho Docker Engine.
- Tạo `.env` từ `.env.example` nếu chưa có; không ghi đè `.env` hiện tại.
  Thay các placeholder Airflow bằng giá trị riêng, tạo secrets mới cho
  `AIRFLOW_DB_PASSWORD`, `AIRFLOW_REDIS_PASSWORD`, `AIRFLOW_FERNET_KEY`,
  `AIRFLOW_API_SECRET_KEY` và `AIRFLOW_ADMIN_PASSWORD`.
- Từ thư mục gốc repo, khởi chạy Airflow và các dependency của nó:

  ```powershell
  docker compose --env-file .env --profile airflow -f 1.4_linux_git_docker\docker\docker-compose.yml up -d airflow-apiserver airflow-scheduler airflow-dag-processor airflow-worker airflow-triggerer
  ```

- Mở `http://localhost:8081` và đăng nhập bằng `AIRFLOW_ADMIN_USERNAME` cùng
  `AIRFLOW_ADMIN_PASSWORD` trong `.env`. API server chỉ bind vào loopback.
- Các DAG trong module được mount read-only và tự được DAG processor phát hiện.
  `src` và `tests` được loại khỏi quá trình parse bằng `.airflowignore`.
- Compose cấp sẵn `PYTHONPATH` và shared output volume cho lab 08 và lab 09.
  Chạy test idempotency trên host bằng lệnh trong README của lab.

Không xóa volume để khắc phục lỗi một cách tùy tiện: `airflow_pgdata` chứa
metadata và trạng thái Airflow; các volume khác chứa logs và output lab.

## Các lab

### 01 — DAG, task, operator và dependency

Tạo pipeline TaskFlow gồm `extract` và `transform`, nối với
`EmptyOperator` để thấy dependency giữa TaskFlow task và classic operator.
Xem [hướng dẫn lab 01](01_taskflow/README.md).

### 02 — Schedule và data interval

Dùng `CronDataIntervalTimetable` tường minh, đọc `data_interval_start` và
`data_interval_end`, rồi kiểm tra các giá trị trong task log. Xem
[hướng dẫn lab 02](02_data_intervals/README.md).

### 03 — Backfill

Tạo các DAG run lịch sử qua scheduler, rồi kiểm tra interval được task xử lý.
Lab chỉ tạo log quan sát, không ghi vào kho dữ liệu. Xem
[hướng dẫn lab 03](03_backfill/README.md).

### 04 — Asset scheduling

Chạy DAG nguồn để phát sự kiện cho asset đại diện một bảng, rồi quan sát DAG
tiêu thụ được scheduler kích hoạt. Xem [hướng dẫn lab 04](04_assets/README.md).

### 05 — Retry, timeout, trigger rule và deadline alert

Mô phỏng task lỗi lần đầu để xem retry, đặt timeout và chạy task tổng kết với
`all_done`. Deadline alert là tính năng thử nghiệm của Airflow 3.1. Xem
[hướng dẫn lab 05](05_reliability/README.md).

### 06 — Connections, Variables và secrets backend

Đọc connection cùng variable trong task mà không log hoặc đưa password vào
XCom. Xem [hướng dẫn lab 06](06_connections_secrets/README.md).

### 07 — Logging, monitoring, DAG versioning và xử lý lỗi

Chủ động bật lỗi bằng Airflow Variable, kiểm tra failure callback, task log,
trạng thái run và các phiên bản DAG trên UI. Xem
[hướng dẫn lab 07](07_observability/README.md).

### 08 — Idempotency theo data interval

Ghi dữ liệu mẫu vào partition xác định bởi interval bằng thao tác atomic
replace; chạy lại cùng interval không tạo thêm dòng. Ví dụ dùng file local để
giữ lab nhỏ, không phù hợp làm output dùng chung cho worker phân tán. Xem
[hướng dẫn lab 08](08_idempotency/README.md).

### 09 — Pipeline end-to-end tới bảng Gold

Thực hành ingestion, kiểm tra dữ liệu, SQL transformation, xác nhận bảng Gold,
retry có chủ đích, downstream DAG theo Asset và backfill 7 ngày. Chạy lại
backfill để xác nhận không sinh dòng trùng. Xem
[hướng dẫn lab 09](09_end_to_end/README.md).

Các lab không cài provider kết nối cơ sở dữ liệu và không chứa credential. Khi
thay dữ liệu mẫu bằng hệ thống thật, cấu hình provider, shared storage và
connections phù hợp với môi trường triển khai.
