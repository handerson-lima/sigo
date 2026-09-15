const {test,before,after}=require('node:test');const assert=require('node:assert/strict');const {chromium}=require('playwright');const http=require('node:http');const fs=require('node:fs');let browser,server,context,page;
before(async()=>{
 server=http.createServer((req,res)=>{res.setHeader('Content-Type',req.url==='/queue.js'?'text/javascript':'text/html');res.end(req.url==='/queue.js'?fs.readFileSync(require('node:path').resolve(__dirname,'../../app/web/queue.js')): req.url==='/legacy'?'<!doctype html>':'<!doctype html><script src="/queue.js"></script>');});
 await new Promise(resolve=>server.listen(8741,'127.0.0.1',resolve));
 browser=await chromium.launch({channel:process.env.PLAYWRIGHT_CHANNEL || 'chrome',headless:true});context=await browser.newContext();page=await context.newPage();await page.goto('http://127.0.0.1:8741');
});
after(async()=>{await browser?.close();if(server)await new Promise(resolve=>server.close(resolve));});
const call=(p,action,args)=>p.evaluate(async([a,b])=>JSON.parse(await sigoQueue(a,JSON.stringify(b))),[action,args]);
const row=(key,uid)=>({key,uid,payload:{operationId:key,construtoraId:'a'},attachments:[{bytes:'YWJj',sha256:'hash',size:3}],state:'pending',leaseUntil:0,schemaVersion:1});
test('IndexedDB guarda anexos após reabrir aba e isola conta',async()=>{
 await call(page,'insert',row('op1','alice'));await call(page,'insert',row('op2','bob'));
 await page.close();page=await context.newPage();await page.goto('http://127.0.0.1:8741');
 const rows=await call(page,'list',{uid:'alice'});assert.equal(rows.length,1);assert.equal(rows[0].attachments[0].bytes,'YWJj');
 assert.equal((await call(page,'list',{uid:'bob'})).length,1);
});
test('duas abas não adquirem o mesmo lease; conta alheia não finaliza',async()=>{
 const other=await context.newPage();await other.goto('http://127.0.0.1:8741');
 const [a,b]=await Promise.all([call(page,'claim',{key:'op1',uid:'alice',lease:'one'}),call(other,'claim',{key:'op1',uid:'alice',lease:'two'})]);
 assert.equal([a,b].filter(Boolean).length,1);const lease=(a||b).lease;
 assert.equal(await call(other,'finish',{key:'op1',uid:'bob',lease,state:'synced'}),null);
 await call(page,'finish',{key:'op1',uid:'alice',lease,state:'failed',error:'Segundo anexo indisponível'});
 assert.equal((await call(page,'list',{uid:'alice'}))[0].attachments[0].bytes,'YWJj');await other.close();
});
test('reenvio de falha preserva bytes e rejeição não é reexecutada',async()=>{
 const claimed=await call(page,'claim',{key:'op1',uid:'alice',lease:'retry',force:true});assert.ok(claimed);
 await call(page,'finish',{key:'op1',uid:'alice',lease:'retry',state:'authorization_rejected',error:'Acesso removido'});
 await page.reload();assert.equal(await call(page,'claim',{key:'op1',uid:'alice',lease:'again'}),null);
 assert.equal((await call(page,'list',{uid:'alice'}))[0].attachments[0].bytes,'YWJj');
});
test('cache de leitura é eliminado no logout sem apagar operações ou outra conta',async()=>{
 await call(page,'cachePut',{key:'alice-read',uid:'alice',value:{modules:['diario']}});
 await call(page,'cachePut',{key:'bob-read',uid:'bob',value:{modules:['lotes']}});
 assert.deepEqual(await call(page,'cacheGet',{key:'alice-read',uid:'alice'}),{modules:['diario']});
 assert.equal(await call(page,'cacheGet',{key:'alice-read',uid:'bob'}),null);
 await call(page,'cacheClear',{uid:'alice'});
 assert.equal(await call(page,'cacheGet',{key:'alice-read',uid:'alice'}),null);
 assert.deepEqual(await call(page,'cacheGet',{key:'bob-read',uid:'bob'}),{modules:['lotes']});
 assert.equal((await call(page,'list',{uid:'alice'})).length,1);
});

test('upgrade IndexedDB v1 para v2 conserva comandos e anexos',async()=>{
 const fresh=await browser.newContext();const p=await fresh.newPage();
 try {
  await p.goto('http://127.0.0.1:8741/legacy');
  await p.evaluate(()=>new Promise((resolve,reject)=>{const req=indexedDB.open('sigo-operations',1);req.onupgradeneeded=()=>req.result.createObjectStore('operations',{keyPath:'key'});req.onsuccess=()=>{const db=req.result,tx=db.transaction('operations','readwrite');tx.objectStore('operations').add({key:'legacy',uid:'alice',state:'pending',attachments:[{bytes:'YWJj'}]});tx.oncomplete=()=>{db.close();resolve();};tx.onerror=()=>reject(tx.error);};req.onerror=()=>reject(req.error);}));
  await p.goto('http://127.0.0.1:8741');
  assert.equal((await call(p,'list',{uid:'alice'}))[0].attachments[0].bytes,'YWJj');
  await call(p,'cachePut',{uid:'alice',key:'new-cache',value:{name:'Upgrade'}});
  assert.equal((await call(p,'cacheGet',{uid:'alice',key:'new-cache'})).name,'Upgrade');
 }finally{await fresh.close();}
});
