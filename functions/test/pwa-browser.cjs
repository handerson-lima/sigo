const {test}=require('node:test');const assert=require('node:assert/strict');const {chromium}=require('playwright');const http=require('node:http');const fs=require('node:fs');const path=require('node:path');
test('PWA inicializa sem CDN e reabre offline preservando fila', {timeout:120000}, async()=>{
 const root=path.resolve(__dirname,'../../app/build/web');
 assert.ok(fs.readFileSync(root+'/main.dart.js','utf8').includes('demo-sigo'),'Exige build SIGO_EMULATORS=true');
 const types={'.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.html':'text/html'};
 const server=http.createServer((req,res)=>{let rel=decodeURIComponent(new URL(req.url,'http://localhost').pathname);let file=path.resolve(root,'.'+rel);if(!file.startsWith(root+path.sep)&&file!==root){res.writeHead(403).end();return;}if(!fs.existsSync(file)||fs.statSync(file).isDirectory())file=root+'/index.html';res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.setHeader('Cache-Control','no-cache');res.end(fs.readFileSync(file));});
 await new Promise(resolve=>server.listen(8742,'127.0.0.1',resolve));let browser,adminApp;
 try {
  browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:390,height:844}});const blocked=[];
  await context.route('**/*',route=>{const u=new URL(route.request().url());if(!['127.0.0.1','localhost'].includes(u.hostname)){blocked.push(u.href);return route.abort();}return route.continue();});
  let page=await context.newPage();page.on('pageerror',e=>console.error(e.message));await page.goto('http://127.0.0.1:8742');
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');await page.getByRole('button',{name:'Entrar',exact:true}).waitFor({timeout:30000});
  assert.equal(blocked.filter(x=>x.includes('firebasejs')||x.includes('canvaskit')).length,0);
  await page.evaluate(()=>navigator.serviceWorker.ready);
  await page.evaluate(()=>sigoQueue('insert',JSON.stringify({key:'offline-proof',uid:'offline-user',state:'pending',payload:{operationId:'offline-proof'},attachments:[{bytes:'YWJj'}]})));
  await page.close();await context.setOffline(true);page=await context.newPage();await page.goto('http://127.0.0.1:8742');
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');await page.getByRole('button',{name:'Entrar',exact:true}).waitFor({timeout:30000});
  const rows=await page.evaluate(async()=>JSON.parse(await sigoQueue('list',JSON.stringify({uid:'offline-user'}))));assert.equal(rows[0].attachments[0].bytes,'YWJj');
  await page.screenshot({path:path.resolve(__dirname,'../../docs/change-control/pwa-offline-chrome.png')});
  await context.setOffline(false);
  process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8080';process.env.FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099';
  const admin=require('firebase-admin');adminApp=admin.initializeApp({projectId:'demo-sigo'},'pwa-test');
  const uid='pwa-user';try{await adminApp.auth().createUser({uid,email:'pwa@example.test',password:'DemoPassword123!'});}catch(e){if(e.code!=='auth/uid-already-exists')throw e;}
  const db=adminApp.firestore(),stamp=new Date().toISOString();
  await db.doc('users/'+uid).set({id:uid,email:'pwa@example.test',displayName:'Ensaio PWA',createdAt:stamp,globalRole:'user'});
  await db.doc('construtoras/pwa').set({id:'pwa',name:'Construtora PWA',createdAt:stamp});
  await db.doc('construtoras/pwa/obras/o').set({id:'o',construtoraId:'pwa',name:'Obra PWA',createdAt:stamp});
  await db.doc('construtoras/pwa/construtora_members/'+uid).set({userId:uid,construtoraId:'pwa',isActive:true,isAdmin:false,modules:[],joinedAt:stamp,role:'member'});
  await db.doc('construtoras/pwa/obras/o/members/'+uid).set({userId:uid,obraId:'o',construtoraId:'pwa',isActive:true,isAdmin:false,modules:['diario'],joinedAt:stamp,role:'member'});
  await page.getByRole('textbox',{name:'E-mail',exact:true}).fill('pwa@example.test');
  await page.getByRole('textbox',{name:'Senha',exact:true}).fill('DemoPassword123!');
  await page.getByRole('button',{name:'Entrar',exact:true}).click();
  await page.getByText('Construtora PWA',{exact:true}).waitFor({timeout:20000});
  await page.goto('http://127.0.0.1:8742/#/construtora/pwa/obra/o/diarios/novo');
  const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.dispatchEvent('click');
  await page.getByText('Novo RDO',{exact:true}).waitFor({timeout:20000});
  // Aguarda os documentos de autorização serem persistidos antes de cortar a rede.
  await page.waitForFunction(async()=>JSON.parse(await sigoQueue('cacheGet',JSON.stringify({uid:'pwa-user',key:JSON.stringify(['pwa-user','construtoras/pwa/obras/o/members/pwa-user'])})))?.isActive===true);
  await context.setOffline(true);await page.close();page=await context.newPage();
  await page.goto('http://127.0.0.1:8742/#/construtora/pwa/obra/o/diarios/novo');await page.locator('flt-semantics-placeholder').dispatchEvent('click');
  await page.getByText('Novo RDO',{exact:true}).waitFor({timeout:20000});
  await page.getByRole('textbox',{name:'Atividades e Observações do Dia'}).fill('Registro offline validado');
  await page.getByRole('button',{name:'Salvar Relatório Diário',exact:true}).click();
  await page.waitForFunction(async()=>JSON.parse(await sigoQueue('list',JSON.stringify({uid:'pwa-user'}))).some(row=>row.action==='finalizeDiario'&&row.payload.diario.observacoes==='Registro offline validado'));
  const saved=await page.evaluate(async()=>JSON.parse(await sigoQueue('list',JSON.stringify({uid:'pwa-user'}))));assert.equal(saved.filter(r=>r.action==='finalizeDiario').length,1);assert.notEqual(saved.find(r=>r.action==='finalizeDiario').state,'synced');

 } finally {await browser?.close();await adminApp?.delete();await new Promise(resolve=>server.close(resolve));}
});
