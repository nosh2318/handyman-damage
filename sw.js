// HANDYMAN 車両チェック Service Worker v3
const CACHE = 'handyman-damage-v3';

self.addEventListener('install', e => {
  // キャッシュはしない（常に最新を取得）
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  // 古いキャッシュを全削除
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  // index.html は必ずネットワークから取得（キャッシュ使わない）
  if (e.request.url.includes('supabase.co')) return;
  if (e.request.mode === 'navigate' ||
      e.request.url.endsWith('.html') ||
      e.request.url.endsWith('/')) {
    e.respondWith(fetch(e.request));
    return;
  }
  e.respondWith(fetch(e.request));
});
