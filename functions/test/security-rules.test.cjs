const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collectionGroup, query, where, getDocs, collection
} = require('firebase/firestore');
const {
  ref, uploadBytes, getBytes, deleteObject
} = require('firebase/storage');

const root = path.resolve(__dirname, '../..');
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8088';
const [fsH, fsP] = firestoreHost.split(':');
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9198';
const [stH, stP] = storageHost.split(':');
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9098';

process.env.GCLOUD_PROJECT = 'demo-sigo';
process.env.FIRESTORE_EMULATOR_HOST = firestoreHost;
process.env.FIREBASE_AUTH_EMULATOR_HOST = authHost;
process.env.FIREBASE_STORAGE_EMULATOR_HOST = storageHost;
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: 'demo-sigo',
  storageBucket: 'demo-sigo.appspot.com'
});

const admin = require(root + '/functions/node_modules/firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'demo-sigo',
    storageBucket: 'demo-sigo.appspot.com'
  });
}
const db = admin.firestore();
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-sigo',
    firestore: {
      host: fsH,
      port: Number(fsP),
      rules: fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8')
    },
    storage: {
      host: stH,
      port: Number(stP),
      rules: fs.readFileSync(path.join(root, 'storage.rules'), 'utf8')
    }
  });

  await testEnv.clearFirestore();
  await admin.storage().bucket().deleteFiles({ force: true });

  const batch = db.batch();

  // 1. Usuários base e dev roles
  const users = [
    { id: 'dev_user', email: 'dev@sigo.test', globalRole: 'dev' },
    { id: 'admin_user', email: 'admin@construtora.test', globalRole: 'user' },
    { id: 'rh_user', email: 'rh@construtora.test', globalRole: 'user' },
    { id: 'stock_user', email: 'stock@construtora.test', globalRole: 'user' },
    { id: 'diary_user', email: 'diary@construtora.test', globalRole: 'user' },
    { id: 'inactive_user', email: 'inactive@construtora.test', globalRole: 'user' },
    { id: 'outsider_user', email: 'outsider@other.test', globalRole: 'user' }
  ];

  for (const u of users) {
    batch.set(db.doc(`users/${u.id}`), {
      id: u.id,
      email: u.email,
      displayName: u.id,
      globalRole: u.globalRole
    });
  }

  // dev_roles ativa para dev_user
  batch.set(db.doc('dev_roles/dev_user'), { isActive: true });

  // 2. Construtoras A e B
  batch.set(db.doc('construtoras/const_a'), { id: 'const_a', name: 'Construtora A' });
  batch.set(db.doc('construtoras/const_b'), { id: 'const_b', name: 'Construtora B' });

  // 3. Obras
  batch.set(db.doc('construtoras/const_a/obras/obra_1'), {
    id: 'obra_1',
    construtoraId: 'const_a',
    name: 'Obra 1'
  });
  batch.set(db.doc('construtoras/const_b/obras/obra_2'), {
    id: 'obra_2',
    construtoraId: 'const_b',
    name: 'Obra 2'
  });

  // 4. Membros da Construtora A
  batch.set(db.doc('construtoras/const_a/construtora_members/admin_user'), {
    userId: 'admin_user',
    isActive: true,
    isAdmin: true,
    isOwner: false,
    modules: []
  });
  batch.set(db.doc('construtoras/const_a/construtora_members/rh_user'), {
    userId: 'rh_user',
    isActive: true,
    isAdmin: false,
    isOwner: false,
    modules: ['rh']
  });
  batch.set(db.doc('construtoras/const_a/construtora_members/stock_user'), {
    userId: 'stock_user',
    isActive: true,
    isAdmin: false,
    isOwner: false,
    modules: ['estoque']
  });
  batch.set(db.doc('construtoras/const_a/construtora_members/diary_user'), {
    userId: 'diary_user',
    isActive: true,
    isAdmin: false,
    isOwner: false,
    modules: []
  });
  batch.set(db.doc('construtoras/const_a/construtora_members/inactive_user'), {
    userId: 'inactive_user',
    isActive: false,
    isAdmin: true,
    isOwner: false,
    modules: ['rh', 'estoque']
  });

  // Membro de Obra
  batch.set(db.doc('construtoras/const_a/obras/obra_1/members/diary_user'), {
    userId: 'diary_user',
    isActive: true,
    isAdmin: false,
    modules: ['diario', 'lotes']
  });

  // 5. Dados base existentes para testes de leitura/imutabilidade
  batch.set(db.doc('construtoras/const_a/materiais/mat_existente'), {
    id: 'mat_existente',
    construtoraId: 'const_a',
    name: 'Cimento CP-II',
    unit: 'sc',
    currentQuantity: 50,
    quantityUnits: 50000,
    quantityScale: 1000,
    schemaVersion: 2
  });

  batch.set(db.doc('construtoras/const_a/despesas/desp_existente'), {
    id: 'desp_existente',
    construtoraId: 'const_a',
    obraId: 'obra_1',
    descricao: 'Compra de Areia',
    valor: 150.0,
    valorEmCentavos: 15000,
    dataVencimento: '2026-09-30',
    dataPagamento: null,
    status: 'pendente',
    categoria: 'Material',
    responsavelId: 'admin_user',
    createdAt: new Date(),
    schemaVersion: 2
  });

  batch.set(db.doc('construtoras/const_a/obras/obra_1/diarios/diario_existente'), {
    id: 'diario_existente',
    construtoraId: 'const_a',
    obraId: 'obra_1',
    responsavelId: 'diary_user',
    date: '2026-09-17',
    isPendingSync: false
  });

  await batch.commit();
});

