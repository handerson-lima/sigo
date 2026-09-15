const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,collection,collectionGroup,query,where,getDocs}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
process.env.GCLOUD_PROJECT='demo-sigo';process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8080';process.env.FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099';process.env.FIREBASE_STORAGE_EMULATOR_HOST='127.0.0.1:9199';process.env.FIREBASE_CONFIG=JSON.stringify({projectId:'demo-sigo',storageBucket:'demo-sigo.appspot.com'});
const root=require('node:path').resolve(__dirname,'../..');
const commands=require(root+'/functions/lib/index.js');
const admin=require(root+'/functions/node_modules/firebase-admin');
const db=admin.firestore();let env;
const ctx=uid=>({auth:{uid,token:{email:`${uid}@example.test`}}});
const invoke=(name,uid,data)=>commands[name].run(data,ctx(uid));
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-sigo',firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync(root+'/firestore.rules','utf8')},storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync(root+'/storage.rules','utf8')}});
 await env.clearFirestore();
 await admin.storage().bucket().deleteFiles({force:true});
 const batch=db.batch();
 for(const uid of ['dev','admin','member','inactive','outsider','owner','obraadmin','nomodule']) batch.set(db.doc('users/'+uid),{id:uid,email:`${uid}@example.test`,displayName:uid,globalRole:uid==='outsider'?'dev':'user'});
 batch.set(db.doc('dev_roles/dev'),{isActive:true});
 for(const c of ['a','b']) {
  batch.set(db.doc('construtoras/'+c),{id:c,name:c});
  batch.set(db.doc(`construtoras/${c}/obras/o`),{id:'o',construtoraId:c,name:'Obra'});
  batch.set(db.doc(`construtoras/${c}/obras/o/lotes/l`),{id:'l',obraId:'o',construtoraId:c,name:'Lote'});
 }
 for(const [uid,active,adm,mods] of [['admin',true,true,[]],['member',true,false,['estoque']],['inactive',false,true,['estoque']],['owner',true,false,[]],['obraadmin',true,false,[]],['nomodule',true,false,[]]]) {
  batch.set(db.doc(`construtoras/a/construtora_members/${uid}`),{userId:uid,isActive:active,isAdmin:adm,isOwner:uid==='owner',modules:mods});
  batch.set(db.doc(`construtoras/a/obras/o/members/${uid}`),{userId:uid,isActive:true,isAdmin:uid==='obraadmin',modules:uid==='nomodule'?[]:['diario','lotes']});
 }
 batch.set(db.doc('construtoras/a/materiais/m'),{id:'m',construtoraId:'a',name:'Cimento',unit:'un',quantityUnits:10000,quantityScale:1000,currentQuantity:10,schemaVersion:2});
 batch.set(db.doc('construtoras/a/despesas/e'),{id:'e',construtoraId:'a',valor:12.34,status:'pendente',dataPagamento:null});
 await batch.commit();
});
after(async()=>{await env?.cleanup();await admin.app().delete();});
test('comum não pode se promover nem escrever autoridade dev',async()=>{
 const d=env.authenticatedContext('member').firestore();
 await assertFails(updateDoc(doc(d,'users/member'),{globalRole:'dev'}));
 await assertFails(setDoc(doc(d,'dev_roles/member'),{isActive:true}));
 await assertSucceeds(updateDoc(doc(d,'users/member'),{displayName:'Membro'}));
});
test('troca de conta entre fila e callable não executa comando de outro ator',async()=>{
 const before=(await db.doc('construtoras/a/materiais/m').get()).data().quantityUnits;
 await assert.rejects(invoke('stockCommand','dev',{actorUid:'member',operationId:'account-race',construtoraId:'a',materialId:'m',type:'entrada',quantity:'1'}),e=>e.code==='unauthenticated');
 assert.equal((await db.doc('construtoras/a/materiais/m').get()).data().quantityUnits,before);
});
test('dev confiável global; perfil globalRole legado não autoriza',async()=>{
 await assertSucceeds(getDoc(doc(env.authenticatedContext('dev').firestore(),'construtoras/b/obras/o')));
 await assertFails(getDoc(doc(env.authenticatedContext('outsider',{email:'dev@marandu.com',role:'admin',construtoraId:'a'}).firestore(),'construtoras/a/materiais/m')));
});
test('revogação supera claims e isolamento entre construtoras',async()=>{
 await assertFails(getDoc(doc(env.authenticatedContext('inactive',{role:'admin',construtoraId:'a'}).firestore(),'construtoras/a/materiais/m')));
 await assertFails(getDoc(doc(env.authenticatedContext('member').firestore(),'construtoras/b/obras/o')));
 await assertSucceeds(getDoc(doc(env.authenticatedContext('member').firestore(),'construtoras/a/obras/o/lotes/l')));
});
test('descoberta collectionGroup própria e consulta ampla negada',async()=>{
 const d=env.authenticatedContext('member').firestore();
 for(const group of ['construtora_members','members']) {
  const rows=await assertSucceeds(getDocs(query(collectionGroup(d,group),where('userId','==','member'),where('isActive','==',true)))); assert.equal(rows.size,1);
  await assertFails(getDocs(collectionGroup(d,group)));
 }
});
test('saldo/histórico não podem ser gravados diretamente nem por dev',async()=>{
 for(const uid of ['member','admin','dev']) {
 const d=env.authenticatedContext(uid).firestore();await assertFails(updateDoc(doc(d,'construtoras/a/materiais/m'),{quantityUnits:1}));
 await assertFails(setDoc(doc(d,'construtoras/a/materiais/m/movimentacoes/forged'),{quantity:10}));
 }
});
test('estoque replay, payload divergente, concorrência e destino',async()=>{
 const p={construtoraId:'a',materialId:'m',operationId:'out1',type:'saida',quantity:2,obraId:'o',loteId:'l'};
 const result=await invoke('stockCommand','member',p);assert.equal(result.quantityUnits,8000);assert.deepEqual(await invoke('stockCommand','member',p),result);
 await assert.rejects(invoke('stockCommand','member',{...p,quantity:3}));
 const results=await Promise.allSettled(['out2','out3'].map(operationId=>invoke('stockCommand','member',{...p,operationId,quantity:6})));
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await db.doc('construtoras/a/materiais/m').get()).data().quantityUnits,2000);
 await assert.rejects(invoke('stockCommand','member',{...p,operationId:'wrong',obraId:'missing'}));
 await assert.rejects(invoke('stockCommand','inactive',{...p,operationId:'revoked'}));
});
test('pagamento legado é idempotente e preserva timestamp entre comandos',async()=>{
 const p={construtoraId:'a',despesaId:'e',operationId:'pay1'};await invoke('payExpense','admin',p);
 const a=(await db.doc('construtoras/a/despesas/e').get()).data();assert.equal(a.valorEmCentavos,1234);
 await invoke('payExpense','admin',p);await invoke('payExpense','dev',{...p,operationId:'pay2'});
 const b=(await db.doc('construtoras/a/despesas/e').get()).data();assert.ok(a.dataPagamento.isEqual(b.dataPagamento));
 await assert.rejects(invoke('payExpense','member',p));
});
test('arquivos privados por obra e imutáveis após upload',async()=>{
 const path='construtoras/a/obras/o/diarios/d/member/photo';const bytes=Buffer.from([255,216,255,1]);
 const sha=require('node:crypto').createHash('sha256').update(bytes).digest('hex');
 const s=env.authenticatedContext('member').storage('gs://demo-sigo.appspot.com');
 await assertSucceeds(uploadBytes(ref(s,path),bytes,{contentType:'image/jpeg',customMetadata:{owner:'member',sha256:sha}}));
 await assertSucceeds(getBytes(ref(s,path)));
 await assertFails(getBytes(ref(env.authenticatedContext('outsider').storage('gs://demo-sigo.appspot.com'),path)));
 await assertSucceeds(getBytes(ref(env.authenticatedContext('dev').storage('gs://demo-sigo.appspot.com'),path)));
 await assertFails(uploadBytes(ref(s,path),Buffer.from([255,216,255,2]),{contentType:'image/jpeg',customMetadata:{owner:'member',sha256:sha}}));
 const diario={id:'d',construtoraId:'a',obraId:'o',responsavelId:'member',date:'2026-09-15',createdAt:'2026-09-15T12:00:00Z',weather:'sol',efetivo:[],observacoes:'Diário'};
 const payload={construtoraId:'a',obraId:'o',operationId:'diary1',diario,attachments:[{id:'photo',size:bytes.length,sha256:sha}]};
 await invoke('finalizeDiario','member',payload);await invoke('finalizeDiario','member',payload);
 assert.equal((await db.doc('construtoras/a/obras/o/diarios/d').get()).data().isPendingSync,false);
 await assert.rejects(invoke('finalizeDiario','member',{...payload,operationId:'missing',diario:{...diario,id:'d2'}}));
 assert.equal((await db.doc('construtoras/a/obras/o/diarios/d2').get()).exists,false);
});

