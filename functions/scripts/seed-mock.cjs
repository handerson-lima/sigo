#!/usr/bin/env node
/**
 * SIGO — Seed Mock para Ambiente de Desenvolvimento / Emuladores
 *
 * Popula 2 construtoras completas com isolamento multi-tenant:
 * - Usuários (Dev, Admin, Engenheiro) no Firebase Auth e Firestore
 * - Construtoras e seus membros com papéis e módulos
 * - Obras, membros de obra e lotes
 * - Materiais de estoque com quantidades em escala e movimentações
 * - Despesas financeiras com centavos, datas civil e pagamentos
 * - Diários de obra com efetivo e anotações
 *
 * Execução:
 *   node functions/scripts/seed-mock.cjs
 */

const admin = require('firebase-admin');

const path = require('path');
const isCloud = process.argv.includes('--cloud') || process.env.TARGET === 'cloud';

if (isCloud) {
  delete process.env.FIRESTORE_EMULATOR_HOST;
  delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
  delete process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../serviceAccountKey.json');
  console.log(`☁️ [SEED] Modo CLOUD ativado. Utilizando credencial: ${keyPath}`);
  const serviceAccount = require(keyPath);
  
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id,
      storageBucket: `${serviceAccount.project_id}.appspot.com`,
    });
  }
} else {
  // Configurações padrão para emuladores locais
  process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-sigo';
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';

  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT,
      storageBucket: `${process.env.GCLOUD_PROJECT}.appspot.com`,
    });
  }
}

const db = admin.firestore();
const auth = admin.auth();

const now = admin.firestore.Timestamp.now();
const daysAgo = (days) => admin.firestore.Timestamp.fromMillis(Date.now() - days * 86400000);

const dateStr = (d) => d.toISOString().split('T')[0];

async function ensureUser(uid, email, password, displayName) {
  try {
    await auth.getUser(uid);
    await auth.updateUser(uid, { email, password, displayName });
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      await auth.createUser({ uid, email, password, displayName });
    } else {
      throw err;
    }
  }
}

