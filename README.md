# data-platform

Kho lưu trữ các bài thực hành Data Engineering, được tổ chức theo các giai đoạn
học tập. Các giai đoạn đầu bao gồm thực hành PostgreSQL và Python; những giai đoạn
tiếp theo được bổ sung dần theo lộ trình.

## Cấu trúc

```text
data-platform/
├── 1.2_sql/
│   ├── schema/
│   ├── data/
│   ├── queries/
│   ├── performance/
│   └── README.md
├── 1.3_python/
│   ├── src/
│   │   ├── main.py
│   │   └── de_project/
│   ├── tests/
│   ├── logs/
│   ├── Dockerfile
│   └── requirements.txt
├── 1.4_linux_git_docker/
│   ├── docker/docker-compose.yml
│   └── scripts/
├── 2.1_data_modeling_dw/
│   ├── ddl/
│   ├── data/
│   ├── scd2/
│   ├── reports/
│   ├── docs/
│   └── README.md
├── 2.2_etl_elt_ingestion_cdc/
│   ├── 01_etl_batch/
│   ├── 02_elt_warehouse/
│   ├── 03_incremental_load/
│   ├── 04_cdc/query_based/
│   ├── 04_cdc/postgres_logical_replication/
│   ├── 05_pipeline_reliability/
│   ├── 06_airbyte_mysql_to_postgres/
│   └── README.md
├── 2.3_cdc_airbyte/
│   ├── airbyte/
│   ├── sql/
│   ├── reconciliation/
│   └── docs/
├── .env.example
└── pytest.ini
```

## Chạy phần Python hiện có

Yêu cầu Python 3.10+ (khuyến nghị 3.12) và PostgreSQL.

Tạo môi trường ảo ở thư mục gốc:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r 1.3_python\requirements.txt
```

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r 1.3_python/requirements.txt
```

Tạo `.env` từ `.env.example` nếu chưa có và điền thông tin PostgreSQL. Không
commit `.env`. Chạy pipeline từ thư mục gốc:

```bash
python 1.3_python/src/main.py
```

Pipeline lấy commit từ GitHub REST API, chuẩn hóa timestamp về UTC, bỏ qua
record không hợp lệ, tạo bảng `github_commits` và upsert theo `sha`. Log được
lưu tại `1.3_python/logs/ingestion.log`.

Chạy unit test từ thư mục gốc:

```bash
python -m pytest
```

Test không gọi Internet và không yêu cầu PostgreSQL đang chạy.

## Thực hành SQL

Phần [1.2_sql](1.2_sql/README.md) có schema PostgreSQL cho nhân viên và đơn
hàng, dữ liệu mẫu, 40 câu SQL, cùng benchmark execution plan trước/sau index.
Xem hướng dẫn chạy và giải thích mô hình trong README của module.

## PostgreSQL bằng Docker Compose

Điền các biến PostgreSQL, pgAdmin và MySQL trong `.env`, sau đó từ thư mục gốc chạy:

```bash
docker compose --env-file .env -f 1.4_linux_git_docker/docker/docker-compose.yml up --build
```

Compose chạy PostgreSQL, MySQL, chương trình Python và pgAdmin. Log ứng dụng
được gắn vào `1.3_python/logs/`. pgAdmin được mở tại `http://localhost:8080`.

Lab Airbyte dùng lại hai database này. Để chỉ khởi động PostgreSQL và MySQL:

```powershell
docker compose --env-file .env -f 1.4_linux_git_docker/docker/docker-compose.yml up -d db mysql
```

MySQL được mở trên `localhost:3307`; PostgreSQL dùng `localhost:5432`. Airbyte
được cài riêng bằng `abctl`, không chạy như một service Compose.

## Mô hình hóa dữ liệu kho (2.1)

Phần [2.1_data_modeling_dw](2.1_data_modeling_dw/README.md) thực hành star
schema với `dim_customer`, `dim_product`, `dim_date` và `fact_sales`; gồm nạp
lịch sử địa chỉ khách hàng theo SCD Type 2 và báo cáo doanh thu theo tháng,
sản phẩm, khu vực. Phần
[2.2_etl_elt_ingestion_cdc](2.2_etl_elt_ingestion_cdc/README.md) gồm các lab
ETL, ELT, incremental load, CDC, độ tin cậy pipeline và lab Airbyte đồng bộ
MySQL sang PostgreSQL. `2.3_cdc_airbyte` hiện là khung để phát triển tiếp.
