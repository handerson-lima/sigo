// Versioned IndexedDB; upgrade only adds stores, never removes pending records.
const sigoDb = new Promise((resolve, reject) => {
  const request = indexedDB.open('sigo-operations', 2);
  request.onupgradeneeded = () => { if (!request.result.objectStoreNames.contains('snapshots')) request.result.createObjectStore('snapshots', {keyPath:'key'}); if (!request.result.objectStoreNames.contains('operations')) request.result.createObjectStore('operations', {keyPath:'key'}); };
  request.onblocked = () => reject(new Error('Feche as outras abas para atualizar a fila.'));
  request.onsuccess = () => { request.result.onversionchange = () => request.result.close(); resolve(request.result); };
  request.onerror = () => reject(request.error);
});
globalThis.sigoQueue = async (action, json) => {
 const input = JSON.parse(json), db = await sigoDb;
 if(action.startsWith('cache')) return new Promise((resolve,reject)=>{
  const tx=db.transaction('snapshots',action==='cacheGet'?'readonly':'readwrite'),store=tx.objectStore('snapshots');let result=null;
  tx.oncomplete=()=>resolve(JSON.stringify(result));tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);
  if(action==='cacheGet'){const req=store.get(input.key);req.onsuccess=()=>{result=req.result?.uid===input.uid?req.result.value:null;};}
  if(action==='cachePut')store.put(input);
  if(action==='cacheClear'){const req=store.openCursor();req.onsuccess=()=>{const cursor=req.result;if(cursor){if(cursor.value.uid===input.uid)cursor.delete();cursor.continue();}};}
 });
 return new Promise((resolve,reject) => {
  const tx = db.transaction('operations', action === 'list' ? 'readonly' : 'readwrite');
  const store = tx.objectStore('operations'); let result = null;
  tx.oncomplete = () => resolve(JSON.stringify(result));
  tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error || new Error('Fila não persistida'));
  if (action === 'list') { const req=store.getAll(); req.onsuccess=()=>{result=req.result.filter(r=>r.uid===input.uid);}; return; }
  const req=store.get(input.key);
  req.onsuccess=()=>{
   const old=req.result;
   if(action==='insert') { if(old) {result=old;return;} store.add(input); result=input; }
   if(action==='claim') {
    if(!old || old.uid!==input.uid || ['synced','conflict','authorization_rejected'].includes(old.state) || (old.leaseUntil||0)>Date.now() || (!input.force && (old.nextAttemptAt||0)>Date.now())) return;
    old.state='syncing'; old.lease=input.lease; old.leaseUntil=Date.now()+120000; store.put(old); result=old;
   }
   if(action==='finish') {
    if(!old || old.uid!==input.uid || old.lease!==input.lease) return;
    old.state=input.state; old.error=input.error; old.leaseUntil=0; old.lease=null;
    old.attempts=(old.attempts||0)+1; old.nextAttemptAt=input.state==='failed'?Date.now()+Math.min(300000,1000*2**Math.min(old.attempts,8)):0;
    // Retain bytes even after success: explicit cleanup is a separate user action.
    store.put(old); result=old;
   }
  };
 });
};
