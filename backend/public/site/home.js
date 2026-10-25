const navToggle = document.querySelector('#nav-toggle');
const primaryNav = document.querySelector('#primary-nav');

function closeNavigation() {
  primaryNav.classList.remove('open');
  navToggle.setAttribute('aria-expanded', 'false');
  navToggle.setAttribute('aria-label', '開啟導覽選單');
}

navToggle.addEventListener('click', () => {
  const opened = primaryNav.classList.toggle('open');
  navToggle.setAttribute('aria-expanded', String(opened));
  navToggle.setAttribute('aria-label', opened ? '關閉導覽選單' : '開啟導覽選單');
});

document.querySelectorAll('a[href^="#"]').forEach((link) => link.addEventListener('click', (event) => {
  const target = document.querySelector(link.getAttribute('href'));
  if (!target) return;
  event.preventDefault();
  const top = target.getBoundingClientRect().top + window.scrollY - 84;
  window.scrollTo({ top: Math.max(0, top), behavior: 'smooth' });
  history.replaceState(null, '', link.getAttribute('href'));
  closeNavigation();
}));

document.addEventListener('click', (event) => {
  if (!event.target.closest('.topbar')) closeNavigation();
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeNavigation();
});
window.addEventListener('resize', () => {
  if (window.innerWidth > 900) closeNavigation();
});
