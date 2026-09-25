import re

with open("app/test/src/features/etapas/presentation/etapas_list_screen_test.dart", "r") as f:
    content = f.read()

# Add imports
content = content.replace(
    "import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';",
    "import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';"
)

# Add FakeEtapaRepository
fake_repo = """
class FakeEtapaRepository implements EtapaRepository {
  @override
  Future<void> createDefaultEtapas({
    WriteBatch? batch,
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required String loteId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
"""

content = content.replace("void main() {", fake_repo + "\nvoid main() {")

# Add override
content = content.replace(
"""          isConstrutoraAdminProvider('c1')
              .overrideWith((ref) => Stream.value(true)),
        ],""",
"""          isConstrutoraAdminProvider('c1')
              .overrideWith((ref) => Stream.value(true)),
          etapaRepositoryProvider.overrideWithValue(FakeEtapaRepository()),
        ],"""
)

with open("app/test/src/features/etapas/presentation/etapas_list_screen_test.dart", "w") as f:
    f.write(content)
