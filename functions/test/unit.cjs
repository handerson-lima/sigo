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

