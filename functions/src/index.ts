import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {id, decimalUnits, SCALE, hash, moduleName, active, manager} from './contracts';
admin.initializeApp();
const db = admin.firestore();
const stamp = () => admin.firestore.FieldValue.serverTimestamp();
const fail = (code: functions.https.FunctionsErrorCode, message: string): never => { throw new functions.https.HttpsError(code, message); };
type Tx = admin.firestore.Transaction;
async function authority(tx: Tx, uid: string, c?: string, o?: string) {
  const dev = (await tx.get(db.doc(`dev_roles/${uid}`))).data()?.isActive === true;
  const cm = c ? (await tx.get(db.doc(`construtoras/${c}/construtora_members/${uid}`))).data() : undefined;
  const om = c && o ? (await tx.get(db.doc(`construtoras/${c}/obras/${o}/members/${uid}`))).data() : undefined;
  return {dev, cm, om, admin: dev || manager(cm), obraAdmin: dev || manager(cm) || (active(cm) && manager(om)),
    can: (module: string) => dev || manager(cm) || (active(cm) && (o ? active(om) && (manager(om) || (om?.modules || []).map(moduleName).includes(module)) : (cm?.modules || []).map(moduleName).includes(module)))};
}
function callable(action: string, handler: (data: any, uid: string) => Promise<any>) {
  return functions.https.onCall(async (data, context) => {
    if (!context.auth) return fail('unauthenticated', 'Entre novamente.');
    try {
      if (data?.actorUid && data.actorUid !== context.auth.uid) return fail('unauthenticated', 'A conta mudou. Entre com o usuário que criou a operação.');
      return await handler(data || {}, context.auth.uid);
    }
    catch (error: any) {
      try { await db.collection('audit').add({action, actor: context.auth.uid, target: typeof data?.construtoraId === 'string' ? data.construtoraId : null, result: 'rejected', code: String(error.code || 'invalid-argument'), at: stamp()}); } catch (_) { /* Falha transitória não deve mascarar o resultado original. */ }
      if (error instanceof functions.https.HttpsError) throw error;
      if ([4, 14, 500, 503, 'ENOTFOUND', 'ETIMEDOUT', 'ECONNRESET'].includes(error.code)) return fail('unavailable', 'Serviço temporariamente indisponível. Tente novamente.');
      if (error.code === 404) return fail('failed-precondition', 'Anexo obrigatório não encontrado.');
      return fail('invalid-argument', error.message || 'Entrada inválida');
    }
  });
}
function audit(tx: Tx, actor: string, action: string, target: string, extra: any = {}) {
  tx.create(db.collection('audit').doc(), {actor, action, target, result: 'accepted', at: stamp(), ...extra});
}
export const setDevRole = callable('setDevRole', async (d, uid) => {
  const target = id(d.userId); if (typeof d.isActive !== 'boolean') throw new Error('isActive obrigatório');
  if (target === uid && !d.isActive) fail('failed-precondition', 'Outro dev deve revogar seu acesso.');
  await admin.auth().getUser(target);
  return db.runTransaction(async tx => {
    if (!(await authority(tx, uid)).dev) fail('permission-denied', 'Dev confiável obrigatório');
    tx.set(db.doc(`dev_roles/${target}`), {isActive: d.isActive, updatedBy: uid, updatedAt: stamp()});
    tx.update(db.doc(`users/${target}`), {globalRole: d.isActive ? 'dev' : 'user', updatedAt: stamp()});
    audit(tx, uid, 'setDevRole', target, {isActive: d.isActive}); return {ok: true};
  });
});
async function membership(d: any, uid: string) {
  const c = id(d.construtoraId), o = d.obraId ? id(d.obraId) : undefined;
  const role = d.role || 'member';
  const validRoles = o ? ['admin', 'member', 'operario'] : ['admin', 'member', 'operario', 'owner'];
  if (!validRoles.includes(role)) throw new Error('Papel inválido');
  const modules = (d.modules || []).map(moduleName);
  if (!Array.isArray(modules) || modules.some((m: string) => !(o ? ['diario', 'lotes', 'estoque'] : ['estoque']).includes(m))) throw new Error('Módulos inválidos');

  // Resolve target UID, intercepting user-not-found to create an access_request
  let target: string;
  try {
    target = d.userId ? id(d.userId) : (await admin.auth().getUserByEmail(d.email)).uid;
  } catch (e: any) {
    const isUserNotFound =
      e.code === 'auth/user-not-found' ||
      e.errorInfo?.code === 'auth/user-not-found' ||
      (typeof e.message === 'string' && (e.message.includes('no user record') || e.message.includes('user-not-found')));
    if (isUserNotFound && !d.userId && !o) {
      // Admin requesting a new user: create access_request and return gracefully
      const displayName = typeof d.displayName === 'string' && d.displayName.trim() ? d.displayName.trim() : d.email;
      await db.runTransaction(async tx => {
        const a = await authority(tx, uid, c, o);
        if (!(a.admin)) fail('permission-denied', 'Sem permissão para gerir vínculo');
        const parent = db.doc(`construtoras/${c}`);
        if (!(await tx.get(parent)).exists) fail('not-found', 'Construtora ausente');
      });
      await db.collection('access_requests').add({
        email: d.email,
        displayName,
        role,
        construtoraId: c,
        requestedBy: uid,
        status: 'pending',
        createdAt: stamp(),
      });
      return {ok: true, pendingCreation: true};
    }
    throw e;
  }

  return db.runTransaction(async tx => {
    const a = await authority(tx, uid, c, o);
    if (!(o ? a.obraAdmin : a.admin)) fail('permission-denied', 'Sem permissão para gerir vínculo');
    const parent = db.doc(o ? `construtoras/${c}/obras/${o}` : `construtoras/${c}`);
    if (!(await tx.get(parent)).exists) fail('not-found', 'Escopo ausente');
    const profile = (await tx.get(db.doc(`users/${target}`))).data();
    if (!profile) fail('not-found', 'Perfil ausente');
    const ref = parent.collection(o ? 'members' : 'construtora_members').doc(target);
    const existing = (await tx.get(ref)).data();
    const isOwnerRequested = !o && (role === 'owner' || d.isOwner === true);
    if ((isOwnerRequested || existing?.isOwner) && !a.dev) fail('permission-denied', 'Apenas dev altera proprietário');
    if (o && !(await tx.get(db.doc(`construtoras/${c}/construtora_members/${target}`))).data()?.isActive) fail('failed-precondition', 'Vínculo ativo na construtora obrigatório');
    const willBeOwner = a.dev ? (isOwnerRequested || (d.isOwner !== false && existing?.isOwner === true && role === 'owner')) : false;
    const finalRole = willBeOwner ? 'owner' : role;
    const finalIsAdmin = finalRole === 'admin' || willBeOwner;
    tx.set(ref, {userId: target, construtoraId: c, ...(o ? {obraId: o} : {}), email: profile!.email, displayName: profile!.displayName,
      role: finalRole, modules: [...new Set(modules)], isAdmin: finalIsAdmin, isOwner: willBeOwner,
      isActive: d.isActive !== false, joinedAt: existing?.joinedAt || stamp(), updatedAt: stamp()});
    audit(tx, uid, 'setMembership', ref.path, {role: finalRole, isOwner: willBeOwner}); return {ok: true, uid: target};
  });
}
export const setMembership = callable('setMembership', membership);
export const setConstrutoraRole = callable('setConstrutoraRole', membership);
export const approveAccessRequest = callable('approveAccessRequest', async (d, uid) => {
  const requestId = id(d.requestId);
  if (typeof d.password !== 'string' || d.password.length < 8) throw new Error('Senha deve ter no mínimo 8 caracteres');
  const requestRef = db.doc(`access_requests/${requestId}`);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) fail('not-found', 'Solicitação não encontrada');
  const req = requestSnap.data()!;
  // Idempotency: already approved
  if (req.status === 'approved') return {ok: true};
  if (req.status !== 'pending') fail('failed-precondition', 'Solicitação não está pendente');
  // Validate dev role outside transaction for Auth operations
  const devDoc = await db.doc(`dev_roles/${uid}`).get();
  if (devDoc.data()?.isActive !== true) fail('permission-denied', 'Dev confiável obrigatório');
  // Deterministic UID to allow retry idempotency
  const target = hash({requestId}).slice(0, 28);
  try {
    await admin.auth().createUser({uid: target, email: req.email, password: d.password, displayName: req.displayName});
  } catch (e: any) {
    if (e.code !== 'auth/uid-already-exists') throw e;
  }
  const sevenDays = 7 * 24 * 60 * 60 * 1000;
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + sevenDays);
  await db.runTransaction(async tx => {
    if ((await tx.get(db.doc(`dev_roles/${uid}`))).data()?.isActive !== true) fail('permission-denied', 'Dev revogado');
    // Re-check idempotency inside transaction
    const fresh = (await tx.get(requestRef)).data();
    if (fresh?.status === 'approved') return;
    // Create user profile
    tx.set(db.doc(`users/${target}`), {id: target, email: req.email, displayName: req.displayName, globalRole: 'user', createdAt: stamp(), updatedAt: stamp()});
    // Grant membership on the construtora
    const c = id(req.construtoraId);
    const role = req.role || 'member';
    const finalIsAdmin = role === 'admin';
    const memberRef = db.doc(`construtoras/${c}/construtora_members/${target}`);
    tx.set(memberRef, {userId: target, construtoraId: c, email: req.email, displayName: req.displayName,
      role, modules: [], isAdmin: finalIsAdmin, isOwner: false, isActive: true, joinedAt: stamp(), updatedAt: stamp()});
    // Mark request approved
    tx.update(requestRef, {status: 'approved', approvedBy: uid, approvedAt: stamp()});
    // Notify the requesting admin (ephemeral notification)
    const notifRef = db.collection(`users/${req.requestedBy}/notifications`).doc();
    const roleLabel = role === 'admin' ? 'Administrador' : role === 'owner' ? 'Proprietário' : 'Operário';
    tx.create(notifRef, {
      title: `Conta criada: ${req.displayName}`,
      body: `A conta de ${req.displayName} (${req.email}) foi criada como ${roleLabel}. Senha provisória: ${d.password}. Compartilhe com o funcionário e oriente-o a alterar no primeiro acesso.`,
      read: false,
      createdAt: stamp(),
      expiresAt,
    });
    audit(tx, uid, 'approveAccessRequest', requestRef.path, {target, construtoraId: c, role});
  });
  return {ok: true, uid: target};
});
export const adminCreateUser = callable('adminCreateUser', async (d, uid) => {
  const op = id(d.operationId); const ref = db.doc(`user_provisioning/${hash([uid, op])}`);
  if (typeof d.email !== 'string' || typeof d.password !== 'string' || d.password.length < 8 || typeof d.displayName !== 'string' || !['user', 'dev'].includes(d.globalRole || 'user')) throw new Error('Dados inválidos');
  const payloadHash = hash({email: d.email, displayName: d.displayName, role: d.globalRole || 'user'});
  // Stable UID allows retry after Auth succeeds and Firestore fails. Password is never persisted.
  const target = hash({uid, op}).slice(0, 28);
  await db.runTransaction(async tx => {
    if (!(await authority(tx, uid)).dev) fail('permission-denied', 'Dev confiável obrigatório');
    const old = (await tx.get(ref)).data();
    if (old && old.payloadHash !== payloadHash) fail('already-exists', 'Operação divergente');
    if (!old) tx.create(ref, {payloadHash, target, status: 'pending', at: stamp()});
  });
  try { await admin.auth().createUser({uid: target, email: d.email, password: d.password, displayName: d.displayName}); }
  catch (e: any) { if (e.code !== 'auth/uid-already-exists') throw e; }
  await db.runTransaction(async tx => {
    if (!(await authority(tx, uid)).dev) fail('permission-denied', 'Dev revogado; provisionamento pendente preservado');
    const old = (await tx.get(ref)).data(); if (old?.status === 'complete') return;
    tx.set(db.doc(`users/${target}`), {id: target, email: d.email, displayName: d.displayName, globalRole: d.globalRole || 'user', createdAt: stamp(), updatedAt: stamp()});
    if (d.globalRole === 'dev') tx.set(db.doc(`dev_roles/${target}`), {isActive: true, updatedBy: uid, updatedAt: stamp()});
    tx.update(ref, {status: 'complete'}); audit(tx, uid, 'adminCreateUser', target);
  }); return {uid: target};
});
export const stockCommand = callable('stockCommand', async (d, uid) => {
  const c = id(d.construtoraId), m = id(d.materialId), op = id(d.operationId);
  const type = d.type; if (!['entrada', 'saida', 'estorno', 'ajuste', 'abertura'].includes(type)) throw new Error('Tipo inválido');
  const quantity = type === 'estorno' ? 0 : decimalUnits(d.quantity, SCALE);
  if ((type === 'entrada' || type === 'saida') && quantity <= 0) throw new Error('Quantidade positiva obrigatória');
  const o = d.obraId ? id(d.obraId) : null, l = d.loteId ? id(d.loteId) : null;
  if (type === 'saida' && !o || l && !o || d.apropriacaoLote === true && !l) throw new Error('Destino obrigatório');
  const payload = {
    m, type, quantity, o, l,
    reason: d.reason || d.observacao || '',
    reversalId: d.reversalId || null,
    evidence: d.evidence || null,
    nfNumber: d.nfNumber || null,
    fornecedor: d.fornecedor || null,
    apropriacaoLote: d.apropriacaoLote === true,
    valorItensCentavos: typeof d.valorItensCentavos === 'number' ? Math.round(d.valorItensCentavos) : null,
    freteCentavos: typeof d.freteCentavos === 'number' ? Math.round(d.freteCentavos) : null,
    despesasCentavos: typeof d.despesasCentavos === 'number' ? Math.round(d.despesasCentavos) : null,
    descontoCentavos: typeof d.descontoCentavos === 'number' ? Math.round(d.descontoCentavos) : null,
    custoTotalCentavos: typeof d.custoTotalCentavos === 'number' ? Math.round(d.custoTotalCentavos) : null,
    custoUnitarioCentavos: typeof d.custoUnitarioCentavos === 'number' ? Math.round(d.custoUnitarioCentavos) : null,
  };
  if (payload.custoTotalCentavos !== null && payload.custoTotalCentavos < 0) throw new Error('Custo total não pode ser negativo');
  const h = hash(payload), command = db.doc(`construtoras/${c}/commands/${hash([uid, op])}`), mat = db.doc(`construtoras/${c}/materiais/${m}`);
  return db.runTransaction(async tx => {
    const a = await authority(tx, uid, c, o || undefined); if (!a.can('estoque')) fail('permission-denied', 'Estoque não autorizado');
    if (['estorno', 'ajuste', 'abertura'].includes(type) && (!a.admin || typeof payload.reason !== 'string' || payload.reason.trim().length < 5 || typeof d.evidence !== 'string' || !d.evidence.trim())) fail('permission-denied', 'Correção exige administrador, motivo e evidência');
    const prior = (await tx.get(command)).data();
    if (prior) { if (prior.payloadHash !== h) fail('already-exists', 'operationId com conteúdo diferente'); return prior.result; }
    const material = (await tx.get(mat)).data(); if (!material || material.construtoraId !== c) fail('not-found', 'Material inválido');
    if (o && !(await tx.get(db.doc(`construtoras/${c}/obras/${o}`))).exists) fail('invalid-argument', 'Obra inválida');
    if (l && !(await tx.get(db.doc(`construtoras/${c}/obras/${o}/lotes/${l}`))).exists) fail('invalid-argument', 'Lote inválido');
    let balance = material!.quantityUnits;
    if (balance === undefined) {
      if (type !== 'abertura') fail('failed-precondition', 'Saldo legado exige reconciliação de abertura');
      balance = decimalUnits(material!.currentQuantity, SCALE);
      if (balance !== quantity) fail('failed-precondition', 'Abertura diverge do saldo legado');
    } else if (type === 'abertura') fail('already-exists', 'Saldo já reconciliado');
    if (!Number.isSafeInteger(balance) || balance < 0 || material!.quantityScale !== undefined && material!.quantityScale !== SCALE) fail('failed-precondition', 'Saldo inválido');
    let delta = type === 'saida' ? -quantity : type === 'abertura' ? 0 : quantity;
    let original: admin.firestore.DocumentReference | undefined;
    if (type === 'estorno') {
      original = mat.collection('movimentacoes').doc(id(d.reversalId));
      const old = (await tx.get(original)).data();
      if (!old || old.reversedBy || !['entrada', 'saida', 'ajuste'].includes(old.commandType) || !Number.isSafeInteger(old.deltaUnits)) fail('failed-precondition', 'Movimento não estornável');
      delta = -old!.deltaUnits;
    }
    const next = balance + delta;
    if (!Number.isSafeInteger(next) || next < 0) fail('failed-precondition', 'Saldo insuficiente ou fora do limite');
    const movementId = hash([uid, op]), result = {movementId, quantityUnits: next, quantityScale: SCALE};
    tx.update(mat, {quantityUnits: next, quantityScale: SCALE, currentQuantity: next / SCALE, schemaVersion: 2});
    tx.create(mat.collection('movimentacoes').doc(movementId), {
      id: movementId,
      materialId: m,
      type: delta < 0 ? 'saida' : 'entrada',
      commandType: type,
      quantity: Math.abs(delta) / SCALE,
      quantityUnits: Math.abs(delta),
      deltaUnits: delta,
      quantityScale: SCALE,
      date: admin.firestore.Timestamp.now(),
      responsavelId: uid,
      obraId: o,
      loteId: l,
      observacao: payload.reason,
      evidence: d.evidence || null,
      nfNumber: d.nfNumber || null,
      fornecedor: d.fornecedor || null,
      reversalId: payload.reversalId,
      openingBalanceUnits: type === 'abertura' ? balance : null,
      valorItensCentavos: payload.valorItensCentavos,
      freteCentavos: payload.freteCentavos,
      despesasCentavos: payload.despesasCentavos,
      descontoCentavos: payload.descontoCentavos,
      custoTotalCentavos: payload.custoTotalCentavos,
      custoUnitarioCentavos: payload.custoUnitarioCentavos,
    });
    if (original) tx.update(original, {reversedBy: movementId});
    tx.create(command, {payloadHash: h, result, actor: uid, at: stamp()}); audit(tx, uid, 'stockCommand', mat.path, {operationId: op, type});
    return result;
  });
});
export const payExpense = callable('payExpense', async (d, uid) => {
  const c = id(d.construtoraId), expenseId = id(d.despesaId), op = id(d.operationId);
  const ref = db.doc(`construtoras/${c}/despesas/${expenseId}`), command = db.doc(`construtoras/${c}/commands/${hash([uid, op])}`), h = hash({action: 'payExpense', expenseId});
  return db.runTransaction(async tx => {
    if (!(await authority(tx, uid, c)).admin) fail('permission-denied', 'Financeiro não autorizado');
    const prior = (await tx.get(command)).data(); if (prior) { if (prior.payloadHash !== h) fail('already-exists', 'Operação divergente'); return prior.result; }
    const expense = (await tx.get(ref)).data(); if (!expense || expense.construtoraId !== c) fail('not-found', 'Despesa ausente');
    const cents = expense!.valorEmCentavos ?? decimalUnits(expense!.valor, 100, true);
    if (!Number.isSafeInteger(cents) || cents <= 0) throw new Error('Valor inválido');
    const paymentDate = expense!.status === 'pago' ? expense!.dataPagamento : admin.firestore.Timestamp.now();
    if (!paymentDate) fail('failed-precondition', 'Pagamento legado sem data exige revisão');
    const result = {despesaId: expenseId, status: 'pago'};
    tx.update(ref, {status: 'pago', dataPagamento: paymentDate, valorEmCentavos: cents, schemaVersion: 2});
    tx.create(command, {payloadHash: h, result, actor: uid, at: stamp()}); audit(tx, uid, 'payExpense', ref.path); return result;
  });
});
export const finalizeDiario = callable('finalizeDiario', async (d, uid) => {
  const c = id(d.construtoraId), o = id(d.obraId), op = id(d.operationId), diaryId = id(d.diario?.id);
  const legacy = await db.runTransaction(async tx => {
    if (!(await authority(tx, uid, c, o)).can('diario')) fail('permission-denied', 'Diário não autorizado');
    return (await tx.get(db.doc(`construtoras/${c}/obras/${o}/diarios/${diaryId}`))).data();
  });
  const legacyPaths: string[] = [];
  for (const value of legacy?.photoUrls || []) {
    let path = value;
    if (value.startsWith('https://')) {
      const url = new URL(value);
      if (url.hostname !== 'firebasestorage.googleapis.com') throw new Error('URL legada exige revisão');
      const split = url.pathname.split('/o/'); if (split.length !== 2) throw new Error('URL legada inválida'); path = decodeURIComponent(split[1]);
    } else if (value.startsWith('gs://')) { path = value.slice(5).split('/').slice(1).join('/'); }
    if (!path.startsWith(`construtoras/${c}/obras/${o}/diarios/${diaryId}/`)) throw new Error('Referência legada fora do escopo');
    await admin.storage().bucket().file(path).getMetadata(); legacyPaths.push(path);
  }
  if (!Array.isArray(d.attachments) || d.attachments.length > 30) throw new Error('Anexos inválidos');
  const paths: string[] = [];
  // Storage objects are create-only. Finalization checks authenticated metadata and exact bytes/hash.
  for (const a of d.attachments) {
    const aid = id(a.id), path = `construtoras/${c}/obras/${o}/diarios/${diaryId}/${uid}/${aid}`;
    if (!Number.isSafeInteger(a.size) || a.size <= 0 || a.size > 10 * 1024 * 1024 || !/^[a-f0-9]{64}$/.test(a.sha256)) throw new Error('Integridade inválida');
    const file = admin.storage().bucket().file(path);
    const [meta] = await file.getMetadata();
    if (Number(meta.size) !== a.size || meta.metadata?.sha256 !== a.sha256 || !/^image\/(jpeg|png|webp)$/.test(meta.contentType || '')) fail('failed-precondition', 'Anexo incompleto');
    const [bytes] = await file.download();
    const {createHash} = await import('crypto');
    if (createHash('sha256').update(bytes).digest('hex') !== a.sha256) fail('failed-precondition', 'Hash do anexo divergente');
    paths.push(path);
  }
  if (new Set(paths).size !== paths.length) throw new Error('Anexo duplicado');
  const diary = d.diario;
  if (diary.construtoraId !== c || diary.obraId !== o || diary.responsavelId !== uid || typeof diary.observacoes !== 'string' || diary.observacoes.length > 20000 || !['sol', 'nublado', 'chuvaLeve', 'chuvaIntensa'].includes(diary.weather) || !Array.isArray(diary.efetivo) || diary.efetivo.some((e: any) => typeof e.role !== 'string' || !Number.isSafeInteger(e.count) || e.count < 0)) throw new Error('Diário inválido');
  const date = new Date(diary.date), created = new Date(diary.createdAt); if (!Number.isFinite(+date) || !Number.isFinite(+created)) throw new Error('Data inválida');
  const h = hash({diary, attachments: d.attachments}), ref = db.doc(`construtoras/${c}/obras/${o}/diarios/${diaryId}`), command = db.doc(`construtoras/${c}/commands/${hash([uid, op])}`);
  return db.runTransaction(async tx => {
    if (!(await authority(tx, uid, c, o)).can('diario')) fail('permission-denied', 'Diário não autorizado');
    const prior = (await tx.get(command)).data(); if (prior) { if (prior.payloadHash !== h) fail('already-exists', 'Operação divergente'); return prior.result; }
    if (!(await tx.get(db.doc(`construtoras/${c}/obras/${o}`))).exists) fail('not-found', 'Obra ausente');
    const old = (await tx.get(ref)).data(); if (old && !old.isPendingSync) fail('already-exists', 'Diário já confirmado');
    if (old && old.responsavelId !== uid) fail('permission-denied', 'Pendência de outro responsável');
    if (old && Array.isArray(old.localPhotoPaths) && old.localPhotoPaths.length !== d.attachments.length) fail('failed-precondition', 'Todos os anexos legados devem ser recuperados');
    if (hash(old?.photoUrls || []) !== hash(legacy?.photoUrls || [])) fail('aborted', 'Referências legadas mudaram; tente novamente');
    const confirmedPaths = [...legacyPaths, ...paths];
    const result = {diarioId: diaryId, status: 'synced'};
    tx.set(ref, {id: diaryId, construtoraId: c, obraId: o, date: admin.firestore.Timestamp.fromDate(date), weather: diary.weather, efetivo: diary.efetivo, observacoes: diary.observacoes, responsavelId: uid, createdAt: admin.firestore.Timestamp.fromDate(created), photoUrls: confirmedPaths, attachments: d.attachments, localPhotoPaths: [], isPendingSync: false, schemaVersion: 2});
    tx.create(command, {payloadHash: h, result, actor: uid, at: stamp()}); audit(tx, uid, 'finalizeDiario', ref.path); return result;
  });
});

export const processLogo = functions.storage.object().onFinalize(async (object) => {
  if (!object.name || !object.name.match(/^construtoras\/[^\/]+\/logos\/[^\/]+$/)) return;
  if (object.metadata?.processed === 'true') return;

  const bucket = admin.storage().bucket(object.bucket);
  const file = bucket.file(object.name);
  const [metadata] = await file.getMetadata();

  if (!metadata.contentType?.startsWith('image/')) return;

  const [buffer] = await file.download();
  // @ts-ignore
  const sharp = (await import('sharp')).default || (await import('sharp'));
  
  const processedBuffer = await sharp(buffer)
    .resize({ width: 2000, height: 2000, fit: 'inside', withoutEnlargement: true })
    .toBuffer();

  await file.save(processedBuffer, {
    metadata: {
      contentType: metadata.contentType,
      metadata: { processed: 'true' }
    }
  });
});
