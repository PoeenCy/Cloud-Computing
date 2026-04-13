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
('SV001', 'Nguyen Van A', '2002-03-15', 'Computer Science'),
('SV002', 'Tran Thi B', '2001-11-02', 'Information Systems'),
('SV003', 'Le Van C', '2002-07-20', 'Software Engineering');
-- Cấp quyền cho user admin được truy cập vào studentdb
GRANT ALL PRIVILEGES ON studentdb.* TO 'admin'@'%';
FLUSH PRIVILEGES;