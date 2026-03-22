/**
 * Gọi API qua đường dẫn tương đối để request đi qua Nginx Proxy (cùng origin).
 * TODO (Ngôn): Xử lý UI khi API trả 501/TODO hoặc mảng sinh viên thật.
 */
document.addEventListener('DOMContentLoaded', () => {
    const el = document.getElementById('student-list');
    if (!el) return;

    fetch('/api/student')
        .then((res) => {
            if (!res.ok) {
                return res.json().then((body) => (JSON.stringify(body, null, 2)));
            }
            return res.json().then((data) => JSON.stringify(data, null, 2));
        })
        .then((text) => {
            el.innerHTML = `<pre>${text}</pre>`;
        })
        .catch((err) => {
            console.error(err);
            el.innerHTML = '<span class="error">Không gọi được API. Kiểm tra Proxy và service app.</span>';
        });
});
