'use strict';
const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
if (!reduced && 'IntersectionObserver' in window) {
  document.documentElement.classList.add('js');
  const observer = new IntersectionObserver(entries => entries.forEach(entry => {
    if (entry.isIntersecting) { entry.target.classList.add('visible'); observer.unobserve(entry.target); }
  }), {threshold: 0.06});
  document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
}
const range = document.querySelector('#band-range');
range.addEventListener('input', () => document.querySelector('.reading-demo').style.setProperty('--band-y', `${range.value}%`));
const button = document.querySelector('#sample-play');
const audio = document.querySelector('#sample-audio');
const zh = document.body.dataset.lang === 'zh';
function resetAudio(){button.innerHTML = `<span aria-hidden="true">▷</span> ${button.dataset.playLabel}`; button.setAttribute('aria-pressed','false'); document.querySelector('.speech-card').classList.remove('playing');}
button.setAttribute('aria-pressed','false');
button.addEventListener('click', async () => {
  if (!audio.paused) {audio.pause(); resetAudio(); return;}
  try {
    document.querySelector('.audio-status').textContent='';
    await audio.play(); button.textContent=zh?'Ⅱ 暂停示例':'Ⅱ Pause sample';button.setAttribute('aria-pressed','true');document.querySelector('.speech-card').classList.add('playing');
  } catch {document.querySelector('.audio-status').textContent=zh?'暂时无法播放，请稍后重试。':'Playback unavailable. Please try again.';resetAudio();}
});
audio.addEventListener('ended',resetAudio);
document.querySelector('video').addEventListener('play',()=>{audio.pause();resetAudio();});
const copy=document.querySelector('#copy');
copy.addEventListener('click',async()=>{
  try {await navigator.clipboard.writeText(document.querySelector('#commands').textContent);copy.textContent=copy.dataset.copied;document.querySelector('#copy-status').textContent=zh?'构建命令已复制。':'Build commands copied.';setTimeout(()=>copy.textContent=copy.dataset.label,2000);}
  catch {document.querySelector('#copy-status').textContent=zh?'请选中上方命令手动复制。':'Select the commands above to copy them manually.';}
});
