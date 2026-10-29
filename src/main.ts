// The landing page: Johnny in the hero, from stranded-web

import { createPlayer } from 'stranded-web';

const hero = document.getElementById('johnny')!;
const loading = document.getElementById('loading')!;


// Once Johnny's been watched for a while without moving, the overlays fade
// out of his way, and come back on the next move

let idleTimer = 0;

function wakeUp() {
    hero.classList.remove('idle');
    clearTimeout(idleTimer);
    idleTimer = window.setTimeout(() => hero.classList.add('idle'), 9000);
}

for (const type of ['pointermove', 'pointerdown', 'keydown', 'focusin'])
    hero.addEventListener(type, wakeUp);

// Not while scrolled away from it, so that it's all there on the way back
window.addEventListener('scroll', () => {
    if (window.scrollY > 0)
        wakeUp();
}, { passive: true });


createPlayer(document.getElementById('player')!, {
    data: 'data/',
    shape: 'fill',
    intro: false,       // straight to the island
    autoHide: false,    // with the rest of the hero, above
})
    .then(() => {
        loading.classList.add('done');
        wakeUp();
    })
    .catch(e => {
        console.error(e);
        loading.textContent = "Johnny couldn't make it ashore. The game's data files didn't load.";
    });
