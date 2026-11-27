# Airbyte: đồng bộ MySQL sang PostgreSQL

Lab này dùng MySQL làm nguồn `HRM.Employee`, PostgreSQL làm đích và Airbyte UI
để tạo Source, Destination, Connection và chạy sync. MySQL Server và PostgreSQL
dùng lại một Compose tại `1.4_linux_git_docker/docker/docker-compose.yml`;
Airbyte được cài riêng bằng `abctl`.

## 1. Khởi động database

Thêm các biến MySQL từ `.env.example` vào `.env` ở thư mục gốc. Tạo password
local riêng và không commit `.env`. Từ thư mục gốc chạy:

```powershell
docker compose --env-file .env -f 1.4_linux_git_docker/docker/docker-compose.yml up -d db mysql
```

Kết nối Workbench tới MySQL bằng `127.0.0.1:3307`; database là `HRM`. PostgreSQL
được mở tại `localhost:5432`. Compose bật MySQL binlog ở chế độ `ROW`, row image
`FULL`, và giữ binlog tối đa 10 ngày để lab có thể đọc CDC.

## 2. Tạo bảng và dữ liệu nguồn

Mở `sql/01_hrm_airbyte_lab.sql` trong MySQL Workbench, kết nối bằng user root
local, rồi chỉ chạy khối **MySQL — setup and seed**. Không chạy toàn bộ file:
nó còn có các khối thay đổi dữ liệu và câu truy vấn PostgreSQL ở cuối.

Khối setup tạo `HRM.Employee`, thêm ba nhân viên ban đầu và cấp quyền đọc/binlog
cho `data_platform`. Các khối insert, update và delete được chạy riêng từng bước
theo kịch bản bên dưới.

## 3. Cấu hình Airbyte UI

1. Cài Docker Desktop và `abctl`, sau đó cài Airbyte local theo
   [hướng dẫn abctl](https://docs.airbyte.com/platform/deploying-airbyte/abctl).
   Chọn và ghi lại một phiên bản Airbyte 2.x cụ thể; tránh thay đổi phiên bản
   giữa các lần sync. Ví dụ: `abctl local install --chart-version <2.x-version>`
   rồi kiểm tra bằng `abctl local status`. Ưu tiên phiên bản 2.3 trở lên; nếu
   chọn bản cũ hơn, làm theo lưu ý MinIO trong tài liệu abctl.
2. Tạo **MySQL Source**: host `host.docker.internal`, port `3307`, database
   `HRM`, user/password từ `.env`; chọn đọc thay đổi bằng **Binary Log (CDC)**.
3. Tạo **PostgreSQL Destination**: host `host.docker.internal`, port `5432`,
   cùng database/user/password đã cấu hình cho Compose. Để Airbyte tự tạo và
   quản lý các bảng stream.
4. Tạo Connection cho stream `HRM.Employee` trong từng mode cần so sánh, dùng
   schema đích riêng: `airbyte_hrm_full`, `airbyte_hrm_append` và
   `airbyte_hrm_deduped`. Chạy Full Refresh - Overwrite làm baseline;
   Incremental - Append để xem change events/delete marker; và Append + Deduped
   để kiểm tra current-state nếu mode đó được connector/version cho phép.

MySQL Workbench là client để chạy SQL; MySQL Server thực sự chạy trong Compose.
Airbyte chạy trong môi trường `abctl`, vì vậy dùng host/port đã publish thay vì
dùng tên service Compose `mysql` hoặc `db`.

## 4. Thử thay đổi và đối soát

Sau mỗi khối trong file SQL, chạy sync thủ công và ghi nhận:

| Thao tác | Số nhân viên hiện hành ở MySQL | Kết quả mong đợi ở PostgreSQL |
|---|---:|---|
| Seed ban đầu | 3 | Baseline có 3 nhân viên |
| Insert `EmployeeID = 104` | 4 | Bản ghi mới xuất hiện |
| Update `EmployeeID = 102` | 4 | Dữ liệu nhân viên được cập nhật |
| Delete `EmployeeID = 103` | 3 | CDC Append ghi nhận delete event; current-state không còn nhân viên 103 |

Đối soát nguồn bằng khối **MySQL — source reconciliation** và đích bằng khối
**PostgreSQL — destination reconciliation** trong cùng file SQL. Với Append,
đếm event rows trực tiếp sẽ lớn hơn số nhân viên hiện hành vì có lịch sử thay
đổi. Đếm riêng các hàng có `_ab_cdc_deleted_at` để xác nhận sự kiện xóa; với
Append + Deduped, kiểm tra trạng thái hiện hành và xác nhận nhân viên đã xóa
không còn trong kết quả. Các lệnh đối soát PostgreSQL trong file SQL dùng ba
schema này.

Airbyte CDC biểu diễn delete bằng `_ab_cdc_deleted_at` trên change record.
Theo [tài liệu CDC](https://docs.airbyte.com/platform/understanding-airbyte/cdc),
bản ghi có thay đổi mới nhất là delete có thể không xuất hiện trong bảng
final-state. Vì vậy không dùng số hàng của append history để đối chiếu trực
tiếp với số nhân viên hiện tại ở nguồn.

## Tự kiểm tra

- Incremental chỉ dựa vào `updated_at` có thể bỏ sót hard delete, cập nhật không
  đổi cursor, hoặc bản ghi đến trễ có cursor cũ. CDC dùng binlog để nhận cả
  insert/update/delete; MySQL cần binlog bật và giữ đủ lâu để Airbyte đọc tiếp.
- Xem cột `_ab_cdc_deleted_at` trong change events của Append. So sánh riêng
  số delete events với số dòng hiện hành sau sync.
- MySQL source connector hỗ trợ CDC bằng binlog. Các mode xuất hiện trong UI
  phụ thuộc phiên bản connector và stream; xem
  [tài liệu MySQL source](https://docs.airbyte.com/integrations/sources/mysql).
