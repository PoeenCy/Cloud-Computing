document.addEventListener('DOMContentLoaded', async () => {
  const container = document.getElementById('student-list');
  if (!container) return;
  try {
    const res = await fetch('/api/student');
    const data = await res.json();
    const list = Array.isArray(data) ? data : [];
    if (list.length === 0) {
      container.innerHTML = '<div class="bg-slate-800 p-6 rounded-2xl text-slate-400 italic">Backend chua tra danh sach sinh vien.</div>';
      return;
    }
    container.innerHTML = list.map((s) => `
      <div class="bg-white p-6 rounded-2xl shadow-lg border-b-4 border-orange-500">
        <p class="text-xs font-bold text-orange-500 uppercase mb-1">Sinh Vien</p>
        <h4 class="text-xl font-bold">${s.fullname ?? s.name ?? 'N/A'}</h4>
        <p class="text-sm text-slate-500 mb-4">Ma so: ${s.student_code ?? s.id ?? 'N/A'}</p>
        <a href="${s.github || '#'}" target="_blank" class="text-xs font-bold bg-slate-100 px-3 py-1 rounded-full hover:bg-slate-200 transition">View Github</a>
      </div>
    `).join('');
  } catch (e) {
    container.innerHTML = '<div class="bg-slate-800 p-6 rounded-2xl text-slate-400 italic">Chua ket noi duoc Backend, hay doi Backend hoan thien API.</div>';
  }
});
