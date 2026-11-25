# 1.2 SQL và cơ sở dữ liệu quan hệ (PostgreSQL)

Thực hành truy vấn, kết hợp, kiểm tra và biến đổi dữ liệu; thiết kế lược đồ
quan hệ, hiểu transaction và đọc execution plan.

## Mục tiêu học tập

- Dùng `SELECT`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY` và các loại `JOIN`.
- Viết CTE, subquery, `CASE`, hàm cửa sổ và truy vấn bản ghi mới nhất theo nhóm.
- Thực hành `INSERT`, `UPDATE`, `DELETE`, `INSERT ... ON CONFLICT` và `MERGE`.
- Hiểu `NULL`, kiểu thời gian/múi giờ, số thập phân, khóa và constraint.
- Thiết kế dữ liệu chuẩn hóa, dùng transaction an toàn và tư duy xử lý theo tập hợp.
- Đọc `EXPLAIN (ANALYZE, BUFFERS)` và đánh giá tác động của index.

## Cấu trúc

```text
1.2_sql/
├── schema/01_schema.sql
├── data/01_seed.sql
├── queries/01_sql_exercises.sql
├── performance/01_index_comparison.sql
└── README.md
```

## Mô hình dữ liệu

`departments` 1—N `employees`; nhân viên có thể tham chiếu một nhân viên quản
lý khác. `customers` 1—N `orders`; mỗi đơn hàng do một nhân viên phụ trách.
`orders` 1—N `order_items`; mỗi dòng đơn hàng tham chiếu một `product`.
Thông tin sản phẩm, khách hàng, nhân viên và phòng ban chỉ được lưu tại bảng
tương ứng; giá bán tại thời điểm đặt hàng được lưu riêng trong
`order_items.unit_price`.

Các khóa chính, khóa ngoại, `UNIQUE`, `NOT NULL`, `CHECK` và kiểu `NUMERIC`
đảm bảo tính toàn vẹn. Khóa ngoại bảo đảm tham chiếu hợp lệ nhưng không tự tạo
index ở cột tham chiếu. Các index phục vụ benchmark được tạo riêng trong thư mục
`performance/`.

Seed tạo 8 phòng ban, 100 nhân viên, 5.000 khách hàng, 200 sản phẩm, 60.000 đơn
hàng và các dòng hàng tương ứng. Dữ liệu có phân bố trạng thái và ngày cố định
để có thể chạy lại và so sánh. Dữ liệu benchmark là dữ liệu tổng hợp, không phải
dữ liệu sản xuất.

## Cài đặt và chạy

Yêu cầu PostgreSQL 15+ (câu lệnh `MERGE` trong bài tập cần PostgreSQL 15 trở
lên). Tạo database rỗng, ví dụ:

```sql
CREATE DATABASE sql_practice;
```

Từ thư mục gốc repository, dùng `psql` để tạo bảng rồi nạp dữ liệu:

```powershell
psql -d sql_practice -v ON_ERROR_STOP=1 -f 1.2_sql\schema\01_schema.sql
psql -d sql_practice -v ON_ERROR_STOP=1 -f 1.2_sql\data\01_seed.sql
```

Chạy các truy vấn thực hành:

```powershell
psql -d sql_practice -v ON_ERROR_STOP=1 -f 1.2_sql\queries\01_sql_exercises.sql
```

Chạy so sánh execution plan trước và sau khi tạo index:

```powershell
psql -d sql_practice -v ON_ERROR_STOP=1 -f 1.2_sql\performance\01_index_comparison.sql
```

Trên Linux/macOS, đổi dấu `\` trong đường dẫn thành `/`. Có thể cấu hình kết
nối bằng `PGHOST`, `PGPORT`, `PGUSER` và `PGDATABASE` hoặc dùng `-h`, `-p`, `-U`.
Không đưa mật khẩu vào câu lệnh hoặc commit thông tin xác thực.

Schema có thể chạy lại mà không xóa dữ liệu; seed dùng `ON CONFLICT DO NOTHING`.
Để benchmark có ý nghĩa sau khi nạp dữ liệu lần đầu, hãy chạy toàn bộ script
trên database riêng. Script benchmark tự xóa các index benchmark lần trước để
phần đầu luôn đo baseline chưa có index, rồi chạy `ANALYZE` trước khi đo.

## Bộ bài tập: 40 câu

`queries/01_sql_exercises.sql` có 40 ví dụ theo nhóm:

1. Truy vấn cơ bản, lọc, sắp xếp, tổng hợp và JOIN.
2. Báo cáo doanh thu theo tháng; CTE, subquery và hàm cửa sổ.
3. Xếp hạng nhân viên và tìm đơn hàng mới nhất của mỗi khách hàng.
4. `NULL`, khoảng thời gian, `NUMERIC` và view.
5. DML, UPSERT, MERGE và transaction. Các ví dụ thay đổi dữ liệu nằm trong
   transaction kết thúc bằng `ROLLBACK` để không làm thay đổi bộ dữ liệu mẫu.

Doanh thu được tính từ `quantity * unit_price` của đơn hàng `shipped` hoặc
`completed`; đơn `cancelled` không được tính. Tháng báo cáo được chốt theo UTC
bằng `order_date AT TIME ZONE 'UTC'`. `timestamptz` biểu diễn một thời điểm
tuyệt đối nhưng hiển thị theo timezone của session; cần chọn timezone rõ ràng
khi gom nhóm theo ngày/tháng. Khoảng ngày nên viết nửa mở
(`>= đầu_kỳ AND < đầu_kỳ_tiếp_theo`) để tránh lỗi biên.

## Hiệu năng và execution plan

Script `performance/01_index_comparison.sql` đo ba truy vấn đại diện trước và
sau khi thêm index:

1. Doanh thu theo tháng: lọc đơn đã giao/hoàn tất theo thời gian.
2. Xếp hạng nhân viên: tổng doanh thu theo nhân viên.
3. Đơn gần nhất của mỗi khách hàng: `DISTINCT ON` theo thời gian giảm dần.

Mỗi truy vấn dùng `EXPLAIN (ANALYZE, BUFFERS)`. So sánh actual execution time,
estimated/actual rows, loại scan, số vòng lặp và shared blocks đọc/đã cache.
`EXPLAIN ANALYZE` thực thi câu `SELECT`; không chạy benchmark trên truy vấn ghi
dữ liệu nếu chưa hiểu tác động. Index không đảm bảo plan sẽ đổi: planner cân
nhắc thống kê, kích thước bảng, độ chọn lọc và chi phí đọc tuần tự. Trên dữ liệu
nhỏ, sequential scan vẫn có thể nhanh hơn.

## Khái niệm cần ghi nhớ

- **Set-based:** mô tả tập kết quả mong muốn bằng một câu SQL thay vì vòng lặp
  xử lý từng bản ghi ở ứng dụng.
- **NULL:** `= NULL` không trả về true/false mà là unknown; dùng `IS NULL`,
  `IS NOT NULL` hoặc `IS NOT DISTINCT FROM`. Điều kiện trong `WHERE` giữ lại
  chỉ các dòng true.
- **JOIN:** điều kiện nối quyết định cách ghép hàng. Với `LEFT JOIN`, đặt điều
  kiện lọc bảng phải trong `WHERE` có thể loại hàng không khớp và biến kết quả
  thành hành vi giống `INNER JOIN`.
- **Transaction:** nhóm thay đổi thành một đơn vị; dùng `COMMIT` khi xác nhận,
  `ROLLBACK` khi cần hủy. Có thể dùng savepoint để quay lui một phần.
- **Index:** tăng tốc một số lần đọc nhưng tiêu tốn dung lượng và làm tăng chi
  phí `INSERT`/`UPDATE`/`DELETE`; chọn theo workload, không tạo index cho mọi cột.
- **EXPLAIN:** ước tính plan; **EXPLAIN ANALYZE** chạy truy vấn và báo số liệu
  thực tế. Đối chiếu ước tính với thực tế để phát hiện thống kê hoặc giả định
  chọn lọc không chính xác.
- **Normalization:** tách dữ liệu theo thực thể để tránh lặp và bất nhất; dùng
  khóa ngoại và constraint để bảo vệ quan hệ.

