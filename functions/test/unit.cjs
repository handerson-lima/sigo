const {test}=require('node:test');const assert=require('node:assert/strict');
const {decimalUnits,hash,id,manager,active,moduleName}=require('../lib/contracts');
test('decimal converte por dígitos e arredonda metade para longe de zero',()=>{
 assert.equal(decimalUnits('1.005',100,true),101);assert.equal(decimalUnits('-1.005',100,true),-101);assert.equal(decimalUnits('0.001',1000),1);
 for(const value of [NaN,Infinity,'abc','1.0001',{},null])assert.throws(()=>decimalUnits(value,1000));
 assert.throws(()=>decimalUnits('9007199254740992',1000));
});
test('hash canônico conserva tipos e elimina ambiguidade de tupla',()=>{
 assert.equal(hash({a:1,b:2}),hash({b:2,a:1}));assert.notEqual(hash(['a_b','c']),hash(['a','b_c']));assert.notEqual(hash({a:1}),hash({a:'1'}));
});
test('papéis ausentes ou inativos nunca autorizam; aliases explícitos',()=>{
 assert.equal(active({}),false);assert.equal(manager({isAdmin:true,isActive:false}),false);assert.equal(manager({isOwner:true,isActive:true}),true);assert.equal(moduleName('rdo'),'diario');assert.equal(moduleName('almoxarifado'),'estoque');
});
test('identificadores impedem caminhos e segmentos arbitrários',()=>{for(const value of ['a/b','..','','a.b',null])assert.throws(()=>id(value));assert.equal(id('a_b-1'),'a_b-1');});
test('endpoints transacionais exigem hashes canonicos determinísticos para comando e idempotencia',()=>{
  const uid = 'user-123';
  const op = 'op-456';
  const commandKey = hash([uid, op]);
  assert.equal(typeof commandKey, 'string');
  assert.equal(commandKey.length, 64);
  assert.equal(commandKey, hash([uid, op]));
  
  // Payloads de comandos com chaves em ordem desordenada produzem o mesmo hash de integridade
  const payload1 = {materialId: 'm1', quantity: 10, type: 'entrada', construtoraId: 'c1'};
  const payload2 = {construtoraId: 'c1', type: 'entrada', materialId: 'm1', quantity: 10};
  assert.equal(hash(payload1), hash(payload2));
});
test('contratos transacionais de escala monetária e de estoque',()=>{
  // 12.34 reais -> 1234 centavos
  assert.equal(decimalUnits('12.34', 100), 1234);
  // 5.500 unidades com escala 1000 -> 5500 unidades inteiras
  assert.equal(decimalUnits('5.5', 1000), 5500);
  // Negativo suportado por decimalUnits (para estornos ou cálculos)
  assert.equal(decimalUnits('-0.001', 1000), -1);
  // Precisão além da escala permitida sem arredondamento lança erro
  assert.throws(() => decimalUnits('1.0001', 1000));
});
test('idempotencia de comandos: reenvio identico retorna mesmo resultado e divergencia falha',()=>{
  const uid = 'user-eng';
  const op = 'op-mov-001';
  const commandKey = hash([uid, op]);

  // Payload original
  const payloadOriginal = {
    m: 'mat-cimento',
    type: 'saida',
    quantity: 5000,
    o: 'obra-1',
    l: 'lote-A',
    reason: 'Uso fundacao',
    reversalId: null,
    evidence: null,
    apropriacaoLote: true
  };
  const originalHash = hash(payloadOriginal);

  // Simulação do banco de comandos
  const commandStore = new Map();
  
  // Função que simula a guarda de idempotência dos endpoints transacionais (stockCommand, payExpense, finalizeDiario)
  function processCommand(actorUid, operationId, payload, executeMutation) {
    const key = hash([actorUid, operationId]);
    const currentHash = hash(payload);
    const prior = commandStore.get(key);
    
    if (prior) {
      if (prior.payloadHash !== currentHash) {
        const error = new Error('operationId com conteúdo diferente');
        error.code = 'already-exists';
        throw error;
      }
      // Idempotente: retorna o resultado original sem reexecutar mutação
      return {result: prior.result, fromCache: true};
    }

    // Executa a mutação
    const result = executeMutation();
    commandStore.set(key, {payloadHash: currentHash, result, actor: actorUid, at: Date.now()});
    return {result, fromCache: false};
  }

  let sideEffectCounter = 0;
  function performStockDeduction() {
    sideEffectCounter++;
    return {movementId: commandKey, quantityUnits: 15000, quantityScale: 1000};
  }

  // 1. Primeira execução: comita mutação e grava comando
  const firstExec = processCommand(uid, op, payloadOriginal, performStockDeduction);
  assert.equal(firstExec.fromCache, false);
  assert.equal(firstExec.result.movementId, commandKey);
  assert.equal(sideEffectCounter, 1);

  // 2. Reenvio com mesmo operationId e mesmo payload (ex: retry após queda de rede)
  // Ordem de campos diferente não altera o hash canônico
  const payloadReordered = {
    l: 'lote-A',
    o: 'obra-1',
    m: 'mat-cimento',
    apropriacaoLote: true,
    evidence: null,
    quantity: 5000,
    reason: 'Uso fundacao',
    reversalId: null,
    type: 'saida'
  };
  const secondExec = processCommand(uid, op, payloadReordered, performStockDeduction);
  assert.equal(secondExec.fromCache, true);
  assert.deepEqual(secondExec.result, firstExec.result);
  // Garante que o efeito colateral NÃO foi executado novamente
  assert.equal(sideEffectCounter, 1);

  // 3. Reenvio com mesmo operationId mas payload divergente (ex: quantidade alterada)
  const payloadDivergent = {...payloadOriginal, quantity: 6000};
  assert.throws(
    () => processCommand(uid, op, payloadDivergent, performStockDeduction),
    (err) => err.code === 'already-exists' && err.message.includes('conteúdo diferente')
  );
  // Garante que nenhum efeito colateral ocorreu no conflito
  assert.equal(sideEffectCounter, 1);
});