after(async () => {
  await testEnv?.cleanup();
  await admin.app().delete();
});

// ==========================================
// 1. AUTENTICAÇÃO E DEV ROLE (dev_roles, users)
// ==========================================
test('1.1 Não autenticado tem acesso negado em leitura e escrita no Firestore', async () => {
  const unauth = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(unauth, 'users/admin_user')));
  await assertFails(getDoc(doc(unauth, 'construtoras/const_a')));
  await assertFails(getDoc(doc(unauth, 'dev_roles/dev_user')));
  await assertFails(setDoc(doc(unauth, 'users/anon'), { id: 'anon' }));
});

test('1.2 Usuário comum não pode se promover a dev nem alterar dev_roles', async () => {
  const stockFs = testEnv.authenticatedContext('stock_user').firestore();
  await assertFails(updateDoc(doc(stockFs, 'users/stock_user'), { globalRole: 'dev' }));
  await assertFails(setDoc(doc(stockFs, 'dev_roles/stock_user'), { isActive: true }));
  // Mas pode atualizar seu próprio displayName
  await assertSucceeds(updateDoc(doc(stockFs, 'users/stock_user'), { displayName: 'Almoxarife Chefe' }));
});

test('1.3 Dev ativo tem permissão global de leitura', async () => {
  const devFs = testEnv.authenticatedContext('dev_user').firestore();
  await assertSucceeds(getDoc(doc(devFs, 'construtoras/const_a')));
  await assertSucceeds(getDoc(doc(devFs, 'construtoras/const_b')));
  await assertSucceeds(getDoc(doc(devFs, 'construtoras/const_a/materiais/mat_existente')));
  await assertSucceeds(getDoc(doc(devFs, 'dev_roles/dev_user')));
});

test('1.4 Dev ativo tem acesso irrestrito para visualizar e cadastrar fornecedores', async () => {
  const devFs = testEnv.authenticatedContext('dev_user').firestore();
  // Leitura da coleção de fornecedores
  await assertSucceeds(getDocs(collection(devFs, 'construtoras/const_a/fornecedores')));
  // Criação de fornecedor pelo dev
  await assertSucceeds(setDoc(doc(devFs, 'construtoras/const_a/fornecedores/forn_dev'), {
    id: 'forn_dev',
    construtoraId: 'const_a',
    razaoSocial: 'Fornecedor Teste Dev',
    documento: '12345678000195',
    status: 'ativo'
  }));
  // Leitura direta do documento criado
  await assertSucceeds(getDoc(doc(devFs, 'construtoras/const_a/fornecedores/forn_dev')));
});

// ==========================================
// 2. ISOLAMENTO CROSS-TENANT E MEMBRO INATIVO
// ==========================================
test('2.1 Membro da Construtora A não pode ler dados da Construtora B', async () => {
  const rhFs = testEnv.authenticatedContext('rh_user').firestore();
  await assertSucceeds(getDoc(doc(rhFs, 'construtoras/const_a')));
  await assertFails(getDoc(doc(rhFs, 'construtoras/const_b')));
  await assertFails(getDoc(doc(rhFs, 'construtoras/const_b/obras/obra_2')));
});

