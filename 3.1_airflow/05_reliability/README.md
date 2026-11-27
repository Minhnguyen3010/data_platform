# Lab 05 — Retry, timeout, trigger rule và deadline alert

## Mục tiêu

Quan sát retry, giới hạn thời gian task và một task tổng kết dùng trigger rule
`all_done`. DAG cũng khai báo deadline alert để thực hành thay cho SLA.

## Chạy

Copy `dags/reliability_controls.py` vào thư mục DAG của Airflow và trigger
`reliability_controls`. Task `retry_once` chủ động lỗi ở lần thử đầu rồi thành
công ở lần retry.

## Kiểm tra

Xem số lần thử và task log trong UI. Task `summarize` phải chạy dù
`retry_once` cuối cùng thành công hay thất bại. Deadline alert chỉ được kích
hoạt khi Dag Run vượt ngưỡng đã khai báo; đây là tính năng thử nghiệm mới trong
Airflow 3.1 và callback mẫu chỉ ghi cảnh báo vào log.
