# Lab 08 — Idempotency theo data interval

## Mục tiêu

Ghi một partition xác định bởi `data_interval_start` và
`data_interval_end`. Cùng một interval luôn được ghi vào cùng file bằng atomic
replace thay vì append, nên chạy lại không làm nhân đôi dữ liệu.

## Chuẩn bị và chạy

Compose của module tự cấu hình `PYTHONPATH` trên DAG processor và worker, đồng
thời gắn shared volume tại `/opt/airflow/output`. Sau khi trigger hoặc backfill
DAG, output được ghi vào volume đó.

Chạy test từ thư mục gốc repo:

```powershell
python -m pytest 3.1_airflow\08_idempotency\tests
```

## Kiểm tra

Chạy lại cùng interval: file partition phải được thay thế và vẫn chỉ có header
cùng ba record mẫu. Đây là ví dụ local đơn giản; khi dùng nhiều worker hoặc
production, thay local filesystem bằng object storage hay warehouse có thao
tác ghi atomic/upsert phù hợp.
