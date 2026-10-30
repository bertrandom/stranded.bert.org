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


// The photos open larger in a lightbox, with their captions. The arrow keys
// go between them, and a click anywhere or Escape closes it.

const lightbox = document.getElementById('lightbox') as HTMLDialogElement;
const lightboxImage = lightbox.querySelector('img')!;
const lightboxCaption = lightbox.querySelector('figcaption')!;
const photos = [...document.querySelectorAll<HTMLElement>('.photos figure')];
let shown = 0;

function showPhoto(index: number) {
    shown = (index + photos.length) % photos.length;
    const photo = photos[shown];
    const link = photo.querySelector('a')!;
    lightboxImage.src = link.href;
    lightboxImage.alt = photo.querySelector('img')!.alt;
    // Its own caption in the lightbox, if it has one, or the one on the page
    lightboxCaption.textContent = link.dataset.caption ?? photo.querySelector('figcaption')?.textContent ?? '';
}

photos.forEach((photo, index) => {
    photo.querySelector('a')!.addEventListener('click', e => {
        e.preventDefault();
        showPhoto(index);
        lightbox.showModal();
    });
});

lightbox.addEventListener('keydown', e => {
    if (e.key === 'ArrowRight')
        showPhoto(shown + 1);
    else if (e.key === 'ArrowLeft')
        showPhoto(shown - 1);
});

lightbox.addEventListener('click', () => lightbox.close());


// In-page links scroll to their section without adding #section to the URL

for (const link of document.querySelectorAll<HTMLAnchorElement>('a[href^="#"]')) {
    link.addEventListener('click', e => {
        const target = document.getElementById(link.hash.slice(1));
        if (!target)
            return;
        e.preventDefault();
        target.scrollIntoView();
    });
}


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
