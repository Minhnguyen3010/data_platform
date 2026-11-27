# Lab 02 — Schedule và data interval

## Mục tiêu

Chạy DAG theo timetable cron dành cho data interval và quan sát ranh giới
`[data_interval_start, data_interval_end)`. DAG khai báo timetable cụ thể,
không ngầm hiểu thời điểm trigger là khoảng dữ liệu cần xử lý.

## Chạy

Copy `dags/data_interval_daily.py` vào thư mục DAG của Airflow. DAG chạy hàng
ngày lúc 02:00 UTC; `catchup=False` để không tự tạo run cho lịch sử.

## Kiểm tra

Mở task log và so sánh logical date với hai mốc interval. Thay đổi cron hoặc
timezone trong DAG, đợi parse lại rồi quan sát lịch chạy mới.
