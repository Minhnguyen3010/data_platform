# 2.1 Mô hình dữ liệu kho dữ liệu

Bài thực hành thiết kế star schema cho doanh thu bán hàng, lưu lịch sử địa chỉ
khách hàng bằng SCD Type 2 và truy vấn doanh thu theo tháng, sản phẩm, khu vực.
Các script dùng PostgreSQL 15+ và nên chạy trên database thực hành riêng.

## Mô hình

- `dim_date`: một dòng cho mỗi ngày; `date_key` có dạng `YYYYMMDD`.
- `dim_customer`: một dòng cho mỗi phiên bản khách hàng. `customer_id` là khóa
  nghiệp vụ ổn định, `customer_sk` là khóa thay thế. Mỗi phiên bản có khoảng
  hiệu lực nửa mở `[valid_from, valid_to)`; bản hiện hành kết thúc ở
  `9999-12-31`. `region` thuộc phiên bản địa chỉ nên lịch sử khu vực cũng được
  giữ lại.
- `dim_product`: một dòng cho mỗi sản phẩm, định danh bởi `product_id`.
- `fact_sales`: một dòng cho mỗi dòng sản phẩm trong một đơn hàng nguồn.
  `sales_amount` được tính từ `quantity * unit_price`.

**Grain của `fact_sales`: một dòng đơn hàng (order line) cho một sản phẩm.**
Khóa duy nhất `(source_order_id, source_line_number)` ngăn nạp trùng cùng một
dòng nguồn. Một đơn có nhiều sản phẩm tạo nhiều dòng fact; không phải một dòng
cho cả đơn hàng hoặc một dòng tổng hợp theo ngày.

## Chạy lần đầu

Từ thư mục gốc repository, tạo bảng rồi nạp dữ liệu mẫu:

```powershell
psql -d dw_practice -v ON_ERROR_STOP=1 -f 2.1_data_modeling_dw\ddl\01_star_schema.sql
psql -d dw_practice -v ON_ERROR_STOP=1 -f 2.1_data_modeling_dw\data\01_seed.sql
psql -d dw_practice -v ON_ERROR_STOP=1 -f 2.1_data_modeling_dw\scd2\01_customer_scd2_load.sql
psql -d dw_practice -v ON_ERROR_STOP=1 -f 2.1_data_modeling_dw\scd2\02_load_fact_sales.sql
psql -d dw_practice -v ON_ERROR_STOP=1 -f 2.1_data_modeling_dw\reports\01_monthly_revenue.sql
```

Tạo database trước bằng `CREATE DATABASE dw_practice;`. Dữ liệu staging trong
`data/01_seed.sql` có một thay đổi địa chỉ của `C001` hiệu lực từ 2024-07-01.
Script SCD2 đóng phiên bản North ở ngày đó và mở phiên bản Central. Sau đó mới
nạp fact để mỗi dòng bán hàng tham chiếu đúng phiên bản khách hàng theo ngày
bán. Script nạp dimension và fact có thể chạy lại với dữ liệu mẫu.

## SCD Type 2

Khi thuộc tính theo dõi thay đổi, loader:

1. Đặt `valid_to` của phiên bản hiện hành bằng ngày hiệu lực và đánh dấu không
   còn hiện hành.
2. Thêm một dòng với cùng `customer_id`, thông tin mới, `valid_from` là ngày
   hiệu lực và `valid_to = 9999-12-31`.

Ngày kết thúc không bao gồm trong phiên bản cũ; do đó ngày hiệu lực thuộc phiên
bản mới. Ràng buộc unique index đảm bảo mỗi khách hàng tối đa có một phiên bản
hiện hành. Loader từ chối ngày hiệu lực không muộn hơn `valid_from` của phiên
bản hiện tại. Trong hệ thống thực tế cần quản lý thêm thứ tự và kiểm tra các
snapshot đến trễ; script này tập trung vào một snapshot hiện hành cho bài tập.

Fact giữ `customer_sk` thay vì chỉ giữ khóa nghiệp vụ. Báo cáo dùng phiên bản
địa chỉ được áp dụng tại lúc phát sinh giao dịch:

- Doanh thu tháng 3 của `C001` thuộc khu vực **North**.
- Doanh thu tháng 8 của `C001` thuộc khu vực **Central**.

Vì vậy, **khi khách hàng đổi địa chỉ, báo cáo doanh thu theo khu vực của tháng
trước không thay đổi**. Dòng fact cũ vẫn tham chiếu `customer_sk` của phiên bản
địa chỉ cũ; phiên bản mới chỉ được nối vào các giao dịch từ ngày hiệu lực trở
đi. Nếu muốn báo cáo theo khu vực hiện tại thay vì khu vực tại thời điểm bán,
cần chủ ý join bằng khóa nghiệp vụ tới phiên bản hiện hành — đó là một định
nghĩa báo cáo khác.

## Báo cáo và tự kiểm tra

`reports/01_monthly_revenue.sql` nhóm doanh thu theo năm-tháng, sản phẩm và
khu vực. Có thể kiểm tra kết quả:

- `C001` tháng 3: 2 Coffee Maker, doanh thu 90.00, khu vực North.
- `C001` tháng 8: 3 Travel Mug, doanh thu 37.50, khu vực Central.
- `C002` tháng 9: 1 Coffee Maker, doanh thu 45.00, khu vực South.

Tự trả lời:

1. Grain của `fact_sales` là gì? Nêu khóa nguồn duy nhất và giải thích vì sao
   đơn có nhiều mặt hàng có nhiều dòng fact.
2. Sau khi đổi địa chỉ `C001` từ North sang Central, khu vực nào được ghi nhận
   cho doanh thu tháng 3 và tháng 8? Giải thích vai trò của `customer_sk` và
   khoảng hiệu lực SCD2.
