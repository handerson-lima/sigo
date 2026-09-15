#!/usr/bin/env node
/**
 * SIGO — Inventário de produção via Admin SDK
 *
 * Lê as coleções críticas do Firestore de produção e gera um JSON compatível
 * com migration.cjs para análise offline (dry-run).
 *
 * Uso:
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node scripts/inventory.cjs [--output inventario.json]
 *   ou com Application Default Credentials já configurado:
 *   node scripts/inventory.cjs [--output inventario.json]
 *
 * SEGURANÇA: este script lê, nunca escreve. Confirme antes de executar em produção.
 */
'use strict';
const admin = require('firebase-admin');
const fs = require('node:fs');
const path = require('node:path');

// ── Configuração ──────────────────────────────────────────────────────────────
const PROJECT_ID = 'sigo-c2eb2';
const OUTPUT = process.argv.includes('--output')
  ? process.argv[process.argv.indexOf('--output') + 1]
  : `inventario-${new Date().toISOString().slice(0, 10)}.json`;

// Coleções a inventariar (subcoleções de construtoras)
const SUBCOLLECTIONS = ['construtora_members', 'despesas', 'materiais', 'obras'];
const OBRA_SUBCOLLECTIONS = ['members', 'lotes', 'diarios'];

// ── Inicialização ─────────────────────────────────────────────────────────────
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

// ── Helpers ───────────────────────────────────────────────────────────────────
async function readAll(ref) {
  const snap = await ref.get();
  return snap.docs.map(d => ({ id: d.id, path: d.ref.path, data: d.data() }));
}

function sanitize(data) {
  // Converte Timestamp para string ISO para serialização JSON segura
  const result = {};
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value._seconds === 'number') {
      result[key] = new Date(value._seconds * 1000).toISOString();
    } else if (value && typeof value === 'object' && !Array.isArray(value)) {
      result[key] = sanitize(value);
    } else {
      result[key] = value;
    }
  }
  return result;
}

// ── Inventário ────────────────────────────────────────────────────────────────
async function main() {
  console.error(`[inventory] Conectando ao projeto ${PROJECT_ID}...`);

  const report = {
    projectId: PROJECT_ID,
    generatedAt: new Date().toISOString(),
    mode: 'dry-run',
    evidence: `inventario-producao-${new Date().toISOString().slice(0,10)}`,
    identities: [],
    verifiedDevs: [],
    documents: [],
    summary: { construtoras: 0, despesas: 0, materiais: 0, membros: 0, diarios: 0, devRoles: 0 },
  };

  // 1. dev_roles
  console.error('[inventory] Lendo dev_roles...');
  const devRoles = await readAll(db.collection('dev_roles'));
  report.summary.devRoles = devRoles.length;
  for (const { id, data } of devRoles) {
    report.identities.push({ uid: id, globalRole: 'dev', isActive: data.isActive, claims: {} });
  }

  // 2. users com globalRole=dev (candidatos não verificados)
  console.error('[inventory] Lendo users com globalRole=dev...');
  const devUsers = await db.collection('users').where('globalRole', '==', 'dev').get();
  for (const doc of devUsers.docs) {
    if (!report.identities.find(i => i.uid === doc.id)) {
      report.identities.push({ uid: doc.id, globalRole: 'dev', isActive: false, claims: { note: 'globalRole apenas, sem dev_role confirmado' } });
    }
  }

  // 3. construtoras e subcoleções
  console.error('[inventory] Lendo construtoras...');
  const construtoras = await readAll(db.collection('construtoras'));
  report.summary.construtoras = construtoras.length;

  for (const { id: cId } of construtoras) {
    console.error(`[inventory]  → construtora: ${cId}`);

    for (const sub of SUBCOLLECTIONS) {
      const docs = await readAll(db.collection(`construtoras/${cId}/${sub}`));
      if (sub === 'despesas') report.summary.despesas += docs.length;
      if (sub === 'construtora_members') report.summary.membros += docs.length;
      if (sub === 'materiais') report.summary.materiais += docs.length;

      for (const { path: docPath, data } of docs) {
        report.documents.push({ path: docPath, data: sanitize(data) });

        // Obras: ler subcoleções de cada obra
        if (sub === 'obras') {
          for (const obraSub of OBRA_SUBCOLLECTIONS) {
            const obraDocs = await readAll(db.collection(`${docPath}/${obraSub}`));
            if (obraSub === 'diarios') report.summary.diarios += obraDocs.length;
            for (const { path: subPath, data: subData } of obraDocs) {
              report.documents.push({ path: subPath, data: sanitize(subData) });
            }
          }
        }
      }
    }
  }

  // 4. Salvar
  const outputPath = path.resolve(process.cwd(), OUTPUT);
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
  console.error(`[inventory] Inventário salvo em: ${outputPath}`);
  console.error(`[inventory] Resumo:`, JSON.stringify(report.summary, null, 2));
  console.error(`[inventory] Dev candidates: ${report.identities.length}`);
  console.error(`[inventory] Total de documentos: ${report.documents.length}`);
  console.error(`\n[inventory] Próximo passo:`);
  console.error(`  node scripts/migration.cjs ${OUTPUT}`);
}

main().catch(err => {
  console.error('[inventory] ERRO:', err.message);
  process.exit(1);
});