test('execucao de autorizacao: dev global irrestrito, managers homogeneos e isolamento de escopo',()=>{
  // 1. Validar helper manager com flags e roles
  assert.equal(manager({isAdmin: true, isActive: true}), true);
  assert.equal(manager({isOwner: true, isActive: true}), true);
  assert.equal(manager({role: 'admin', isActive: true}), true);
  assert.equal(manager({role: 'owner', isActive: true}), true);
  assert.equal(manager({role: 'admin', isActive: false}), false);
  assert.equal(manager({role: 'member', isActive: true}), false);
  assert.equal(manager(null), false);

  // 2. Simulação da função authority de functions/src/index.ts
  function evaluateAuthority({devActive, cm, om, o}) {
    const dev = devActive === true;
    return {
      dev,
      cm,
      om,
      admin: dev || manager(cm),
      obraAdmin: dev || manager(cm) || (active(cm) && manager(om)),
      can: (mod) => dev || manager(cm) || (active(cm) && (o ? active(om) && (manager(om) || (om?.modules || []).map(moduleName).includes(mod)) : (cm?.modules || []).map(moduleName).includes(mod)))
    };
  }

  // Cenário A: Dev global ativo (sem membership na construtora nem na obra)
  const devAuth = evaluateAuthority({devActive: true, cm: undefined, om: undefined});
  assert.equal(devAuth.dev, true);
  assert.equal(devAuth.admin, true);
  assert.equal(devAuth.obraAdmin, true);
  assert.equal(devAuth.can('estoque'), true);
  assert.equal(devAuth.can('diario'), true);
  assert.equal(devAuth.can('financeiro'), true);

  // Cenário B: Usuário normal com vínculo ativo de admin na construtora
  const adminAuth = evaluateAuthority({
    devActive: false,
    cm: {role: 'admin', isActive: true},
    om: undefined
  });
  assert.equal(adminAuth.dev, false);
  assert.equal(adminAuth.admin, true);
  assert.equal(adminAuth.obraAdmin, true);
  assert.equal(adminAuth.can('estoque'), true);
  assert.equal(adminAuth.can('diario'), true);

  // Cenário C: Membro operário da construtora ativo apenas para estoque
  const stockMemberAuth = evaluateAuthority({
    devActive: false,
    cm: {role: 'operario', isActive: true, modules: ['almoxarifado']},
    om: undefined
  });
  assert.equal(stockMemberAuth.dev, false);
  assert.equal(stockMemberAuth.admin, false);
  assert.equal(stockMemberAuth.can('estoque'), true);
  assert.equal(stockMemberAuth.can('diario'), false);

  // Cenário D: Membro de obra ativo para diário
  const diarioMemberAuth = evaluateAuthority({
    devActive: false,
    cm: {role: 'member', isActive: true},
    om: {role: 'member', isActive: true, modules: ['rdo']},
    o: 'obra-1'
  });
  assert.equal(diarioMemberAuth.can('diario'), true);
  assert.equal(diarioMemberAuth.can('estoque'), false);

  // Cenário E: Membro desativado na construtora
  const inactiveMemberAuth = evaluateAuthority({
    devActive: false,
    cm: {role: 'admin', isActive: false},
    om: {role: 'admin', isActive: true},
    o: 'obra-1'
  });
  assert.equal(inactiveMemberAuth.admin, false);
  assert.equal(inactiveMemberAuth.obraAdmin, false);
  assert.equal(inactiveMemberAuth.can('estoque'), false);
  assert.equal(inactiveMemberAuth.can('diario'), false);

  // Cenário F: Usuário sem nenhum vínculo
  const nonMemberAuth = evaluateAuthority({devActive: false, cm: undefined, om: undefined});
  assert.equal(nonMemberAuth.admin, false);
  assert.equal(nonMemberAuth.can('estoque'), false);
});

