#!/usr/bin/env node
/*
 * EduPulse — Sinh service-worker.js cho offline-first PWA trên iOS / Android / Desktop.
 *
 * Chạy SAU `flutter build web --release` để:
 *   - Precache toàn bộ app shell và static assets (offline 100% ngay từ lần đầu mở trên iOS PWA),
 *   - Tự bump version cache theo hash nội dung build,
 *   - Xử lý triệt để lỗi "response served by service worker has redirections" theo chuẩn W3C.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const BUILD_DIR = path.join(__dirname, '..', 'build', 'web');
const OUT_FILE = path.join(BUILD_DIR, 'service-worker.js');

// Những file KHÔNG precache
const EXCLUDE_PATTERNS = [
  /^service-worker\.js$/,        // chính file SW
  /^flutter_service_worker\.js$/, // SW cũ của Flutter (nếu có)
  /^version\.json$/,             // metadata phiên bản
  /^\.last_build_id$/,           // metadata build
  /^index\.html$/,               // index.html được đại diện qua './' để tránh redirect
];

function isExcluded(rel) {
  return EXCLUDE_PATTERNS.some((re) => re.test(rel));
}

function listFiles(dir, base) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const full = path.join(dir, e.name);
    const rel = path.join(base, e.name).replace(/\\/g, '/');
    if (e.isDirectory()) {
      out.push(...listFiles(full, rel));
    } else if (!isExcluded(rel)) {
      out.push(rel);
    }
  }
  return out;
}

function main() {
  if (!fs.existsSync(path.join(BUILD_DIR, 'main.dart.js'))) {
    console.error(
      'generate_sw: build/web/main.dart.js không tồn tại. Chạy `flutter build web --release` trước.'
    );
    process.exit(1);
  }

  const files = listFiles(BUILD_DIR, '').sort();
  // Precache gốc './' (đại diện index.html không redirect) + toàn bộ file tĩnh
  const uniqueFiles = Array.from(new Set(['./', ...files.map((f) => './' + f)]));

  // Version = hash của toàn bộ file build
  const hasher = crypto.createHash('sha256');
  for (const rel of files) {
    try {
      hasher.update(fs.readFileSync(path.join(BUILD_DIR, rel)));
    } catch (_) {
      // bỏ qua file không đọc được
    }
  }
  const version = hasher.digest('hex').slice(0, 12);
  const CACHE = `edupulse-pwa-v4-${version}`;
  const FONT_CACHE = 'edupulse-fonts-v1';

  const precacheJson = JSON.stringify(uniqueFiles);

  const sw = `// EduPulse — Offline-First iOS/Android PWA Service Worker (GENERATED)
// Do not edit by hand — regenerated on every build.

const CACHE = ${JSON.stringify(CACHE)};
const FONT_CACHE = ${JSON.stringify(FONT_CACHE)};
const PRECACHE = ${precacheJson};

// Chuẩn hóa response: Loại bỏ cờ 'redirected' theo chuẩn W3C Service Worker
// Tránh hoàn toàn lỗi trình duyệt "response served by service worker has redirections"
async function cleanResponse(response) {
  if (!response) return response;
  if (response.redirected || (response.status >= 300 && response.status < 400)) {
    const body = await response.blob();
    return new Response(body, {
      status: 200,
      statusText: 'OK',
      headers: response.headers,
    });
  }
  return response;
}

// Timeout helper cho fetch
function fetchWithTimeout(request, timeoutMs) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Network timeout')), timeoutMs);
    fetch(request)
      .then((res) => {
        clearTimeout(timer);
        resolve(res);
      })
      .catch((err) => {
        clearTimeout(timer);
        reject(err);
      });
  });
}

// Install: Precache an toàn toàn bộ asset
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE).then(async (cache) => {
      // 1. Precache shell cốt lõi './'
      try {
        const rootRes = await fetch('./', { cache: 'reload' });
        if (rootRes && rootRes.ok) {
          const cleanRoot = await cleanResponse(rootRes);
          await cache.put('./', cleanRoot);
        }
      } catch (err) {
        console.warn('EduPulse SW: Core shell precache failed', err);
      }

      // 2. Precache từng file tĩnh còn lại
      await Promise.allSettled(
        PRECACHE.map(async (url) => {
          if (url === './') return;
          try {
            const res = await fetch(url, { cache: 'reload' });
            if (res && (res.ok || res.type === 'opaque')) {
              const clean = await cleanResponse(res);
              await cache.put(url, clean);
            }
          } catch (e) {
            // bỏ qua lỗi file lẻ
          }
        })
      );
    })
  );
});

// Activate: dọn cache cũ và claim clients ngay
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE && key !== FONT_CACHE)
          .map((key) => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

// Fetch routing
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // 1. Google Fonts runtime caching
  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    event.respondWith(
      caches.open(FONT_CACHE).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cleanResponse(cached);
        try {
          const res = await fetch(request);
          if (res && res.ok) {
            const clean = await cleanResponse(res);
            cache.put(request, clean.clone());
            return clean;
          }
          return res;
        } catch (_) {
          return cached ? cleanResponse(cached) : new Response('', { status: 408 });
        }
      })
    );
    return;
  }

  // Bỏ qua external API (Supabase, OpenRouter, Tavily...)
  if (url.origin !== self.location.origin) return;

  // 2. Navigation Request (mở trang / refresh / đổi route SPA):
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        // Nếu offline, trả ngay cached app shell
        if (!self.navigator.onLine) {
          const cached = await caches.match('./');
          if (cached) return cleanResponse(cached);
        }

        try {
          // Thử mạng trước (timeout 2s)
          const res = await fetchWithTimeout(request, 2000);
          if (res && (res.ok || res.type === 'opaque')) {
            const clean = await cleanResponse(res);
            const copy = clean.clone();
            caches.open(CACHE).then((c) => c.put('./', copy));
            return clean;
          }
        } catch (_) {
          // Network timeout hoặc mất mạng -> fallback cache
        }

        const fallback = await caches.match('./');
        if (fallback) return cleanResponse(fallback);

        // Fallback tối hậu: fetch trực tiếp root
        try {
          const netRoot = await fetch('./');
          return cleanResponse(netRoot);
        } catch (e) {
          return new Response('EduPulse đang ngoại tuyến.', {
            status: 200,
            headers: { 'Content-Type': 'text/plain; charset=utf-8' },
          });
        }
      })()
    );
    return;
  }

  // 3. Static Assets: Cache-First + Clean Response
  event.respondWith(
    caches.match(request).then(async (cached) => {
      if (cached) {
        // Cập nhật ngầm trong background nếu có mạng
        if (self.navigator.onLine) {
          fetch(request)
            .then(async (netRes) => {
              if (netRes && netRes.ok) {
                const clean = await cleanResponse(netRes);
                caches.open(CACHE).then((c) => c.put(request, clean));
              }
            })
            .catch(() => {});
        }
        return cleanResponse(cached);
      }

      // Chưa có trong cache -> lấy từ network
      return fetch(request).then(async (res) => {
        const clean = await cleanResponse(res);
        if (clean && clean.ok) {
          const copy = clean.clone();
          caches.open(CACHE).then((c) => c.put(request, copy));
        }
        return clean;
      });
    })
  );
});
`;

  fs.writeFileSync(OUT_FILE, sw, 'utf8');
  console.log(
    `generate_sw: OK — ${uniqueFiles.length} assets precache, cache="${CACHE}"`
  );
}

main();