test('matriz owner e admin obra não concede financeiro ao membro',async()=>{
 await assertSucceeds(getDoc(doc(env.authenticatedContext('owner').firestore(),'construtoras/a/despesas/e')));
 await assertSucceeds(getDoc(doc(env.authenticatedContext('obraadmin').firestore(),'construtoras/a/obras/o/lotes/l')));
 for(const uid of ['obraadmin','nomodule']) await assertFails(getDoc(doc(env.authenticatedContext(uid).firestore(),'construtoras/a/despesas/e')));
 await assertFails(getDoc(doc(env.authenticatedContext('nomodule').firestore(),'construtoras/a/obras/o/diarios/d')));
});
test('abertura e estorno preservam saldo e impedem reversão duplicada',async()=>{
 const mat=db.doc('construtoras/a/materiais/legacy');await mat.set({id:'legacy',construtoraId:'a',currentQuantity:5.125,name:'Areia',unit:'m3'});
 const base={construtoraId:'a',materialId:'legacy',operationId:'opening',type:'abertura',quantity:'5.125',reason:'Conferência inicial',evidence:'inventario-2026'};
 await assert.rejects(invoke('stockCommand','member',base));
 const opening=await invoke('stockCommand','admin',base);assert.equal(opening.quantityUnits,5125);
 assert.deepEqual(await invoke('stockCommand','admin',base),opening);
 const out=await invoke('stockCommand','member',{construtoraId:'a',materialId:'legacy',operationId:'legacy-out',type:'saida',quantity:'1.125',obraId:'o'});
 const reversal={construtoraId:'a',materialId:'legacy',operationId:'reverse',type:'estorno',reversalId:out.movementId,reason:'Correção de saída',evidence:'foto-conferencia'};
 const result=await invoke('stockCommand','dev',reversal);assert.equal(result.quantityUnits,5125);
 assert.deepEqual(await invoke('stockCommand','dev',reversal),result);
 await assert.rejects(invoke('stockCommand','dev',{...reversal,operationId:'reverse-again'}));
});
test('dev provisiona usuário e repete comando sem duplicar; admin não concede dev',async()=>{
 const payload={operationId:'create-user-test',email:'new-user@example.test',password:'A-test-password-123',displayName:'Teste',globalRole:'user'};
 const result=await invoke('adminCreateUser','dev',payload);assert.deepEqual(await invoke('adminCreateUser','dev',payload),result);
 await assert.rejects(invoke('setDevRole','admin',{userId:result.uid,isActive:true}));
 await invoke('setDevRole','dev',{userId:result.uid,isActive:true});assert.equal((await db.doc('dev_roles/'+result.uid).get()).data().isActive,true);
 await invoke('setMembership','dev',{construtoraId:'b',userId:result.uid,role:'admin',modules:[]});assert.equal((await db.doc(`construtoras/b/construtora_members/${result.uid}`).get()).data().isAdmin,true);
 await invoke('setDevRole','dev',{userId:result.uid,isActive:false});assert.equal((await db.doc('dev_roles/'+result.uid).get()).data().isActive,false);
 await assert.rejects(invoke('setMembership','obraadmin',{construtoraId:'a',userId:result.uid,role:'admin'}));
});
test('diário não confirma anexo ausente, corrompido ou pendência legada incompleta',async()=>{
 const diario={id:'legacy-diary',construtoraId:'a',obraId:'o',responsavelId:'member',date:'2026-09-15',createdAt:'2026-09-15T12:00:00Z',weather:'sol',efetivo:[],observacoes:'Pendência'};
 await db.doc('construtoras/a/obras/o/diarios/legacy-diary').set({...diario,isPendingSync:true,photoUrls:[],localPhotoPaths:['/device/photo.jpg']});
 const payload={construtoraId:'a',obraId:'o',operationId:'legacy-diary',diario,attachments:[]};
 await assert.rejects(invoke('finalizeDiario','member',payload));
 assert.equal((await db.doc('construtoras/a/obras/o/diarios/legacy-diary').get()).data().isPendingSync,true);
 const bytes=Buffer.from([255,216,255,3]),badHash='a'.repeat(64),path='construtoras/a/obras/o/diarios/legacy-diary/member/corrupt';
 await admin.storage().bucket().file(path).save(bytes,{metadata:{contentType:'image/jpeg',metadata:{owner:'member',sha256:badHash}}});
 await assert.rejects(invoke('finalizeDiario','member',{...payload,attachments:[{id:'corrupt',size:bytes.length,sha256:badHash}]}));
 assert.equal((await db.doc('construtoras/a/obras/o/diarios/legacy-diary').get()).data().isPendingSync,true);
});
test('revogação de módulo bloqueia arquivos existentes',async()=>{
 const membership=db.doc('construtoras/a/obras/o/members/member');await membership.update({modules:[]});
 await assertFails(getBytes(ref(env.authenticatedContext('member').storage('gs://demo-sigo.appspot.com'),'construtoras/a/obras/o/diarios/d/member/photo')));
 await membership.update({modules:['diario','lotes']});
});
test('material novo inicia zerado e despesa não aceita escopo alheio',async()=>{
 const d=env.authenticatedContext('admin').firestore();
 const material={id:'new',construtoraId:'a',name:'Novo',unit:'un',quantityUnits:0,quantityScale:1000,currentQuantity:0,schemaVersion:2};
 await assertSucceeds(setDoc(doc(d,'construtoras/a/materiais/new'),material));
 await assertFails(setDoc(doc(d,'construtoras/a/materiais/nonzero'),{...material,id:'nonzero',quantityUnits:1000,currentQuantity:1}));
 const expense={id:'new',construtoraId:'a',obraId:null,descricao:'Nova',valor:12.34,valorEmCentavos:1234,dataVencimento:'2026-09-20',dataPagamento:null,status:'pendente',categoria:'Material',responsavelId:'admin',createdAt:new Date(),schemaVersion:2};
 await assertSucceeds(setDoc(doc(d,'construtoras/a/despesas/new'),expense));
 await assertFails(setDoc(doc(d,'construtoras/a/despesas/wrong'),{...expense,id:'wrong',obraId:'not-a-project'}));
 await assertFails(updateDoc(doc(d,'construtoras/a/despesas/new'),{status:'pago'}));
});
test('ensaio de migração é retomável e preserva pendências sem promover dev forjado',async()=>{
 const {plan,applyDemo}=require('../scripts/migration.cjs');
 const input=JSON.parse(fs.readFileSync(root+'/functions/scripts/migration-fixture.json','utf8'));
 for(const item of input.documents)await db.doc(item.path).set(item.data);
 for(const item of plan(input).files)await admin.storage().bucket().file(item.object).save(Buffer.from('foto fixture'),{metadata:{contentType:'image/jpeg',metadata:{firebaseStorageDownloadTokens:'old-token'}}});
 const report=plan(input);await applyDemo(input,report);await applyDemo(input,report);
 assert.equal((await db.doc('construtoras/A/despesas/d1').get()).data().valorEmCentavos,101);
 assert.equal((await db.doc('construtoras/A/materiais/m1').get()).data().quantityUnits,12345);
 assert.equal((await db.collection('construtoras/A/materiais/m1/movimentacoes').get()).size,1);
 assert.equal((await db.doc('dev_roles/forged').get()).exists,false);
 assert.deepEqual((await db.doc('construtoras/A/obras/O/diarios/d').get()).data().localPhotoPaths,['/original/foto.jpg']);
 const [meta]=await admin.storage().bucket().file('construtoras/A/obras/O/diarios/d/photo').getMetadata();assert.notEqual(meta.metadata?.firebaseStorageDownloadTokens,'old-token');
 const oldLink='http://127.0.0.1:9199/v0/b/demo-sigo.appspot.com/o/'+encodeURIComponent('construtoras/A/obras/O/diarios/d/photo')+'?alt=media&token=old-token';
 assert.equal((await fetch(oldLink)).status,403);
 fs.writeFileSync(root+'/docs/change-control/migration-rehearsal.json',JSON.stringify(report,null,2)+'\n');
});
