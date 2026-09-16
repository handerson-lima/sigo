// Versioned IndexedDB; upgrade only adds stores, never removes pending records.
let currentDbPromise = null;
function getDb() {
  if (currentDbPromise) return currentDbPromise;
  currentDbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open('sigo-operations', 2);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains('snapshots')) db.createObjectStore('snapshots', {keyPath:'key'});
      if (!db.objectStoreNames.contains('operations')) db.createObjectStore('operations', {keyPath:'key'});
    };
    request.onblocked = () => { currentDbPromise = null; reject(new Error('Feche as outras abas para atualizar a fila.')); };
    request.onsuccess = () => {
      const db = request.result;
      db.onversionchange = () => { db.close(); currentDbPromise = null; };
      resolve(db);
    };
    request.onerror = () => { currentDbPromise = null; reject(request.error); };
  });
  return currentDbPromise;
}
globalThis.sigoQueue = async (action, json) => {
  const input = JSON.parse(json), db = await getDb();
 if(action.startsWith('cache')) return new Promise((resolve,reject)=>{
  const tx=db.transaction('snapshots',action==='cacheGet'?'readonly':'readwrite'),store=tx.objectStore('snapshots');let result=null;
  tx.oncomplete=()=>resolve(JSON.stringify(result));tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);
  if(action==='cacheGet'){const req=store.get(input.key);req.onsuccess=()=>{result=req.result?.uid===input.uid?req.result.value:null;};}
  if(action==='cachePut')store.put(input);
  if(action==='cacheClear'){const req=store.openCursor();req.onsuccess=()=>{const cursor=req.result;if(cursor){if(cursor.value.uid===input.uid && (!input.prefix || (cursor.value.key && cursor.value.key.includes(input.prefix))))cursor.delete();cursor.continue();}};}
 });
 return new Promise((resolve,reject) => {
  const tx = db.transaction('operations', action === 'list' ? 'readonly' : 'readwrite');
  const store = tx.objectStore('operations'); let result = null;
  tx.oncomplete = () => resolve(JSON.stringify(result));
  tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error || new Error('Fila não persistida'));
  if (action === 'list') { const req=store.getAll(); req.onsuccess=()=>{result=req.result.filter(r=>r.uid===input.uid && (!input.construtoraId || r.construtoraId===input.construtoraId || r.payload?.construtoraId===input.construtoraId) && (!input.obraId || r.obraId===input.obraId || r.payload?.obraId===input.obraId) && (!input.action || r.action===input.action));}; return; }
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
