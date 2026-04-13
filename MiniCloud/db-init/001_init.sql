CREATE DATABASE IF NOT EXISTS minicloud;
USE minicloud;
CREATE TABLE IF NOT EXISTS notes(
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO notes (title) VALUES ('Hello from MariaDB!');

CREATE DATABASE IF NOT EXISTS studentdb;
USE studentdb;
CREATE TABLE IF NOT EXISTS students (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(10),
    fullname VARCHAR(100),
    dob DATE,
    major VARCHAR(50)
);
INSERT INTO students (student_id, fullname, dob, major) VALUES 
('52300232', 'Trần Thanh Nhã', '2002-05-10', 'Frontend & UI/UX Design'),
('52300299', 'Từ Thanh Ngôn', '2002-08-15', 'Cloud Infrastructure'),
('52300267', 'Huỳnh Nguyễn Quốc Việt', '2002-03-22', 'Backend & DevOps');
-- Cấp quyền cho user admin được truy cập vào studentdb
GRANT ALL PRIVILEGES ON studentdb.* TO 'admin'@'%';
FLUSH PRIVILEGES;