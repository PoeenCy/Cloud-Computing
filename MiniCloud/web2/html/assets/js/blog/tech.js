document.addEventListener('DOMContentLoaded', () => {
  const btn = document.getElementById('back-to-top-btn');
  if (!btn) return;
  btn.addEventListener('click', () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });
});
