#!/usr/bin/env python3
"""Run after flutter build web --no-web-resources-cdn --pwa-strategy=none.
Installs one immutable, complete app version atomically; never caches API data.
"""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]/'build/web'
# FlutterFire normally imports Firebase from gstatic during startup. Bundle the
# exact tested SDK locally, so a cold offline launch needs no external scripts.
sdk=root.parents[2]/'functions/node_modules/firebase'
version_sdk=json.loads((sdk/'package.json').read_text())['version']
if version_sdk!='12.19.0':
    raise SystemExit('Revalidar SDK local com firebase_core_web antes de mudar 12.19.0')
vendor=root/'firebase';vendor.mkdir(exist_ok=True)
services={'core':'app','auth':'auth','firestore':'firestore-pipelines','functions':'functions','storage':'storage'}
for name in services.values():
    body=(sdk/f'firebase-{name}.js').read_text()
    body=body.replace(f'https://www.gstatic.com/firebasejs/{version_sdk}/','./')
    (vendor/f'firebase-{name}.js').write_text(body)
bootstrap="window.firebase_core = await import('./firebase/firebase-app.js');\n"
bootstrap+='\n'.join(f"window.firebase_{service} = await import('./firebase/firebase-{name}.js');" for service,name in services.items() if service!='core')
bootstrap+="\nconst script=document.createElement('script');script.src='flutter_bootstrap.js';document.body.appendChild(script);\n"
(root/'firebase_bootstrap.js').write_text(bootstrap)
index=root/'index.html'
index.write_text(index.read_text().replace('<script src="flutter_bootstrap.js" async></script>','<script type="module" src="firebase_bootstrap.js"></script>'))
files=sorted(p for p in root.rglob('*') if p.is_file() and p.name not in ['sigo-sw.js','flutter_service_worker.js'] and not p.name.endswith('.map'))
if not (root/'canvaskit/canvaskit.wasm').exists():
    raise SystemExit('Build must bundle CanvasKit: --no-web-resources-cdn')
assets=[p.relative_to(root).as_posix() for p in files]
version=hashlib.sha256(b''.join(p.relative_to(root).as_posix().encode()+p.read_bytes() for p in files)).hexdigest()[:20]
source="""const CACHE='sigo-shell-%s';
const ASSETS=%s;
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)).catch(async error=>{await caches.delete(CACHE);throw error;})));
// No skipWaiting or clients.claim: existing tabs retain their complete prior version.
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('sigo-shell-')&&k!==CACHE).map(k=>caches.delete(k))))));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);if(event.request.method!=='GET'||url.origin!==self.location.origin)return;
 const base=new URL('./',self.location.href);const relative=url.pathname.slice(base.pathname.length);
 if(event.request.mode==='navigate'){event.respondWith(caches.open(CACHE).then(cache=>cache.match('index.html')));return;}
 if(ASSETS.includes(relative)){event.respondWith(caches.open(CACHE).then(cache=>cache.match(relative)));}
});
"""%(version,json.dumps(assets))
(root/'sigo-sw.js').write_text(source)
print(f'PWA {version}: {len(assets)} local assets; atomic install; queue database untouched')