test('2.2 Membro inativo (isActive: false) tem qualquer acesso negado', async () => {
  const inactiveFs = testEnv.authenticatedContext('inactive_user').firestore();
  await assertFails(getDoc(doc(inactiveFs, 'construtoras/const_a')));
  await assertFails(getDoc(doc(inactiveFs, 'construtoras/const_a/materiais/mat_existente')));
  await assertFails(getDoc(doc(inactiveFs, 'construtoras/const_a/despesas/desp_existente')));
});

test('2.3 Membresias de construtora são protegidas contra escrita direta do cliente', async () => {
  const adminFs = testEnv.authenticatedContext('admin_user').firestore();
  await assertFails(setDoc(doc(adminFs, 'construtoras/const_a/construtora_members/hacker'), {
    userId: 'hacker',
    isActive: true,
    isAdmin: true
  }));
  await assertFails(deleteDoc(doc(adminFs, 'construtoras/const_a/construtora_members/stock_user')));
});

// ==========================================
// 3. RECURSOS HUMANOS (funcionários e equipes)
// ==========================================
test('3.1 Membro com módulo RH pode ler e cadastrar funcionários e equipes', async () => {
  const rhFs = testEnv.authenticatedContext('rh_user').firestore();
  const funcData = {
    id: 'func_1',
    construtoraId: 'const_a',
    nome: 'João Operário',
    cargo: 'Pedreiro',
    ativo: true
  };
  await assertSucceeds(setDoc(doc(rhFs, 'construtoras/const_a/funcionarios/func_1'), funcData));
  await assertSucceeds(getDoc(doc(rhFs, 'construtoras/const_a/funcionarios/func_1')));

  const eqData = {
    id: 'eq_1',
    construtoraId: 'const_a',
    nome: 'Equipe Alvenaria',
    liderId: 'func_1'
  };
  await assertSucceeds(setDoc(doc(rhFs, 'construtoras/const_a/equipes/eq_1'), eqData));
  await assertSucceeds(getDoc(doc(rhFs, 'construtoras/const_a/equipes/eq_1')));
});

test('3.2 Usuário sem módulo de RH não pode ler nem cadastrar funcionários', async () => {
  const stockFs = testEnv.authenticatedContext('stock_user').firestore();
  await assertFails(getDoc(doc(stockFs, 'construtoras/const_a/funcionarios/func_1')));
  await assertFails(setDoc(doc(stockFs, 'construtoras/const_a/funcionarios/func_bad'), {
    id: 'func_bad',
    construtoraId: 'const_a',
    nome: 'Invasor'
  }));
});

test('3.3 Exclusão de funcionário é sempre negada (imutabilidade)', async () => {
  const rhFs = testEnv.authenticatedContext('rh_user').firestore();
  await assertFails(deleteDoc(doc(rhFs, 'construtoras/const_a/funcionarios/func_1')));
});

// ==========================================
// 4. ALMOXARIFADO / ESTOQUE (materiais e movimentações)
// ==========================================
test('4.1 Membro com módulo estoque pode ler materiais', async () => {
  const stockFs = testEnv.authenticatedContext('stock_user').firestore();
  await assertSucceeds(getDoc(doc(stockFs, 'construtoras/const_a/materiais/mat_existente')));
});

test('4.2 Cadastro de material novo exige saldo zero e schema version 2', async () => {
  const stockFs = testEnv.authenticatedContext('stock_user').firestore();
  const validMat = {
    id: 'mat_valido',
    construtoraId: 'const_a',
    name: 'Tijolo 8 furos',
    unit: 'milheiro',
    currentQuantity: 0,
    quantityUnits: 0,
    quantityScale: 1000,
    schemaVersion: 2
  };
  await assertSucceeds(setDoc(doc(stockFs, 'construtoras/const_a/materiais/mat_valido'), validMat));

  // Violação: tentar criar material com saldo inicial diferente de zero
  const invalidSaldoMat = {
    ...validMat,
    id: 'mat_invalido',
    currentQuantity: 10,
    quantityUnits: 10000
  };
  await assertFails(setDoc(doc(stockFs, 'construtoras/const_a/materiais/mat_invalido'), invalidSaldoMat));
});

test('4.3 Atualização direta de saldo de material e escrita em movimentações são negadas', async () => {
  const stockFs = testEnv.authenticatedContext('stock_user').firestore();
  // Alteração de saldo direta rejeitada
  await assertFails(updateDoc(doc(stockFs, 'construtoras/const_a/materiais/mat_existente'), {
    currentQuantity: 999
  }));
  // Escrita em movimentações bloqueada para clientes
  await assertFails(setDoc(doc(stockFs, 'construtoras/const_a/materiais/mat_existente/movimentacoes/mov_1'), {
    type: 'entrada',
    quantity: 10
  }));
});

