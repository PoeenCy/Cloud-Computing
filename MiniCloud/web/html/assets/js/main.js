/**
 * MiniCloud System - Main Frontend Logic
 * Responsible for: Fetching student data, handling UI states, and system notifications.
 */

// 1. Cấu hình các hằng số
const API_ENDPOINT = '/api/student'; // Đường dẫn tương đối qua Nginx Proxy
const STUDENT_CONTAINER_ID = 'student-list';

// 2. Cấu hình Keycloak Client
const keycloak = new Keycloak({
    url: 'http://localhost:8088/auth',
    realm: 'realm_52300267',
    clientId: 'flask-app'
});

/**
 * Hàm khởi tạo khi trang web đã sẵn sàng
 */
document.addEventListener('DOMContentLoaded', () => {
    console.log("🚀 MiniCloud Dashboard đã sẵn sàng!");
    setupSmoothScroll();

    keycloak.init({ onLoad: 'login-required', checkLoginIframe: false })
        .then(authenticated => {
            if (authenticated) {
                console.log("✅ Đăng nhập Keycloak thành công!");
                loadStudentData();
            }
        })
        .catch(err => {
            console.error("❌ Lỗi Keycloak:", err);
            // Fallback: load data không cần auth nếu Keycloak chưa cấu hình
            loadStudentData();
        });
});

/**
 * Hàm gọi API và đổ dữ liệu vào giao diện
 */
async function loadStudentData() {
    const container = document.getElementById(STUDENT_CONTAINER_ID);

    // Trạng thái đang tải (Loading State)
    container.innerHTML = `
        <div class="col-span-full py-20 text-center">
            <div class="inline-block animate-spin rounded-full h-12 w-12 border-4 border-orange-500 border-t-transparent"></div>
            <p class="mt-4 text-slate-400 font-medium tracking-wide">Đang đồng bộ dữ liệu từ hệ thống...</p>
        </div>
    `;

    try {
        const headers = { 'Accept': 'application/json' };
        if (keycloak.token) {
            headers['Authorization'] = `Bearer ${keycloak.token}`;
        }
        const response = await fetch(API_ENDPOINT, { headers });

        if (!response.ok) {
            throw new Error(`Lỗi HTTP: ${response.status}`);
        }

        const students = await response.json();

        // Xóa nội dung loading
        container.innerHTML = '';

        if (students.length === 0) {
            container.innerHTML = `<p class="col-span-full text-center text-slate-500 py-10 italic">Danh sách sinh viên hiện đang trống.</p>`;
            return;
        }

        // Render từng sinh viên thành thẻ Card
        students.forEach(student => {
            container.appendChild(createStudentCard(student));
        });

        console.log(`✅ Đã tải thành công ${students.length} sinh viên.`);

    } catch (error) {
        console.error("❌ Lỗi Fetch API:", error);
        renderErrorState(container);
    }
}

/**
 * Hàm tạo HTML cho thẻ sinh viên (UI Component)
 */
function createStudentCard(student) {
    const div = document.createElement('div');
    div.className = "bg-white p-6 rounded-[1.5rem] shadow-sm hover:shadow-xl hover:-translate-y-1 transition duration-300 border border-slate-100 flex flex-col justify-between group";

    // Tui thêm màu sắc ngẫu nhiên cho Avatar cho nó "vui mắt"
    const colors = ['bg-orange-100 text-orange-600', 'bg-cyan-100 text-cyan-600', 'bg-rose-100 text-rose-600', 'bg-indigo-100 text-indigo-600'];
    const randomColor = colors[Math.floor(Math.random() * colors.length)];

    div.innerHTML = `
        <div>
            <div class="w-12 h-12 ${randomColor} rounded-full flex items-center justify-center font-bold mb-4 transition group-hover:scale-110">
                ${student.name.charAt(0)}
            </div>
            <h4 class="text-lg font-extrabold text-slate-900 mb-1 leading-tight group-hover:text-orange-600 transition">${student.name}</h4>
            <p class="text-xs font-mono text-slate-400 mb-4 tracking-tighter">STUDENT_ID: ${student.id}</p>
            
            <!-- Phần sáng tạo thêm: Thông tin bổ sung nếu có -->
            <div class="space-y-2">
                <div class="flex items-center gap-2 text-[11px] text-slate-500">
                    <span class="w-1.5 h-1.5 rounded-full bg-green-500"></span>
                    <span>Chuyên ngành: ${student.major || 'Công nghệ phần mềm'}</span>
                </div>
            </div>
        </div>
        
        <div class="flex items-center justify-between mt-6 pt-4 border-t border-slate-50">
            <div class="flex flex-col">
                <span class="text-[9px] font-bold text-slate-300 uppercase">Hệ thống</span>
                <span class="text-[10px] font-bold text-green-500 uppercase tracking-widest">Active</span>
            </div>
            <a href="${student.github || '#'}" target="_blank" 
               class="bg-slate-900 text-white p-2 rounded-lg hover:bg-orange-500 transition shadow-md shadow-slate-200">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
            </a>
        </div>
    `;
    return div;
}

/**
 * Hiển thị giao diện khi lỗi (Error State)
 */
function renderErrorState(container) {
    container.innerHTML = `
        <div class="col-span-full py-12 px-6 text-center bg-rose-50 rounded-3xl border border-rose-100 shadow-inner">
            <div class="text-rose-500 mb-4">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </div>
            <h3 class="text-lg font-bold text-rose-900 mb-2">Không thể kết nối Backend</h3>
            <p class="text-sm text-rose-600 mb-6">Có vẻ như ông Việt chưa bật MariaDB hoặc Flask rồi. Ông kiểm tra lại Docker nhé!</p>
            <button onclick="loadStudentData()" class="bg-rose-600 text-white px-6 py-2 rounded-xl text-sm font-bold hover:bg-rose-700 transition shadow-lg shadow-rose-200">
                Thử kết nối lại
            </button>
        </div>
    `;
}

/**
 * Hỗ trợ cuộn trang mượt mà
 */
function setupSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth'
                });
            }
        });
    });
}
