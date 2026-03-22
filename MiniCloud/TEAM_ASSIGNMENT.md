# 🚀 MiniCloud System - Task Assignment & Guidelines

Chào anh em,

Tình hình là tui đã "chốt hạ" xong toàn bộ hạ tầng lõi của con MiniCloud nhà mình rồi. Hệ thống từ Docker Compose, Nginx Proxy, DNS nội bộ cho đến bảo mật Docker Secrets giờ đã vững như bàn thạch! Anh em không cần phải đau đầu lo về server, port hay cấu hình mạng lằng nhằng nữa, cứ yên tâm mà tập trung 100% công lực vào chuyên môn của mình nhé.

Dưới đây là phần việc tui chia cho hai anh em, code mẫu (boilerplate) tui đã dựng sẵn hết vào các thư mục rồi, anh em cứ thế mà "múa".

---

## 👨‍💻 1. Việt (Backend Developer & Database)

**📍 Nơi làm việc của ông:** Thư mục `app/src/` và `db-init/`.

**🎯 Việc cần làm ngay (Core):**
- Schema mẫu đã có trong `db-init/001_init.sql` (chạy tự động **lần đầu** khi volume `db_data` còn trống); chỉnh sửa / mở rộng bảng tại đây nếu cần. Nếu DB đã tồn tại từ trước, muốn đổi schema thì phải migration tay, `docker exec` vào MariaDB, hoặc hiểu rõ là `docker compose down -v` sẽ xóa sạch data.
- Chui vào `app/src/routes.py`, tìm mấy dòng `# TODO`, rồi nhét logic gọi SQL lấy danh sách sinh viên trả về chuẩn JSON cho Frontend nó xài (route `/api/student`).
- Tuỳ chọn: gia cố `app/src/database.py` (try/except, pool…) nếu ông kỹ tính.

**🎨 Không gian sáng tạo (Tự do vẫy vùng):**
- Danh sách sinh viên cơ bản chán lắm, ông cứ thoải mái sáng tạo thêm mấy trường hay ho như GPA, Sở thích, hay nhét luôn cái Link Github cá nhân vào.
- Nếu đang sung, ông có thể quất luôn thêm mấy bài API Thêm/Sửa/Xóa (CRUD) sinh viên. Anh em nào thích try-hard thì tích hợp luôn cái logic giải mã Token JWT từ con Keycloak để phân quyền admin/user rạch ròi cho nó "ngầu"!

**⚠️ Cảnh báo nhẹ (Critical):**
- Kết nối DB và đọc Docker Secret đã mớm sẵn trong `app/src/database.py`. Ông **tuyệt đối không hard-code mật khẩu** vào source code nhé! Hostname để móc vào DB luôn luôn là `db.cloud.local`. Giữ đúng luật chơi này để app chạy mượt mà trên môi trường thật.

---

## 👨‍🎨 2. Ngôn (Frontend & UI/UX Specialist - Observability)

**📍 Nơi làm việc của ông:** Thư mục `web/html/` (giao diện) và màn hình Web của mấy con Grafana / MinIO.

**🎯 Việc cần làm ngay (Core):**
- Chui vào `web/html/assets/js/main.js`, tìm `# TODO` rồi viết logic hứng cục data JSON từ API `/api/student` mà ông Việt ném ra, xong render thật mượt lên trang `index.html` (thay đổi `index.html` + `assets/css/style.css` tuỳ ý).
- Build cho tui 3 bài Blog tĩnh cá nhân đặt trong `web/html/blog/` nhé.

**🎨 Không gian sáng tạo (Tự do vẫy vùng):**
- Thả cửa cho ông "bung xõa" hết nấc với CSS, Tailwind hay Bootstrap trong cái `style.css`. Cứ làm mấy cái Blog thật xịn xò (chủ đề du lịch, công nghệ, review đồ ăn hay gì tùy thích). Tràn viền hay gắn thêm dăm ba quả animation cho nó cháy máy!
- Trên con Grafana, ông cứ tự do "kéo thả" mấy cái Dashboard, vẽ biểu đồ rực rỡ nhìn thật "Hacker-style" hoặc "Minimalist", sao cho lúc show demo trông thật ác chiến. 
- Còn với con kho MinIO, cứ tự do upload ảnh ọt, ném file PDF báo cáo lên đó làm resource tĩnh để nhúng sang trang Blog cho đẹp. Console MinIO mở tại `http://localhost:9001/` (user/pass đọc từ thư mục `secrets/`).

**⚠️ Cảnh báo nhẹ (Critical):**
- Lúc gọi API Backend từ cái file JS, ông **chỉ cần dùng đường dẫn tương đối** là `fetch('/api/student')` thôi nhé. Đừng có trỏ thẳng IP hay port làm gì nhọc thân, con Nginx Proxy của tui nó sẽ tự động nhận diện và vạch đường vòng bên dưới để chui vào Backend.

---

## ⚡ Chạy & link nhanh

```bash
cd MiniCloud
docker compose up -d --build
```

- Web qua gateway: `http://localhost/`
- MinIO Console: `http://localhost:9001/`
- Grafana: `http://localhost:3000/`

---

🔥 **Chốt lại:** Anh em đọc kỹ nhiệm vụ, quẩy mạnh cái chuyên môn của mình nhé. Xong xuôi thì hú tui một tiếng để chốt lịch anh em mình ráp code test thử nghiệm. Triển thôi anh em!
