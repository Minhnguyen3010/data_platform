# Lab 09 — Pipeline end-to-end tới bảng Gold

## Mục tiêu

Pipeline `gold_sales_pipeline` gồm ingestion, kiểm tra dữ liệu, một task cố ý
thất bại lần đầu, SQL transformation và xác nhận bảng Gold. DAG
`gold_sales_downstream` chạy theo Asset sau khi bảng Gold đã được xác nhận.

Lab dùng SQLite trên shared Docker volume để chạy được ngay với stack hiện tại;
đây là lựa chọn cho bài thực hành một worker, không phải thiết kế warehouse
production. Ingestion dùng khóa sự kiện ổn định và upsert, còn Gold có khóa
duy nhất theo ngày và được upsert bằng SQL.

## Chạy pipeline

Khởi động Airflow theo hướng dẫn tại README module, mở `http://localhost:8081`
và bật DAG `gold_sales_pipeline`. Trigger DAG một lần. Lịch của pipeline là
hằng ngày lúc 00:00 UTC theo `CronDataIntervalTimetable`.

Kiểm tra Graph và task logs:

1. `ingest_orders` nạp hai order mẫu trong data interval.
2. `validate_orders` kiểm tra số dòng, amount và status.
3. `retry_demo` ném exception ở lần thử đầu; lần retry thành công.
4. `transform_gold` chạy SQL trong `sql/02_transform_gold.sql`.
5. `assert_gold_updated` xác nhận có đúng một dòng Gold cho mỗi ngày, hai order
   và tổng amount là `20.00`. Task này phát Asset event sau khi thành công.
6. Scheduler kích hoạt `gold_sales_downstream` theo Asset đó.

## Backfill 7 ngày và kiểm tra không trùng

Tạo backfill với 7 logical dates, từ `2025-01-01` đến `2025-01-07` (bao gồm
cả hai ngày). DAG xử lý các khoảng dữ liệu UTC tương ứng `[2025-01-01,
2025-01-02)` đến `[2025-01-07, 2025-01-08)`.

Có thể tạo/chạy lại backfill qua CLI trong container scheduler:

```powershell
docker compose --env-file .env --profile airflow -f 1.4_linux_git_docker\docker\docker-compose.yml exec airflow-scheduler airflow backfill create --dag-id gold_sales_pipeline --from-date 2025-01-01 --to-date 2025-01-07 --reprocess-behavior completed
```

Sau khi backfill hoàn tất, chạy lại cùng lệnh. `completed` yêu cầu Airflow
reprocess các logical date đã hoàn thành. Sau mỗi lượt, kiểm tra bảng:

```powershell
docker compose --env-file .env --profile airflow -f 1.4_linux_git_docker\docker\docker-compose.yml exec airflow-worker python -c 'import sqlite3; c=sqlite3.connect("/opt/airflow/output/gold_pipeline.sqlite"); print(c.execute("SELECT COUNT(*), COUNT(DISTINCT sales_date), SUM(order_count), ROUND(SUM(gross_amount), 2) FROM gold_daily_sales WHERE sales_date >= ? AND sales_date < ?", ("2025-01-01", "2025-01-08")).fetchone())'
```

Kết quả mong đợi sau cả hai lượt là `(7, 7, 14, 140.0)`: bảy ngày Gold,
không có ngày trùng, 14 order và tổng amount `140.00`.

## Tự kiểm tra

- Với `CronTriggerTimetable` mặc định, trigger lúc 00:00 ngày 05/01 có logical
  date 05/01 00:00 và data interval mặc định có độ dài 0:
  `[05/01 00:00, 05/01 00:00)`. Cron trigger không tự suy ra khoảng dữ liệu
  của ngày trước. Nếu cấu hình `interval=timedelta(days=1)`, interval sẽ là
  `[04/01 00:00, 05/01 00:00)` trong khi logical date vẫn là 05/01 00:00.
- Với `CronDataIntervalTimetable`, run được kích hoạt lúc 00:00 ngày 05/01 có
  logical date 04/01 00:00 và xử lý interval
  `[04/01 00:00, 05/01 00:00)`.
- Chạy lại an toàn khi ingestion dùng event ID ổn định và upsert, còn Gold dùng
  khóa ngày và upsert. Nếu chỉ append, retry hoặc backfill có thể tạo dòng
  trùng. Bài này cố ý replay cả bảy interval để kiểm chứng.

## Test idempotency

```powershell
python -m pytest 3.1_airflow\09_end_to_end\tests -q
```
