# SIGO — app (Flutter)

Cliente Flutter do **SIGO** (Sistema Integrado de Gestão de Obras): login e perfis,
construtoras, obras, membros, lotes, almoxarifado, financeiro, diário de obra e os
módulos de RH/EPI, com Firebase (Auth, Firestore, Cloud Functions, Storage),
Riverpod e GoRouter.

## Pré-requisitos

- Flutter **3.47.2** (stable) — a mesma versão fixada no CI.
- Dependências resolvidas pelo `pubspec.lock`.
- Node 20 e Java para Functions/emuladores — ver
  [docs/implantacao-c0-c6.md](../docs/implantacao-c0-c6.md).

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
```

## Emuladores, Functions e PWA

Os comandos locais de emulação (Auth/Firestore/Storage), testes de Rules,
Functions (`cd functions && npm ci && npm test`) e o preparo da PWA estão em
[docs/implantacao-c0-c6.md](../docs/implantacao-c0-c6.md).

## Validação e produção

- Estado da validação C0–C6 em desenvolvimento:
  [docs/validacao-c0-c6.md](../docs/validacao-c0-c6.md) (ACEITO em dev).
- Implantação em produção **não é autorizada** por este plano; é apresentada
  separadamente com simulação e plano de recuperação.
