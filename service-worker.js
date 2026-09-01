'use strict';

const CACHE_NAME = 'edupulse-shell-v6';
const OFFLINE_CACHE_NAME = 'edupulse-offline-v1';

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

// Offline fallback page content
const OFFLINE_HTML = `
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="theme-color" content="#58CC02">
  <title>EduPulse - Mất kết nối</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #F7F7F7;
      color: #1A1A1A;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      text-align: center;
    }
    .container { max-width: 360px; }
    .icon {
      width: 80px; height: 80px;
      margin: 0 auto 24px;
      background: linear-gradient(135deg, #58CC02, #4AAE02);
      border-radius: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .icon svg { width: 40px; height: 40px; color: white; }
    h1 { font-size: 24px; font-weight: 700; margin-bottom: 12px; }
    p { font-size: 16px; line-height: 1.5; color: #666; margin-bottom: 24px; }
    .status {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 12px 20px;
      background: #FFF3E0;
      border-radius: 12px;
      color: #E65100;
      font-size: 14px;
      font-weight: 500;
      margin-bottom: 24px;
    }
    .status::before {
      content: '';
      width: 8px; height: 8px;
      background: #FF9800;
      border-radius: 50%;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.4; }
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 14px 28px;
      background: #58CC02;
      color: white;
      border: none;
      border-radius: 12px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s, transform 0.1s;
    }
    .btn:active { transform: scale(0.98); }
    .btn:hover { background: #4AAE02; }
    .tip {
      margin-top: 20px;
      font-size: 13px;
      color: #999;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M1 1l22 22M16.72 11.06A10.94 10.94 0 0 1 19 12.55M5 12.55a10.94 10.94 0 0 1 5.17-2.39M10.71 5.05A16 16 0 0 1 22.58 9M1.42 9a15.91 15.91 0 0 1 4.7-2.88M8.53 16.11a6 6 0 0 1 6.95 0M12 20h.01"/>
      </svg>
    </div>
    <h1>Mất kết nối mạng</h1>
    <p>Bạn đang ở chế độ ngoại tuyến. Một số tính năng có thể không hoạt động cho đến khi kết nối được khôi phục.</p>
    <div class="status" id="status">Đang thử kết nối lại...</div>
    <button class="btn" onclick="window.location.reload()">Thử lại</button>
    <p class="tip">Kiểm tra Wi-Fi hoặc dữ liệu di động, sau đó nhấn Thử lại.</p>
  </div>
  <script>
    (function() {
      const statusEl = document.getElementById('status');
      function checkOnline() {
        if (navigator.onLine) {
          statusEl.textContent = 'Đã kết nối lại! Đang tải...';
          statusEl.style.background = '#E8F5E9';
          statusEl.style.color = '#2E7D32';
          statusEl.innerHTML = '<span style="width:8px;height:8px;background:#4CAF50;border-radius:50%"></span> Đã kết nối lại! Đang tải...';
          setTimeout(() => window.location.reload(), 1000);
        } else {
          statusEl.textContent = 'Đang thử kết nối lại...';
          statusEl.style.background = '#FFF3E0';
          statusEl.style.color = '#E65100';
          statusEl.innerHTML = '<span style="width:8px;height:8px;background:#FF9800;border-radius:50%;animation:pulse 1.5s infinite"></span> Đang thử kết nối lại...';
        }
      }
      window.addEventListener('online', checkOnline);
      window.addEventListener('offline', checkOnline);
      // Periodic check
      setInterval(checkOnline, 5000);
    })();
  </script>
</body>
</html>
`;

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
        keys.filter((key) => key !== CACHE_NAME && key !== OFFLINE_CACHE_NAME).map((key) => caches.delete(key))
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

  // Navigation (HTML pages): network-first, fall back to cached index.html,
  // then to offline page if both fail.
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put('./index.html', copy));
          return response;
        })
        .catch(() => caches.match('./index.html'))
        .catch(() => {
          // Return offline fallback page
          return new Response(OFFLINE_HTML, {
            headers: { 'Content-Type': 'text/html; charset=utf-8' }
          });
        })
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

// Listen for messages from the client (Flutter) to skip waiting
self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
  }
});