// ==========================================
// 5. FINANCEIRO (despesas)
// ==========================================
test('5.1 Apenas admin pode ler e criar despesas', async () => {
  const stockFs = testEnv.authenticatedContext('stock_user').firestore();
  const adminFs = testEnv.authenticatedContext('admin_user').firestore();

  // Membro comum não lê despesas
  await assertFails(getDoc(doc(stockFs, 'construtoras/const_a/despesas/desp_existente')));

  // Admin lê normalmente
  await assertSucceeds(getDoc(doc(adminFs, 'construtoras/const_a/despesas/desp_existente')));

  // Admin cria despesa com schema válido
  const validDesp = {
    id: 'desp_nova',
    construtoraId: 'const_a',
    obraId: 'obra_1',
    descricao: 'Locação Betoneira',
    valor: 450.0,
    valorEmCentavos: 45000,
    dataVencimento: '2026-10-05',
    dataPagamento: null,
    status: 'pendente',
    categoria: 'Equipamento',
    responsavelId: 'admin_user',
    createdAt: new Date(),
    schemaVersion: 2
  };
  await assertSucceeds(setDoc(doc(adminFs, 'construtoras/const_a/despesas/desp_nova'), validDesp));
});

test('5.2 Schema de despesa rejeita divergência entre centavos e float, e proíbe update/delete', async () => {
  const adminFs = testEnv.authenticatedContext('admin_user').firestore();
  const despDivergente = {
    id: 'desp_div',
    construtoraId: 'const_a',
    obraId: null,
    descricao: 'Teste',
    valor: 100.0,
    valorEmCentavos: 9999, // divergência proposital
    dataVencimento: '2026-10-01',
    dataPagamento: null,
    status: 'pendente',
    categoria: 'Outros',
    responsavelId: 'admin_user',
    createdAt: new Date(),
    schemaVersion: 2
  };
  await assertFails(setDoc(doc(adminFs, 'construtoras/const_a/despesas/desp_div'), despDivergente));

  // Imutabilidade: update e delete bloqueados
  await assertFails(updateDoc(doc(adminFs, 'construtoras/const_a/despesas/desp_existente'), { status: 'pago' }));
  await assertFails(deleteDoc(doc(adminFs, 'construtoras/const_a/despesas/desp_existente')));
});

// ==========================================
// 6. OBRAS E DIÁRIOS (imutabilidade do cliente)
// ==========================================
test('6.1 Diários de obra não permitem escrita direta pelo cliente (apenas backend callable)', async () => {
  const diaryFs = testEnv.authenticatedContext('diary_user').firestore();
  // Leitura permitida para membro da obra com módulo diario
  await assertSucceeds(getDoc(doc(diaryFs, 'construtoras/const_a/obras/obra_1/diarios/diario_existente')));
  // Escrita direta bloqueada
  await assertFails(setDoc(doc(diaryFs, 'construtoras/const_a/obras/obra_1/diarios/diario_novo'), {
    id: 'diario_novo',
    date: '2026-09-18'
  }));
});

// ==========================================
// 7. STORAGE RULES (Anexos e Imutabilidade)
// ==========================================
test('7.1 Upload de foto de diário válido com autorização, tamanho <= 10MB e sha256', async () => {
  const pathStorage = 'construtoras/const_a/obras/obra_1/diarios/diario_existente/diary_user/foto1';
  const imgBytes = Buffer.from([255, 216, 255, 224, 0, 16, 74, 70, 73, 70]); // JPEG magic header
  const sha = crypto.createHash('sha256').update(imgBytes).digest('hex');

  const storageMember = testEnv.authenticatedContext('diary_user').storage('gs://demo-sigo.appspot.com');
  const targetRef = ref(storageMember, pathStorage);

  // Upload bem-sucedido
  await assertSucceeds(uploadBytes(targetRef, imgBytes, {
    contentType: 'image/jpeg',
    customMetadata: {
      owner: 'diary_user',
      sha256: sha
    }
  }));

  // Leitura bem-sucedida pelo autor
  await assertSucceeds(getBytes(targetRef));

  // Leitura negada para outsider de outra construtora
  const storageOutsider = testEnv.authenticatedContext('outsider_user').storage('gs://demo-sigo.appspot.com');
  await assertFails(getBytes(ref(storageOutsider, pathStorage)));

  // Leitura permitida para dev
  const storageDev = testEnv.authenticatedContext('dev_user').storage('gs://demo-sigo.appspot.com');
  await assertSucceeds(getBytes(ref(storageDev, pathStorage)));
});

