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


// Links with data-lightbox open their image larger in a lightbox, with a
// caption. The arrow keys go between the images in the same data-lightbox
// group, and a click anywhere or Escape closes it. A data-tall image, like a
// whole web page, opens at a readable width and scrolls.

const lightbox = document.getElementById('lightbox') as HTMLDialogElement;
const lightboxImage = lightbox.querySelector('img')!;
const lightboxCaption = lightbox.querySelector('figcaption')!;
const lightboxLinks = [...document.querySelectorAll<HTMLAnchorElement>('a[data-lightbox]')];
let group: HTMLAnchorElement[] = [];
let shown = 0;

function showImage(index: number) {
    shown = (index + group.length) % group.length;
    const link = group[shown];
    lightboxImage.src = link.href;
    lightboxImage.alt = link.dataset.alt ?? link.querySelector('img')?.alt ?? '';
    // Its own caption in the lightbox, if it has one, or the one on the page
    lightboxCaption.textContent = link.dataset.caption ?? link.closest('figure')?.querySelector('figcaption')?.textContent ?? '';
    lightbox.classList.toggle('tall', 'tall' in link.dataset);
    lightbox.scrollTop = 0;
}

for (const link of lightboxLinks) {
    link.addEventListener('click', e => {
        e.preventDefault();
        group = lightboxLinks.filter(other => other.dataset.lightbox === link.dataset.lightbox);
        showImage(group.indexOf(link));
        lightbox.showModal();
    });
}

lightbox.addEventListener('keydown', e => {
    if (e.key === 'ArrowRight')
        showImage(shown + 1);
    else if (e.key === 'ArrowLeft')
        showImage(shown - 1);
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
