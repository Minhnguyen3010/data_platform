# Lab 03 — Backfill

## Mục tiêu

Tạo các DAG run cho một khoảng lịch sử và quan sát scheduler chạy từng
interval. DAG không tự catch up; backfill được yêu cầu tường minh.

## Chạy

Copy `dags/backfill_daily.py` vào thư mục DAG của Airflow, đợi DAG parse thành
công, rồi tạo backfill trong UI qua **DAGs → backfill_daily → Backfill**. Chọn
khoảng bắt đầu/kết thúc theo UTC. Có thể tạo cùng backfill qua CLI hoặc REST
API; kiểm tra cú pháp CLI bằng `airflow backfill create --help` và API docs
đúng phiên bản đang chạy. Airflow 3 thực thi backfill qua scheduler, không
phải chạy task trực tiếp từ lệnh CLI.

## Kiểm tra

Mở danh sách Dag Runs và task logs. Mỗi run phải ghi nhận interval riêng của
nó; không dùng thời điểm thực thi làm mốc dữ liệu.
