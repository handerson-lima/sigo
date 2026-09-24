import 'dart:io';

void main() async {
  // Fix Setores List Screen
  final slFile = File('app/lib/src/features/setores/presentation/setores_list_screen.dart');
  var slContent = await slFile.readAsString();
  if (slContent.contains('StreamBuilder')) {
    slContent = slContent.replaceAll(
      'final stream = ref.watch(setorRepositoryProvider).watchSetores(construtoraId, loteamentoId, quadraId, loteId);',
      'final setoresAsync = ref.watch(watchSetoresProvider({\'construtoraId\': construtoraId, \'loteamentoId\': loteamentoId, \'quadraId\': quadraId, \'loteId\': loteId}));'
    );
    
    slContent = slContent.replaceFirst(
      "import '../data/setor_repository.dart';",
      "import '../data/setor_repository.dart';\nimport 'package:intl/intl.dart';"
    );
    
    final pattern = r'''          Expanded\(
            child: StreamBuilder<List<Setor>>\(
              stream: stream,
              builder: \(context, snapshot\) {
                if \(snapshot\.connectionState == ConnectionState\.waiting\) {
                  return const Center\(child: CircularProgressIndicator\(\)\);
                }
                if \(snapshot\.hasError\) {
                  return Center\(child: Text\('Erro: \$\{snapshot\.error\}'\)\);
                }
                final items = snapshot\.data \?\? \[\];
                if \(items\.isEmpty\) return const Center\(child: Text\('Nenhum registro encontrado\.'\)\);

                return ListView\.builder\(
                  itemCount: items\.length,
                  itemBuilder: \(context, index\) {
                    final item = items\[index\];
                    return ListTile\(
                      title: Text\(item\.name\),
                      subtitle: Text\('Criado em: \$\{item\.createdAt\}'\),
                      onTap: \(\) {
                        context\.go\('/construtora/\$construtoraId/loteamentos/\$loteamentoId/quadras/\$quadraId/lotes/\$loteId/setores/\$\{item\.id\}/equipes'\);
                      },
                    \);
                  },
                \);
              },
            \),
          \),''';
    
    final replacement = '''          Expanded(
            child: setoresAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Não foi possível carregar os setores. Tente novamente.')),
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('Criado em: \$dateStr'),
                      onTap: () {
                        context.go('/construtoras/\$construtoraId/loteamentos/\$loteamentoId/quadras/\$quadraId/lotes/\$loteId/setores/\${item.id}/equipes');
                      },
                    );
                  },
                );
              },
            ),
          ),''';

    slContent = slContent.replaceFirst(RegExp(pattern), replacement);
    
    // Fix link bug `/construtora/` -> `/construtoras/` 
    // Notice I changed `construtora` to `construtoras` in context.go above.
    await slFile.writeAsString(slContent);
  }

  // Fix Equipes List Screen
  final elFile = File('app/lib/src/features/equipes/presentation/equipes_list_screen.dart');
  var elContent = await elFile.readAsString();
  if (elContent.contains('StreamBuilder')) {
    elContent = elContent.replaceAll(
      'final stream = ref.watch(equipeRepositoryProvider).watchEquipes(construtoraId, loteamentoId, quadraId, loteId, setorId);',
      'final equipesAsync = ref.watch(watchEquipesProvider({\'construtoraId\': construtoraId, \'loteamentoId\': loteamentoId, \'quadraId\': quadraId, \'loteId\': loteId, \'setorId\': setorId}));'
    );
    
    elContent = elContent.replaceFirst(
      "import '../data/equipe_repository.dart';",
      "import '../data/equipe_repository.dart';\nimport 'package:intl/intl.dart';"
    );
    
    final pattern2 = r'''          Expanded\(
            child: StreamBuilder<List<Equipe>>\(
              stream: stream,
              builder: \(context, snapshot\) {
                if \(snapshot\.connectionState == ConnectionState\.waiting\) {
                  return const Center\(child: CircularProgressIndicator\(\)\);
                }
                if \(snapshot\.hasError\) {
                  return Center\(child: Text\('Erro: \$\{snapshot\.error\}'\)\);
                }
                final items = snapshot\.data \?\? \[\];
                if \(items\.isEmpty\) return const Center\(child: Text\('Nenhum registro encontrado\.'\)\);

                return ListView\.builder\(
                  itemCount: items\.length,
                  itemBuilder: \(context, index\) {
                    final item = items\[index\];
                    return ListTile\(
                      title: Text\(item\.name\),
                      subtitle: Text\('Criado em: \$\{item\.createdAt\}'\),
                    \);
                  },
                \);
              },
            \),
          \),''';
          
    final replacement2 = '''          Expanded(
            child: equipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Não foi possível carregar as equipes. Tente novamente.')),
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('Criado em: \$dateStr'),
                    );
                  },
                );
              },
            ),
          ),''';

    elContent = elContent.replaceFirst(RegExp(pattern2), replacement2);
    await elFile.writeAsString(elContent);
  }
}
