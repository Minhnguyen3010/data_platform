# 2.2 ETL, ELT, incremental load và CDC

Các lab nhỏ dùng PostgreSQL 16, Python 3.10+ và Airbyte:

1. `01_etl_batch`: biến đổi CSV trước khi nạp vào PostgreSQL.
2. `02_elt_warehouse`: nạp payload JSON thô rồi dùng SQL tạo bảng mart.
3. `03_incremental_load`: so sánh full load, cursor thời gian và ID tăng dần.
4. `04_cdc`: so sánh query-based CDC và PostgreSQL logical replication; thực
   hành update, hard delete và soft delete.
5. `05_pipeline_reliability`: retry, checkpoint, upsert idempotent và dead
   letter cho bản ghi lỗi.
6. `06_airbyte_mysql_to_postgres`: đồng bộ `HRM.Employee` từ MySQL sang
   PostgreSQL qua Airbyte UI; MySQL và PostgreSQL dùng chung Compose, Airbyte
   được cài riêng bằng `abctl`.

## Yêu cầu

- PostgreSQL 16; các lab database và lab Airbyte cần Docker Engine đang chạy.
- Python 3.10+ cho lab ETL và pipeline reliability.
- Lab Airbyte cần MySQL 8.0 trong Compose và `abctl` cài Airbyte local.
- Cài dependencies Python từ thư mục gốc:

  ```powershell
  pip install -r 1.3_python\requirements.txt
  ```

Các lab SQL chạy trên database thực hành riêng; ví dụ lệnh dưới dùng
`etl_lab`, `elt_lab` và `incremental_lab`. Tạo database trước bằng `CREATE
DATABASE ...;`.

## Chạy lab

### 01 — ETL batch

Tạo bảng đích và chạy từ thư mục gốc:

```powershell
psql -d etl_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\01_etl_batch\sql\01_schema.sql
python 2.2_etl_elt_ingestion_cdc\01_etl_batch\src\etl.py
```

Đặt biến `DATABASE_URL` để kết nối. Ví dụ trong PowerShell:

```powershell
$env:DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/etl_lab"
```

CSV được kiểm tra và chuẩn hóa trong Python trước khi ghi vào Postgres. Dòng
không hợp lệ được xuất sang `01_etl_batch\output\rejected.csv`; bản ghi hợp lệ
được upsert theo khóa order-line để chạy lại không tạo dòng trùng.

### 02 — ELT warehouse

Chạy lần lượt trên database `elt_lab`:

```powershell
psql -d elt_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\02_elt_warehouse\sql\01_setup.sql
psql -d elt_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\02_elt_warehouse\sql\02_seed_raw.sql
psql -d elt_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\02_elt_warehouse\sql\03_transform.sql
psql -d elt_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\02_elt_warehouse\sql\04_assertions.sql
```

Payload giữ ở vùng `raw`; phép ép kiểu, xử lý field tùy chọn và upsert mart
được thực hiện trong PostgreSQL.

### 03 — Full và incremental load

Chạy `01_setup.sql`, `02_full_load.sql`, rồi `03_append_source_events.sql`.
Chạy cả `04_incremental_by_timestamp.sql` và
`05_incremental_by_id.sql` (mỗi script có checkpoint và bảng đích riêng), rồi
chạy lại cả hai để kiểm tra tính idempotent. `06_assertions.sql` đối chiếu kết
quả hai chiến lược.

### 04 — CDC

Lab query-based dùng change log và cursor theo thời gian kết hợp ID sự kiện.
Trên database `incremental_lab`, chạy lần lượt:

```powershell
psql -d incremental_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\04_cdc\query_based\sql\01_setup.sql
psql -d incremental_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\04_cdc\query_based\sql\02_full_load.sql
psql -d incremental_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\04_cdc\query_based\sql\03_append_changes.sql
psql -d incremental_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\04_cdc\query_based\sql\04_poll_changes.sql
psql -d incremental_lab -v ON_ERROR_STOP=1 -f 2.2_etl_elt_ingestion_cdc\04_cdc\query_based\sql\05_assertions.sql
```

Chạy `04_poll_changes.sql` lần nữa để kiểm tra checkpoint không nạp lại sự
kiện. Bản ghi soft-deleted còn ở đích với cờ `is_deleted`; hard-delete event
xóa bản ghi khỏi đích.

Lab PostgreSQL log-based: từ thư mục gốc, chuyển vào project và copy
`.env.example` thành `.env`:

```powershell
Set-Location 2.2_etl_elt_ingestion_cdc\04_cdc\postgres_logical_replication
Copy-Item .env.example .env
docker compose up -d --wait
docker compose exec source psql -U cdc_user -d cdc_lab -f /seed/01_source.sql
docker compose exec target psql -U cdc_user -d cdc_lab -f /seed/02_target.sql
docker compose exec target psql -U cdc_user -d cdc_lab -f /seed/03_subscribe.sql
```

Áp dụng thay đổi nguồn và kiểm tra:

```powershell
docker compose exec source psql -U cdc_user -d cdc_lab -f /seed/04_changes.sql
docker compose exec target psql -U cdc_user -d cdc_lab -f /seed/05_assertions.sql
docker compose down -v
Set-Location ..\..\..
```

### 05 — Độ tin cậy pipeline

```powershell
python 2.2_etl_elt_ingestion_cdc\05_pipeline_reliability\src\pipeline.py
```

Kết quả đích, dead-letter và checkpoint nằm trong SQLite local của lab. Xóa
file database lab khi muốn bắt đầu lại.

### 06 — Airbyte MySQL sang PostgreSQL

Xem [hướng dẫn Airbyte HRM](06_airbyte_mysql_to_postgres/README.md). Lab bật
service MySQL bằng profile `airbyte` trong Compose hiện có, cài Airbyte bằng
`abctl`, cấu hình Source/Destination/Connection trên UI và chạy các khối trong
một file SQL theo thứ tự có sync xen giữa.

Chạy các test Python từ thư mục gốc bằng `python -m pytest`.

## Lý thuyết cần phân biệt

- **ETL và ELT:** ETL biến đổi trước khi ghi vào kho; ELT nạp dữ liệu thô trước,
  sau đó biến đổi bằng khả năng tính toán của kho.
- **CDC:** log-based đọc transaction log và thường phù hợp luồng gần real-time;
  query-based dò bảng theo cursor/polling và dễ triển khai nhưng phụ thuộc cột
  theo dõi, có thể bỏ sót hard delete nếu không có tombstone.
- PostgreSQL logical replication là ví dụ log-based; SQL Server CDC và Oracle
  LogMiner là các lựa chọn theo nền tảng. Lab CDC triển khai PostgreSQL.
- **Batch** xử lý theo lô ở các thời điểm định kỳ; **near-real-time** chuyển
  thay đổi với độ trễ thấp nhưng vẫn có thể chạy bất đồng bộ theo micro-batch.
- Hard delete xóa hẳn dòng; soft delete giữ dòng với cờ trạng thái. CDC log-based
  có thể phát sự kiện delete; query-based thường cần cờ `is_deleted` hoặc bảng
  tombstone để nhận biết xóa.
- Cursor thời gian cần xử lý timestamp trùng và bản ghi đến trễ; cursor ID tăng
  dần phù hợp nguồn append-only nhưng không tự phát hiện cập nhật cũ.
- Schema drift/evolution và đối soát số lượng/tổng kiểm được minh họa trong lab
  ELT; hệ thống thật cần quy định rõ thay đổi nào tương thích và cách xử lý
  thay đổi phá vỡ schema.
