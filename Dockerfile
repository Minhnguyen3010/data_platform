
# Sử dụng Python 3.12
FROM python:3.12-slim

# Thư mục làm việc bên trong container
WORKDIR /app

# Copy danh sách thư viện
COPY requirements.txt .

# Cài đặt thư viện
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code vào container
COPY . .

# Chạy chương trình
CMD ["python", "main.py"]
