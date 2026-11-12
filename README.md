# GitHub Commits Ingestion

Project thực hành Data Engineering: REST API JSON -> transform -> PostgreSQL.

## Công nghệ

- Python 3.10+ (khuyến nghị 3.12)
- GitHub REST API công khai
- PostgreSQL + psycopg 3
- requests, python-dotenv, pytest

## 1. Chuẩn bị PostgreSQL

Project đang cấu hình `.env` với:
- Host: `localhost`
- Port: `5432`
- Database: `data_platform`
- User: `data_platform`

Đảm bảo PostgreSQL đã có database và user tương ứng, user có quyền tạo bảng trong database.
Nếu database chưa tồn tại, đăng nhập bằng tài khoản quản trị PostgreSQL và chạy:

```sql
CREATE USER data_platform WITH PASSWORD 'abcd123';
CREATE DATABASE data_platform OWNER data_platform;
```

Nếu user/database đã tồn tại thì không cần chạy lại. Nếu PostgreSQL của bạn không ở localhost,
hãy sửa `DB_HOST` trong `.env` cho đúng địa chỉ máy chủ.

## 2. Cài đặt môi trường Python

Windows PowerShell:
```powershell
py -3.12 -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Ubuntu / WSL:
```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 3. Cấu hình

File `.env` đã được tạo sẵn theo thông tin database bạn cung cấp.
File `.env` được khai báo trong `.gitignore`, không push file này lên GitHub.
Nếu host/port PostgreSQL khác, sửa lại trong `.env`.

## 4. Chạy pipeline

```bash
python main.py
```

API:
`https://api.github.com/repos/psf/requests/commits`

Pipeline sẽ:
1. Gọi API lấy JSON.
2. Retry khi HTTP 429 hoặc timeout/connection error.
3. Chuẩn hóa timestamp thành UTC.
4. Bỏ qua record thiếu SHA, message hoặc ngày tháng không hợp lệ.
5. Tạo bảng `github_commits` nếu chưa có.
6. UPSERT theo `sha` (PRIMARY KEY).

## 5. Kiểm tra dữ liệu và idempotency

Chạy `python main.py` hai lần liên tiếp, sau đó chạy SQL:

```sql
SELECT COUNT(*) FROM github_commits;

SELECT sha, COUNT(*)
FROM github_commits
GROUP BY sha
HAVING COUNT(*) > 1;
```

Truy vấn thứ hai phải trả về 0 dòng. Số lượng dòng không tăng khi chạy lại cùng tập commit.
`ON CONFLICT (sha) DO UPDATE` cập nhật bản ghi đã tồn tại thay vì tạo dòng mới.

## 6. Unit test

```bash
pytest -v
```

Test mô phỏng API thành công, 429, timeout, retry hết lượt và dữ liệu lỗi.
Test không gọi Internet và không cần PostgreSQL thật.

## 7. Cấu trúc thư mục

```text
github_commits_de_project/
├── de_project/
│   ├── __init__.py
│   ├── api.py
│   ├── config.py
│   ├── db.py
│   ├── exceptions.py
│   ├── pipeline.py
│   └── transform.py
├── tests/
│   ├── test_api.py
│   └── test_transform.py
├── .env
├── .env.example
├── .gitignore
├── main.py
├── requirements.txt
└── README.md
```

## 8. Lưu ý bảo mật

`.env` trong project này được tạo sẵn theo thông tin bạn cung cấp để tiện chạy local.
Không commit hoặc gửi file `.env` lên GitHub. Mật khẩu đã xuất hiện trong cuộc trò chuyện,
nên nếu đây là mật khẩu đang dùng cho hệ thống thật, bạn nên đổi sang mật khẩu riêng.