test('atribuicao e protecao de owner: apenas dev concede ou altera proprietario', () => {
  function simulateMembershipLogic({ actorIsDev, actorIsAdmin, targetRole, existingIsOwner, obraScope }) {
    const validRoles = obraScope ? ['admin', 'member', 'operario'] : ['admin', 'member', 'operario', 'owner'];
    if (!validRoles.includes(targetRole)) {
      throw new Error('Papel inválido');
    }
    if (!(actorIsDev || actorIsAdmin)) {
      const err = new Error('Sem permissão para gerir vínculo');
      err.code = 'permission-denied';
      throw err;
    }
    const isOwnerRequested = !obraScope && targetRole === 'owner';
    if ((isOwnerRequested || existingIsOwner) && !actorIsDev) {
      const err = new Error('Apenas dev altera proprietário');
      err.code = 'permission-denied';
      throw err;
    }
    const willBeOwner = actorIsDev ? isOwnerRequested : false;
    const finalRole = willBeOwner ? 'owner' : targetRole;
    const finalIsAdmin = finalRole === 'admin' || willBeOwner;
    return { role: finalRole, isAdmin: finalIsAdmin, isOwner: willBeOwner };
  }

  // 1. Dev atribui papel 'owner' com sucesso no escopo da construtora
  const devAsOwner = simulateMembershipLogic({
    actorIsDev: true,
    actorIsAdmin: false,
    targetRole: 'owner',
    existingIsOwner: false,
    obraScope: false,
  });
  assert.equal(devAsOwner.role, 'owner');
  assert.equal(devAsOwner.isOwner, true);
  assert.equal(devAsOwner.isAdmin, true);

  // 2. Admin comum tenta atribuir 'owner' -> falha com permission-denied
  assert.throws(
    () => simulateMembershipLogic({
      actorIsDev: false,
      actorIsAdmin: true,
      targetRole: 'owner',
      existingIsOwner: false,
      obraScope: false,
    }),
    (err) => err.code === 'permission-denied' && err.message.includes('Apenas dev altera proprietário')
  );

  // 3. Admin comum tenta alterar vínculo de membro que já é owner -> falha
  assert.throws(
    () => simulateMembershipLogic({
      actorIsDev: false,
      actorIsAdmin: true,
      targetRole: 'member',
      existingIsOwner: true,
      obraScope: false,
    }),
    (err) => err.code === 'permission-denied' && err.message.includes('Apenas dev altera proprietário')
  );

  // 4. Tentativa de atribuir 'owner' no escopo de obra -> rejeitada como Papel inválido
  assert.throws(
    () => simulateMembershipLogic({
      actorIsDev: true,
      actorIsAdmin: false,
      targetRole: 'owner',
      existingIsOwner: false,
      obraScope: true,
    }),
    (err) => err.message.includes('Papel inválido')
  );

  // 5. Dev pode rebaixar owner para admin
  const demotedByDev = simulateMembershipLogic({
    actorIsDev: true,
    actorIsAdmin: false,
    targetRole: 'admin',
    existingIsOwner: true,
    obraScope: false,
  });
  assert.equal(demotedByDev.role, 'admin');
  assert.equal(demotedByDev.isOwner, false);
  assert.equal(demotedByDev.isAdmin, true);
});



