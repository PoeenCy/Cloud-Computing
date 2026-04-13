document.addEventListener('DOMContentLoaded', async () => {
  const container = document.getElementById('student-list');
  if (!container) return;
  try {
    const res = await fetch('/api/student');
    // Nếu 401/403 (cần token), hiện thông báo thay vì crash
    if (res.status === 401 || res.status === 403) {
      container.innerHTML = '<div class="bg-slate-800 p-6 rounded-2xl text-slate-400 italic">Cần đăng nhập để xem danh sách sinh viên.</div>';
      return;
    }
    const data = await res.json();
    const list = Array.isArray(data) ? data : [];
    if (list.length === 0) {
      container.innerHTML = '<div class="bg-slate-800 p-6 rounded-2xl text-slate-400 italic">Danh sách sinh viên đang trống.</div>';
      return;
    }
    container.innerHTML = list.map((s) => `
      <div class="bg-white p-6 rounded-2xl shadow-lg border-b-4 border-orange-500">
        <p class="text-xs font-bold text-orange-500 uppercase mb-1">Sinh Viên</p>
        <h4 class="text-xl font-bold">${s.name ?? s.fullname ?? 'N/A'}</h4>
        <p class="text-sm text-slate-500 mb-2">Mã số: ${s.id ?? s.student_id ?? 'N/A'}</p>
        <p class="text-sm text-slate-500 mb-4">Ngành: ${s.major ?? 'N/A'}</p>
      </div>
    `).join('');
  } catch (e) {
    container.innerHTML = '<div class="bg-slate-800 p-6 rounded-2xl text-slate-400 italic">Chưa kết nối được Backend.</div>';
  }
});
