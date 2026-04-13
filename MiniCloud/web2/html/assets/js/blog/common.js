document.addEventListener('scroll', () => {
  const bar = document.getElementById('progress-bar');
  if (!bar) return;
  const top = document.documentElement.scrollTop || document.body.scrollTop;
  const height = document.documentElement.scrollHeight - document.documentElement.clientHeight;
  const percent = height > 0 ? (top / height) * 100 : 0;
  bar.style.width = percent + '%';
});
