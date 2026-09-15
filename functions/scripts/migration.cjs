#!/usr/bin/env node
/* Offline inventory and demo-only rehearsal. No production write path exists. */
const fs=require('node:fs');
const {decimalUnits,moduleName,hash,SCALE}=require('../lib/contracts');
function plan(input) {
 const report={schemaVersion:2,mode:'dry-run',totals:{legacyRoundedCents:0,newCents:0},roundings:[],review:[],devCandidates:[],verifiedDevs:[],files:[],changes:[]};
 for(const identity of input.identities||[]) {
  report.devCandidates.push({uid:identity.uid,legacyRole:identity.globalRole||null,claims:identity.claims||{}});
 }
 for(const dev of input.verifiedDevs||[]) {
  if(!dev.uid || !dev.verifiedBy || !dev.evidence) throw new Error('UID dev exige responsável e evidência explícitos');
  report.verifiedDevs.push(dev);
 }
 for(const document of input.documents||[]) {
  const {path,data}=document;
  try {
   if(!/^construtoras\/[^/]+\//.test(path)) continue;
   if(/\/despesas\/[^/]+$/.test(path)) {
    const cents=data.valorEmCentavos ?? decimalUnits(data.valor,100,true);
    if(!Number.isSafeInteger(cents)||cents<=0) throw new Error('Valor inválido');
    report.totals.legacyRoundedCents+=decimalUnits(data.valor,100,true); report.totals.newCents+=cents;
    if(String(data.valor)!==String(cents/100)) report.roundings.push({path,legacy:data.valor,cents});
    let civil=data.dataVencimento;
    if(typeof civil!=='string'||!/^\d{4}-\d{2}-\d{2}/.test(civil)) throw new Error('Vencimento Timestamp exige decisão de data civil');
    civil=civil.slice(0,10); if(new Date(`${civil}T00:00:00Z`).toISOString().slice(0,10)!==civil) throw new Error('Data civil inválida');
    const patch={valorEmCentavos:cents,schemaVersion:2,dataVencimento:civil};
    for(const key of ['dataPagamento','createdAt']) { const value=data[key]; if(value==null) continue; const date=typeof value==='string'?new Date(value):Number.isFinite(value._seconds)?new Date(value._seconds*1000):null; if(!date || !Number.isFinite(+date)) throw new Error(`${key} inválida`); patch[key]={timestamp:date.toISOString()}; }
    if(data.status==='pago'&&!data.dataPagamento) throw new Error('Pago sem data exige revisão');
    report.changes.push({path,beforeHash:hash(data),patch});
   }
   if(/\/materiais\/[^/]+$/.test(path) && data.quantityUnits===undefined) {
    const quantityUnits=decimalUnits(data.currentQuantity,SCALE); if(quantityUnits<0) throw new Error('Saldo negativo');
    report.changes.push({path,beforeHash:hash(data),patch:{quantityUnits,quantityScale:SCALE,schemaVersion:2},opening:{id:'migration_opening_v2',commandType:'abertura',type:'entrada',quantity:0,quantityUnits:0,deltaUnits:0,openingBalanceUnits:quantityUnits,quantityScale:SCALE,observacao:'Abertura reconciliada com saldo legado; não representa histórico anterior',evidence:input.evidence||'fixture isolada'}});
   }
   if(/\/(construtora_members|members)\/[^/]+$/.test(path)) {
    if(typeof data.isActive!=='boolean') report.review.push({path,reason:'isActive ausente: falha fechada; autorização explícita necessária'});
    if(!Array.isArray(data.modules)) report.review.push({path,reason:'modules ausente: nenhum módulo central concedido automaticamente'});
    else report.changes.push({path,beforeHash:hash(data),patch:{modules:[...new Set(data.modules.map(moduleName))],schemaVersion:2}});
   }
   if(/\/diarios\/[^/]+$/.test(path)) {
    if(data.localPhotoPaths?.length) report.review.push({path,reason:'Pendência legada depende dos bytes no dispositivo de origem; nunca limpar por migração'});
    for(const value of data.photoUrls||[]) {
     if(typeof value!=='string') throw new Error('Referência inválida');
     let object=value,hasToken=false;
     if(value.startsWith('https://')) { const url=new URL(value); if(url.hostname!=='firebasestorage.googleapis.com'||!url.pathname.includes('/o/')) throw new Error('URL externa exige revisão'); object=decodeURIComponent(url.pathname.split('/o/')[1]);hasToken=url.searchParams.has('token'); }
     const prefix=`${path}/`; if(!object.startsWith(prefix)) throw new Error('Objeto fora do escopo do diário');
     report.files.push({document:path,object,hasToken,requiredAction:'Verificar objeto e leitor privado; converter referência e só então revogar token. Rules não revogam URLs existentes.'});
    }
   }
  } catch(error) { report.review.push({path,reason:error.message}); }
 }
 return report;
}
async function applyDemo(input,report) {
 const project=process.env.GCLOUD_PROJECT;
 if(!project?.startsWith('demo-')||!process.env.FIRESTORE_EMULATOR_HOST||!process.env.FIREBASE_AUTH_EMULATOR_HOST || !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST) || !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST)) throw new Error('Aplicação permitida somente em demo-* com emuladores explícitos');
 const admin=require('firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:project,storageBucket:`${project}.appspot.com`});const db=admin.firestore();
 for(const dev of report.verifiedDevs) { await admin.auth().getUser(dev.uid); await db.doc(`dev_roles/${dev.uid}`).set({isActive:true,verifiedBy:dev.verifiedBy,evidence:dev.evidence,updatedAt:admin.firestore.FieldValue.serverTimestamp()}); }
 for(const change of report.changes) {
  if(report.review.some(item=>item.path===change.path)) continue;
  await db.runTransaction(async tx=>{
   const ref=db.doc(change.path),old=(await tx.get(ref)).data();
   const marker=db.doc(`migration_receipts/${hash({path:change.path,beforeHash:change.beforeHash})}`);
   if((await tx.get(marker)).exists)return;
   // Fixtures use timestamp JSON representations; compare their normalized form.
   if(!old||hash(JSON.parse(JSON.stringify(old)))!==change.beforeHash) throw new Error(`Documento mudou: ${change.path}`);
   const patch={...change.patch};for(const [key,value] of Object.entries(patch)) if(value?.timestamp) patch[key]=admin.firestore.Timestamp.fromDate(new Date(value.timestamp));
   tx.update(ref,patch);
   tx.create(marker,{path:change.path,beforeHash:change.beforeHash,at:admin.firestore.FieldValue.serverTimestamp()});
   if(change.opening) tx.create(ref.collection('movimentacoes').doc(change.opening.id),{...change.opening,materialId:ref.id,responsavelId:'migration-demo',date:admin.firestore.FieldValue.serverTimestamp()});
   tx.create(db.collection('audit').doc(),{actor:'migration-demo',action:'schemaV2',target:ref.path,result:'accepted',at:admin.firestore.FieldValue.serverTimestamp()});
  });
 }
 if(process.env.FIREBASE_STORAGE_EMULATOR_HOST && /^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIREBASE_STORAGE_EMULATOR_HOST)) {
  const bucket=admin.storage().bucket(`${project}.appspot.com`);
  for(const item of report.files) {
   const file=bucket.file(item.object);await file.getMetadata();
   await db.runTransaction(async tx=>{
    const ref=db.doc(item.document),doc=await tx.get(ref);if(!doc.exists)throw new Error('Diário desapareceu');
    const urls=doc.data().photoUrls||[];
    const next=urls.map(value=>{
     if(value===item.object)return value;
     if(value.startsWith('https://')){const url=new URL(value);if(url.hostname==='firebasestorage.googleapis.com'&&decodeURIComponent(url.pathname.split('/o/')[1]||'')===item.object)return item.object;}
     return value;
    });
    tx.update(ref,{photoUrls:next});
   });
   // O emulador acumula tokens ao alterar customMetadata (metadata.js),
   // diferentemente da substituição em GCS. Remover via API administrativa local.
   const [metadata]=await file.getMetadata();
   for(const token of (metadata.metadata?.firebaseStorageDownloadTokens||'').split(',').filter(Boolean)) {
    const endpoint=`http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}/v0/b/${bucket.name}/o/${encodeURIComponent(item.object)}?delete_token=${encodeURIComponent(token)}`;
    const response=await fetch(endpoint,{method:'POST',headers:{Authorization:'Bearer owner'}});
    if(!response.ok)throw new Error(`Falha ao revogar token no emulador: ${response.status}`);
   }
   item.result='referência privada verificada; tokens removidos pela API administrativa do emulador';
  }
 }
 report.mode='demo-applied';
}
if(require.main===module) {
 (async()=>{const source=process.argv[2];if(!source) throw new Error('Uso: node scripts/migration.cjs fixture.json [--apply-demo]'); const input=JSON.parse(fs.readFileSync(source,'utf8'));const report=plan(input);if(process.argv.includes('--apply-demo')) await applyDemo(input,report);process.stdout.write(JSON.stringify(report,null,2)+'\n');if(process.argv.includes('--apply-demo'))await require('firebase-admin').app().delete();})().catch(error=>{console.error(error.message);process.exitCode=1;});
}
module.exports={plan,applyDemo};