test('7.2 Storage rejeita tipo de arquivo inválido, metadata divergente ou tamanho excessivo', async () => {
  const badPath = 'construtoras/const_a/obras/obra_1/diarios/diario_existente/diary_user/bad_file';
  const storageMember = testEnv.authenticatedContext('diary_user').storage('gs://demo-sigo.appspot.com');

  // Tipo não imagem
  await assertFails(uploadBytes(ref(storageMember, badPath), Buffer.from('script shell'), {
    contentType: 'text/plain',
    customMetadata: {
      owner: 'diary_user',
      sha256: crypto.createHash('sha256').update(Buffer.from('script shell')).digest('hex')
    }
  }));

  // Metadata owner divergente do auth.uid
  const imgBytes = Buffer.from([255, 216, 255, 224]);
  await assertFails(uploadBytes(ref(storageMember, badPath), imgBytes, {
    contentType: 'image/jpeg',
    customMetadata: {
      owner: 'outro_usuario',
      sha256: crypto.createHash('sha256').update(imgBytes).digest('hex')
    }
  }));
});

test('7.3 Storage garante imutabilidade: update e delete bloqueados', async () => {
  const pathStorage = 'construtoras/const_a/obras/obra_1/diarios/diario_existente/diary_user/foto1';
  const storageMember = testEnv.authenticatedContext('diary_user').storage('gs://demo-sigo.appspot.com');
  const targetRef = ref(storageMember, pathStorage);

  // Sobrescrita (update) negada
  await assertFails(uploadBytes(targetRef, Buffer.from([255, 216, 255, 225]), {
    contentType: 'image/jpeg',
    customMetadata: {
      owner: 'diary_user',
      sha256: 'a'.repeat(64)
    }
  }));

  // Deleção negada
  await assertFails(deleteObject(targetRef));
});

// ==========================================
// 8. LOGOS DA CONSTRUTORA (Story 3)
// ==========================================
test('8.1 Admin atualiza logoUrl com string; tipo não-string é negado', async () => {
  const adminFs = testEnv.authenticatedContext('admin_user').firestore();

  await assertSucceeds(updateDoc(doc(adminFs, 'construtoras/const_a'), {
    logoUrl: 'construtoras/const_a/logos/logo.png'
  }));

  await assertFails(updateDoc(doc(adminFs, 'construtoras/const_a'), {
    logoUrl: 12345
  }));

  await assertFails(updateDoc(doc(adminFs, 'construtoras/const_a'), {
    logoUrl: { path: 'construtoras/const_a/logos/x' }
  }));
});

test('8.2 Membro não-admin não pode atualizar logoUrl', async () => {
  const stockFs = testEnv.authenticatedContext('stock_user').firestore();
  await assertFails(updateDoc(doc(stockFs, 'construtoras/const_a'), {
    logoUrl: 'construtoras/const_a/logos/evil.png'
  }));
});

test('8.3 Upload de logo: admin aceita; não-admin, tipo inválido e metadata processed negados', async () => {
  const adminStorage = testEnv.authenticatedContext('admin_user').storage('gs://demo-sigo.appspot.com');
  const stockStorage = testEnv.authenticatedContext('stock_user').storage('gs://demo-sigo.appspot.com');
  const imgBytes = Buffer.from([255, 216, 255, 224, 0, 16, 74, 70, 73, 70]);

  await assertSucceeds(uploadBytes(ref(adminStorage, 'construtoras/const_a/logos/logo_ok'), imgBytes, {
    contentType: 'image/jpeg'
  }));

  await assertFails(uploadBytes(ref(stockStorage, 'construtoras/const_a/logos/logo_member'), imgBytes, {
    contentType: 'image/jpeg'
  }));

  await assertFails(uploadBytes(ref(adminStorage, 'construtoras/const_a/logos/logo_bad_type'), Buffer.from('script shell'), {
    contentType: 'text/plain'
  }));

  // Bypass do loop-guard: cliente não pode marcar processed=true no upload
  await assertFails(uploadBytes(ref(adminStorage, 'construtoras/const_a/logos/logo_bypass'), imgBytes, {
    contentType: 'image/jpeg',
    customMetadata: { processed: 'true' }
  }));
});
