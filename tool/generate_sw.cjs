#!/usr/bin/env node
/*
 * EduPulse — Sinh service-worker.js cho offline-first PWA trên iOS / Android / Desktop.
 *
 * Chạy SAU `flutter build web --release` để:
 *   - Precache toàn bộ app shell và static assets (offline 100% ngay từ lần đầu mở trên iOS PWA),
 *   - Tự bump version cache theo hash nội dung build,
 *   - Chiến lược cache thích ứng: Offline-immediate navigation cho iOS Safari PWA.
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
  // Bao gồm root và index.html rõ ràng
  const baseAssets = ['./', './index.html'];
  const uniqueFiles = Array.from(new Set([...baseAssets, ...files.map((f) => './' + f)]));

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
  const CACHE = `edupulse-pwa-v3-${version}`;
  const FONT_CACHE = 'edupulse-fonts-v1';

  const precacheJson = JSON.stringify(uniqueFiles);

  const sw = `// EduPulse — Offline-First iOS/Android PWA Service Worker (GENERATED)
// Do not edit by hand — regenerated on every build.

const CACHE = ${JSON.stringify(CACHE)};
const FONT_CACHE = ${JSON.stringify(FONT_CACHE)};
const PRECACHE = ${precacheJson};

// Install: Precache toàn bộ asset với xử lý lỗi độc lập cho từng asset
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE).then(async (cache) => {
      // 1. Precache shell cốt lõi
      try {
        await cache.addAll(['./', './index.html']);
      } catch (err) {
        console.warn('EduPulse SW: Core shell cache warn', err);
      }
      // 2. Precache các file tĩnh còn lại một cách an toàn (không bị ngắt nếu 1 file lỗi)
      await Promise.allSettled(
        PRECACHE.map(async (url) => {
          try {
            const res = await fetch(url, { cache: 'reload' });
            if (res && (res.ok || res.type === 'opaque')) {
              await cache.put(url, res);
            }
          } catch (e) {
            // Không chặn install nếu 1 asset không tải được
          }
        })
      );
    })
  );
});

// Activate: dọn dẹp các cache cũ và claim clients ngay lập tức
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

// Helper: timeout cho fetch mạng
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

// Fetch routing
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // 1. Xử lý Google Fonts runtime caching
  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    event.respondWith(
      caches.open(FONT_CACHE).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cached;
        try {
          const res = await fetch(request);
          if (res && res.ok) {
            cache.put(request, res.clone());
          }
          return res;
        } catch (e) {
          return cached || new Response('', { status: 408 });
        }
      })
    );
    return;
  }

  // Bỏ qua các domain API bên ngoài (OpenRouter, Supabase, Tavily...)
  if (url.origin !== self.location.origin) return;

  // 2. Navigation Request (mở app / refresh trang):
  // Trên iOS PWA, khi offline phải lập tức trả về cached index.html
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        // Nếu thiết bị đã báo offline, trả ngay cache để tránh iOS timeout màn hình trắng
        if (!self.navigator.onLine) {
          const cached = await caches.match('./index.html') || await caches.match('./');
          if (cached) return cached;
        }

        try {
          // Thử mạng với timeout 2.5s
          const res = await fetchWithTimeout(request, 2500);
          if (res && res.ok) {
            const copy = res.clone();
            caches.open(CACHE).then((c) => c.put(request.url, copy));
            return res;
          }
        } catch (_) {
          // Khi mạng timeout hoặc mất kết nối -> fallback về cache index.html
        }

        const fallback = await caches.match('./index.html') || await caches.match('./');
        if (fallback) return fallback;

        return new Response('EduPulse đang ngoại tuyến. Vui lòng kiểm tra lại kết nối.', {
          status: 503,
          headers: { 'Content-Type': 'text/plain; charset=utf-8' }
        });
      })()
    );
    return;
  }

  // 3. Static Assets (JS, WASM, CSS, Images, Fonts, JSON): Cache-First
  event.respondWith(
    caches.match(request).then(async (cached) => {
      if (cached) {
        // Cập nhật ngầm trong background nếu đang online
        if (self.navigator.onLine) {
          fetch(request)
            .then((networkRes) => {
              if (networkRes && networkRes.ok) {
                caches.open(CACHE).then((c) => c.put(request, networkRes));
              }
            })
            .catch(() => {});
        }
        return cached;
      }

      // Chưa có trong cache -> lấy từ network và lưu lại
      return fetch(request).then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(request, copy));
        }
        return res;
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
