'use strict';

const CACHE_NAME = 'edupulse-shell-v3';

// Core app shell precached on install.
const SHELL_ASSETS = [
  './',
  './index.html',
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './manifest.json',
  './favicon.png',
  './favicon-16x16.png',
  './favicon-32x32.png',
  './icons/apple-touch-icon.png',
  './icons/Icon-96.png',
  './icons/Icon-144.png',
  './icons/Icon-180.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(SHELL_ASSETS))
      .catch((err) => console.warn('EduPulse SW precache failed:', err))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  // Only handle same-origin requests. API keys / external AI endpoints are
  // never cached so the app correctly errors when offline for those.
  if (url.origin !== location.origin) return;

  // Navigation (HTML pages): network-first, fall back to cached index.html.
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put('./index.html', copy));
          return response;
        })
        .catch(() => caches.match('./index.html'))
    );
    return;
  }

  // Hashed immutable runtime assets (JS/WASM/fonts/images): stale-while-revalidate.
  const isStatic =
    url.pathname.startsWith('/assets/') ||
    url.pathname.startsWith('/canvaskit') ||
    /\.(js|mjs|wasm|woff2?|ttf|otf|png|ico|svg)$/i.test(url.pathname);
  if (isStatic) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const network = fetch(request)
          .then((response) => {
            if (response && response.ok) {
              const copy = response.clone();
              caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
            }
            return response;
          })
          .catch(() => cached);
        return cached || network;
      })
    );
    return;
  }

  // Default: network-first with cache fallback.
  event.respondWith(
    fetch(request).catch(() => caches.match(request))
  );
});
