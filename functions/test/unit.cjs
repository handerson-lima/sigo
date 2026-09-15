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
