-- MiniCloud: khởi tạo DB nghiệp vụ (chạy tự động lần đầu khi volume db trống)
CREATE DATABASE IF NOT EXISTS studentdb;
USE studentdb;

CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fullname VARCHAR(255) NOT NULL,
    student_code VARCHAR(32) NOT NULL UNIQUE
);

INSERT INTO students (fullname, student_code) VALUES
    ('Nguyễn Văn A', 'SV001'),
    ('Trần Thị B', 'SV002'),
    ('Lê Văn C', 'SV003');

-- Cấp quyền cho user ứng dụng (tạo bởi MARIADB_USER trong docker-compose)
GRANT ALL PRIVILEGES ON studentdb.* TO 'admin'@'%';
FLUSH PRIVILEGES;