async function seed() {
  console.log('🌱 [SEED] Iniciando seed de dados mock para 2 construtoras no emulador...');
  console.log(`   Projeto: ${process.env.GCLOUD_PROJECT}`);
  console.log(`   Firestore: ${process.env.FIRESTORE_EMULATOR_HOST}`);
  console.log(`   Auth: ${process.env.FIREBASE_AUTH_EMULATOR_HOST}`);

  // 1. USUÁRIOS
  const users = [
    {
      uid: 'usr-dev-global',
      email: 'dev@sigo.test',
      password: 'password123',
      displayName: 'Carlos Silva (Dev Global)',
      globalRole: 'dev',
    },
    // Construtora Alfa
    {
      uid: 'usr-admin-alfa',
      email: 'admin.alfa@sigo.test',
      password: 'password123',
      displayName: 'Roberto Dias (Admin Alfa)',
      globalRole: 'user',
    },
    {
      uid: 'usr-eng-alfa',
      email: 'eng.alfa@sigo.test',
      password: 'password123',
      displayName: 'Juliana Lima (Eng. Alfa)',
      globalRole: 'user',
    },
    // Construtora Beta
    {
      uid: 'usr-admin-beta',
      email: 'admin.beta@sigo.test',
      password: 'password123',
      displayName: 'Marcos Souza (Admin Beta)',
      globalRole: 'user',
    },
    {
      uid: 'usr-eng-beta',
      email: 'eng.beta@sigo.test',
      password: 'password123',
      displayName: 'Fernanda Rocha (Eng. Beta)',
      globalRole: 'user',
    },
  ];

  console.log('👤 Provisionando usuários no Firebase Auth e Firestore...');
  for (const u of users) {
    await ensureUser(u.uid, u.email, u.password, u.displayName);
    await db.doc(`users/${u.uid}`).set({
      id: u.uid,
      email: u.email,
      displayName: u.displayName,
      globalRole: u.globalRole,
      createdAt: daysAgo(30),
      updatedAt: now,
    });
  }

  // Dev Global Role (C1 Authority)
  await db.doc('dev_roles/usr-dev-global').set({
    isActive: true,
    verifiedBy: 'system-seed',
    updatedAt: now,
  });

  // 2. CONSTRUTORA 1: ALFA ENGENHARIA
  console.log('🏢 Criando Construtora Alfa e seus recursos...');
  const cAlfaId = 'alfa';
  await db.doc(`construtoras/${cAlfaId}`).set({
    id: cAlfaId,
    name: 'Alfa Engenharia e Construções',
    cnpj: '12.345.678/0001-90',
    createdAt: daysAgo(60).toDate().toISOString(),
    isActive: true,
  });

  // Membros Construtora Alfa
  await db.doc(`construtoras/${cAlfaId}/construtora_members/usr-admin-alfa`).set({
    userId: 'usr-admin-alfa',
    email: 'admin.alfa@sigo.test',
    displayName: 'Roberto Dias (Admin Alfa)',
    role: 'admin',
    isAdmin: true,
    isOwner: true,
    isActive: true,
    modules: ['estoque'],
    joinedAt: daysAgo(60),
    updatedAt: now,
  });

  await db.doc(`construtoras/${cAlfaId}/construtora_members/usr-eng-alfa`).set({
    userId: 'usr-eng-alfa',
    email: 'eng.alfa@sigo.test',
    displayName: 'Juliana Lima (Eng. Alfa)',
    role: 'member',
    isAdmin: false,
    isOwner: false,
    isActive: true,
    modules: ['estoque'],
    joinedAt: daysAgo(45),
    updatedAt: now,
  });

  // Obras Alfa
  // Obra 1: Residencial Horizonte
  const oAlfa1Id = 'obra-alfa-horizonte';
  await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa1Id}`).set({
    id: oAlfa1Id,
    construtoraId: cAlfaId,
    name: 'Residencial Horizonte',
    description: 'Edifício residencial de 12 pavimentos com 48 apartamentos.',
    createdAt: daysAgo(40).toDate().toISOString(),
    isActive: true,
  });

  await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa1Id}/members/usr-admin-alfa`).set({
    userId: 'usr-admin-alfa',
    isAdmin: true,
    isActive: true,
    modules: ['diario', 'lotes', 'estoque'],
    joinedAt: daysAgo(40).toDate().toISOString(),
  });

  await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa1Id}/members/usr-eng-alfa`).set({
    userId: 'usr-eng-alfa',
    isAdmin: false,
    isActive: true,
    modules: ['diario', 'lotes', 'estoque'],
    joinedAt: daysAgo(40).toDate().toISOString(),
  });

  // Lotes Obra 1
  const lotesAlfa1 = [
    { id: 'lote-alfa-h1', name: 'Torre A - Estrutura e Lajes', phase: 'Estrutura', status: 'noPrazo' },
    { id: 'lote-alfa-h2', name: 'Torre B - Fundação e Pilares', phase: 'Fundação', status: 'noPrazo' },
    { id: 'lote-alfa-h3', name: 'Área de Lazer e Piscina', phase: 'Alvenaria', status: 'atrasado' },
  ];
  for (const l of lotesAlfa1) {
    await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa1Id}/lotes/${l.id}`).set({
      id: l.id,
      construtoraId: cAlfaId,
      obraId: oAlfa1Id,
      name: l.name,
      phase: l.phase,
      status: l.status,
      responsavelId: 'usr-eng-alfa',
      createdAt: daysAgo(35).toDate().toISOString(),
    });
  }

  // Diários Obra 1
  await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa1Id}/diarios/diario-alfa-01`).set({
    id: 'diario-alfa-01',
    construtoraId: cAlfaId,
    obraId: oAlfa1Id,
    date: daysAgo(1).toDate().toISOString(),
    weather: 'sol',
    efetivo: [
      { role: 'Pedreiro', count: 8 },
      { role: 'Servente', count: 12 },
      { role: 'Armador', count: 4 },
      { role: 'Encarregado', count: 1 },
    ],
    observacoes: 'Concretagem da laje do 5º pavimento concluída às 16h30 sem intercorrências. Cura úmida iniciada.',
    photoUrls: [],
    localPhotoPaths: [],
    isPendingSync: false,
    responsavelId: 'usr-eng-alfa',
    createdAt: daysAgo(1).toDate().toISOString(),
  });

  // Obra 2: Condomínio Aurora
  const oAlfa2Id = 'obra-alfa-aurora';
  await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa2Id}`).set({
    id: oAlfa2Id,
    construtoraId: cAlfaId,
    name: 'Condomínio Fechado Aurora',
    description: 'Condomínio horizontal com 24 casas e clube social.',
    createdAt: daysAgo(20).toDate().toISOString(),
    isActive: true,
  });

  await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa2Id}/members/usr-admin-alfa`).set({
    userId: 'usr-admin-alfa',
    isAdmin: true,
    isActive: true,
    modules: ['diario', 'lotes', 'estoque'],
    joinedAt: daysAgo(20).toDate().toISOString(),
  });

  await db.doc(`construtoras/${cAlfaId}/obras/${oAlfa2Id}/members/usr-eng-alfa`).set({
    userId: 'usr-eng-alfa',
    isAdmin: false,
    isActive: true,
    modules: ['diario', 'lotes'],
    joinedAt: daysAgo(20).toDate().toISOString(),
  });

  // Materiais Estoque Alfa (C4: quantityUnits com escala 1000)
  const materiaisAlfa = [
    {
      id: 'mat-alfa-cimento',
      name: 'Cimento Portland CP-II 50kg',
      unit: 'Saco',
      quantityUnits: 350000, // 350 sacos
      currentQuantity: 350.0,
    },
    {
      id: 'mat-alfa-areia',
      name: 'Areia Média Lavada',
      unit: 'm³',
      quantityUnits: 48500, // 48.5 m³
      currentQuantity: 48.5,
    },
    {
      id: 'mat-alfa-aco',
      name: 'Aço CA-50 10mm',
      unit: 'Barra 12m',
      quantityUnits: 140000, // 140 barras
      currentQuantity: 140.0,
    },
    {
      id: 'mat-alfa-tinta',
      name: 'Tinta Acrílica Fosca Premium',
      unit: 'Lata 18L',
      quantityUnits: 25000, // 25 latas
      currentQuantity: 25.0,
    },
  ];

  for (const m of materiaisAlfa) {
    const matRef = db.doc(`construtoras/${cAlfaId}/materiais/${m.id}`);
    await matRef.set({
      id: m.id,
      construtoraId: cAlfaId,
      name: m.name,
      unit: m.unit,
      quantityUnits: m.quantityUnits,
      quantityScale: 1000,
      currentQuantity: m.currentQuantity,
      schemaVersion: 2,
    });

    // Movimentação inicial de abertura
    await matRef.collection('movimentacoes').doc('abertura-inicial').set({
      id: 'abertura-inicial',
      materialId: m.id,
      type: 'entrada',
      commandType: 'abertura',
      quantity: m.currentQuantity,
      quantityUnits: m.quantityUnits,
      deltaUnits: m.quantityUnits,
      quantityScale: 1000,
      date: daysAgo(30),
      responsavelId: 'usr-admin-alfa',
      observacao: 'Abertura de saldo inicial auditado C4',
    });
  }

  // Despesas Financeiras Alfa (C3: valorEmCentavos)
  const despesasAlfa = [
    {
      id: 'desp-alfa-01',
      descricao: 'Aquisição de 300 sacos de cimento Votoran',
      valorEmCentavos: 1050000, // R$ 10.500,00
      categoria: 'Materiais',
      status: 'pago',
      dataVencimento: dateStr(new Date(Date.now() - 15 * 86400000)),
      dataPagamento: daysAgo(15),
      responsavelId: 'usr-admin-alfa',
      obraId: oAlfa1Id,
    },
    {
      id: 'desp-alfa-02',
      descricao: 'Locação de Grua e Andaimes Fachadeiros',
      valorEmCentavos: 480000, // R$ 4.800,00
      categoria: 'Equipamentos',
      status: 'pago',
      dataVencimento: dateStr(new Date(Date.now() - 5 * 86400000)),
      dataPagamento: daysAgo(5),
      responsavelId: 'usr-admin-alfa',
      obraId: oAlfa1Id,
    },
    {
      id: 'desp-alfa-03',
      descricao: 'Empreiteira de Estrutura e Formas - Medição 03',
      valorEmCentavos: 2850000, // R$ 28.500,00
      categoria: 'Mão de Obra',
      status: 'pendente',
      dataVencimento: dateStr(new Date(Date.now() + 10 * 86400000)),
      dataPagamento: null,
      responsavelId: 'usr-admin-alfa',
      obraId: oAlfa1Id,
    },
    {
      id: 'desp-alfa-04',
      descricao: 'Fornecimento de Caçambas para Bota-Fora',
      valorEmCentavos: 125000, // R$ 1.250,00
      categoria: 'Serviços',
      status: 'pendente',
      dataVencimento: dateStr(new Date(Date.now() + 15 * 86400000)),
      dataPagamento: null,
      responsavelId: 'usr-admin-alfa',
      obraId: oAlfa2Id,
    },
  ];

  for (const d of despesasAlfa) {
    await db.doc(`construtoras/${cAlfaId}/despesas/${d.id}`).set({
      id: d.id,
      construtoraId: cAlfaId,
      obraId: d.obraId,
      descricao: d.descricao,
      valor: d.valorEmCentavos / 100,
      valorEmCentavos: d.valorEmCentavos,
      categoria: d.categoria,
      status: d.status,
      dataVencimento: d.dataVencimento,
      dataPagamento: d.dataPagamento,
      responsavelId: d.responsavelId,
      schemaVersion: 2,
      createdAt: daysAgo(20),
    });
  }

  // 3. CONSTRUTORA 2: BETA EMPREENDIMENTOS
  console.log('🏢 Criando Construtora Beta e seus recursos...');
  const cBetaId = 'beta';
  await db.doc(`construtoras/${cBetaId}`).set({
    id: cBetaId,
    name: 'Beta Empreendimentos Imobiliários',
    cnpj: '98.765.432/0001-10',
    createdAt: daysAgo(50).toDate().toISOString(),
    isActive: true,
  });

  // Membros Construtora Beta
  await db.doc(`construtoras/${cBetaId}/construtora_members/usr-admin-beta`).set({
    userId: 'usr-admin-beta',
    email: 'admin.beta@sigo.test',
    displayName: 'Marcos Souza (Admin Beta)',
    role: 'admin',
    isAdmin: true,
    isOwner: true,
    isActive: true,
    modules: ['estoque'],
    joinedAt: daysAgo(50),
    updatedAt: now,
  });

  await db.doc(`construtoras/${cBetaId}/construtora_members/usr-eng-beta`).set({
    userId: 'usr-eng-beta',
    email: 'eng.beta@sigo.test',
    displayName: 'Fernanda Rocha (Eng. Beta)',
    role: 'member',
    isAdmin: false,
    isOwner: false,
    isActive: true,
    modules: ['estoque'],
    joinedAt: daysAgo(30),
    updatedAt: now,
  });

  // Obras Beta
  const oBeta1Id = 'obra-beta-solar';
  await db.doc(`construtoras/${cBetaId}/obras/${oBeta1Id}`).set({
    id: oBeta1Id,
    construtoraId: cBetaId,
    name: 'Complexo Parque Solar',
    description: 'Usina fotovoltaica de 5MW com subestação e cerca perimetral.',
    createdAt: daysAgo(30).toDate().toISOString(),
    isActive: true,
  });

  await db.doc(`construtoras/${cBetaId}/obras/${oBeta1Id}/members/usr-admin-beta`).set({
    userId: 'usr-admin-beta',
    isAdmin: true,
    isActive: true,
    modules: ['diario', 'lotes', 'estoque'],
    joinedAt: daysAgo(30).toDate().toISOString(),
  });

  await db.doc(`construtoras/${cBetaId}/obras/${oBeta1Id}/members/usr-eng-beta`).set({
    userId: 'usr-eng-beta',
    isAdmin: false,
    isActive: true,
    modules: ['diario', 'lotes', 'estoque'],
    joinedAt: daysAgo(30).toDate().toISOString(),
  });

  // Lotes Obra Beta
  const lotesBeta1 = [
    { id: 'lote-beta-s1', name: 'Bloco Solar Norte - 2.5MW', phase: 'Fundação', status: 'noPrazo' },
    { id: 'lote-beta-s2', name: 'Subestação Central Rebaixadora', phase: 'Estrutura', status: 'noPrazo' },
  ];
  for (const l of lotesBeta1) {
    await db.doc(`construtoras/${cBetaId}/obras/${oBeta1Id}/lotes/${l.id}`).set({
      id: l.id,
      construtoraId: cBetaId,
      obraId: oBeta1Id,
      name: l.name,
      phase: l.phase,
      status: l.status,
      responsavelId: 'usr-eng-beta',
      createdAt: daysAgo(25).toDate().toISOString(),
    });
  }

  // Diário Obra Beta
  await db.doc(`construtoras/${cBetaId}/obras/${oBeta1Id}/diarios/diario-beta-01`).set({
    id: 'diario-beta-01',
    construtoraId: cBetaId,
    obraId: oBeta1Id,
    date: daysAgo(0).toDate().toISOString(),
    weather: 'sol',
    efetivo: [
      { role: 'Eletricista Montador', count: 12 },
      { role: 'Ajudante Geral', count: 8 },
      { role: 'Técnico em Segurança', count: 1 },
    ],
    observacoes: 'Fixação dos trilhos de alumínio nas estacas metálicas do setor A1.',
    photoUrls: [],
    localPhotoPaths: [],
    isPendingSync: false,
    responsavelId: 'usr-eng-beta',
    createdAt: now.toDate().toISOString(),
  });

  // Materiais Estoque Beta
  const materiaisBeta = [
    {
      id: 'mat-beta-tijolo',
      name: 'Tijolo Cerâmico 8 Furos',
      unit: 'Milheiro',
      quantityUnits: 22000, // 22 milheiros
      currentQuantity: 22.0,
    },
    {
      id: 'mat-beta-argamassa',
      name: 'Argamassa Colante AC-III 20kg',
      unit: 'Saco',
      quantityUnits: 95000, // 95 sacos
      currentQuantity: 95.0,
    },
    {
      id: 'mat-beta-pvc',
      name: 'Tubo PVC Esgoto 100mm',
      unit: 'Barra 6m',
      quantityUnits: 70000, // 70 barras
      currentQuantity: 70.0,
    },
  ];

  for (const m of materiaisBeta) {
    const matRef = db.doc(`construtoras/${cBetaId}/materiais/${m.id}`);
    await matRef.set({
      id: m.id,
      construtoraId: cBetaId,
      name: m.name,
      unit: m.unit,
      quantityUnits: m.quantityUnits,
      quantityScale: 1000,
      currentQuantity: m.currentQuantity,
      schemaVersion: 2,
    });

    await matRef.collection('movimentacoes').doc('abertura-inicial').set({
      id: 'abertura-inicial',
      materialId: m.id,
      type: 'entrada',
      commandType: 'abertura',
      quantity: m.currentQuantity,
      quantityUnits: m.quantityUnits,
      deltaUnits: m.quantityUnits,
      quantityScale: 1000,
      date: daysAgo(20),
      responsavelId: 'usr-admin-beta',
      observacao: 'Saldo inicial verificado Beta',
    });
  }

  // Despesas Financeiras Beta
  const despesasBeta = [
    {
      id: 'desp-beta-01',
      descricao: 'Fornecimento de Estruturas Metálicas de Fixação',
      valorEmCentavos: 6200000, // R$ 62.000,00
      categoria: 'Equipamentos',
      status: 'pago',
      dataVencimento: dateStr(new Date(Date.now() - 10 * 86400000)),
      dataPagamento: daysAgo(10),
      responsavelId: 'usr-admin-beta',
      obraId: oBeta1Id,
    },
    {
      id: 'desp-beta-02',
      descricao: 'Serviços Especializados de Sondagem e Topografia',
      valorEmCentavos: 750000, // R$ 7.500,00
      categoria: 'Serviços',
      status: 'pendente',
      dataVencimento: dateStr(new Date(Date.now() + 8 * 86400000)),
      dataPagamento: null,
      responsavelId: 'usr-admin-beta',
      obraId: oBeta1Id,
    },
  ];

  for (const d of despesasBeta) {
    await db.doc(`construtoras/${cBetaId}/despesas/${d.id}`).set({
      id: d.id,
      construtoraId: cBetaId,
      obraId: d.obraId,
      descricao: d.descricao,
      valor: d.valorEmCentavos / 100,
      valorEmCentavos: d.valorEmCentavos,
      categoria: d.categoria,
      status: d.status,
      dataVencimento: d.dataVencimento,
      dataPagamento: d.dataPagamento,
      responsavelId: d.responsavelId,
      schemaVersion: 2,
      createdAt: daysAgo(12),
    });
  }

  console.log('✅ [SEED] Sucesso! Base mockada com 2 construtoras completas.');
}

seed()
  .catch((err) => {
    console.error('❌ Erro no seed:', err);
    process.exit(1);
  })
  .then(() => process.exit(0));
