import '../../authentication/data/user_repository.dart';
import 'current_permissions_provider.dart';
import '../../financeiro/domain/despesa.dart';
import '../../../core/contracts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'construtora_obras_provider.dart';

import 'package:fl_chart/fl_chart.dart';

import '../../financeiro/presentation/financeiro_provider.dart';

import '../../../common_widgets/sigo_layout.dart';

import 'package:uuid/uuid.dart';

import '../data/obra_repository.dart';
import '../domain/obra.dart';

class ObrasListScreen extends ConsumerWidget {
  final String construtoraId;

  const ObrasListScreen({super.key, required this.construtoraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obrasAsync = ref.watch(construtoraObrasProvider(construtoraId));
    final cm = ref.watch(construtoraPermissionProvider(construtoraId)).value;
    final admin =
        ref.watch(trustedDevProvider).value == true ||
        cm?['isActive'] == true &&
            (cm?['isAdmin'] == true ||
                cm?['isOwner'] == true ||
                cm?['role'] == 'admin' ||
                cm?['role'] == 'owner');
    final stock =
        admin ||
        cm?['isActive'] == true &&
            (cm?['modules'] as List? ?? []).any(
              (m) => m == 'estoque' || m == 'almoxarifado',
            );
    final hasRh =
        admin ||
        cm?['isActive'] == true &&
            (cm?['modules'] as List? ?? []).any(
              (m) => m == 'rh' || m == 'recursos_humanos',
            );
    final hasValidacao =
        admin ||
        cm?['isActive'] == true &&
            (cm?['modules'] as List? ?? []).any(
              (m) => m == 'validacao' || m == 'qualidade',
            );
    final hasEpi =
        admin ||
        cm?['isActive'] == true &&
            (cm?['modules'] as List? ?? []).any(
              (m) => m == 'epi' || m == 'rh' || m == 'seguranca',
            );
    final hasFornecedores =
        admin ||
        cm?['isActive'] == true &&
            (cm?['modules'] as List? ?? []).any(
              (m) =>
                  m == 'fornecedores' ||
                  m == 'compras' ||
                  m == 'financeiro' ||
                  m == 'adm' ||
                  m == 'almoxarifado' ||
                  m == 'estoque',
            );
    final despesasAsync = admin
        ? ref.watch(despesasConstrutoraProvider(construtoraId))
        : const AsyncData<List<Despesa>>([]);
    final canViewLoteamentos =
        admin ||
        cm?['isActive'] == true &&
            normalizeRawModules(
              cm?['modules'],
              cm?['allowedModules'],
            ).contains('lotes');

    return SigoLayout(
      title: 'Painel da Construtora',
      activeRoute: '/construtoras/$construtoraId',
      actions: [
        if (admin)
          IconButton(
            icon: const Icon(Icons.add_business, color: Colors.black54),
            tooltip: 'Novo Loteamento',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => _AddObraDialog(construtoraId: construtoraId),
              );
            },
          ),
        if (admin)
          IconButton(
            icon: const Icon(Icons.people, color: Colors.black54),
            tooltip: 'Gerenciar Membros',
            onPressed: () {
              context.go('/construtoras/$construtoraId/membros');
            },
          ),
        if (canViewLoteamentos)
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.black54),
            tooltip: 'Loteamentos',
            onPressed: () {
              context.go('/construtoras/$construtoraId/loteamentos');
            },
          ),
        if (hasRh)
          IconButton(
            icon: const Icon(Icons.badge, color: Colors.black54),
            tooltip: 'Recursos Humanos (RH)',
            onPressed: () {
              context.go('/construtoras/$construtoraId/rh');
            },
          ),
        if (stock)
          IconButton(
            icon: const Icon(Icons.inventory_2, color: Colors.black54),
            tooltip: 'Almoxarifado Global',
            onPressed: () {
              context.go('/construtoras/$construtoraId/almoxarifado');
            },
          ),
        if (admin)
          IconButton(
            icon: const Icon(
              Icons.account_balance_wallet,
              color: Colors.black54,
            ),
            tooltip: 'Financeiro Global',
            onPressed: () {
              context.go('/construtoras/$construtoraId/financeiro');
            },
          ),
        if (hasValidacao)
          IconButton(
            icon: const Icon(Icons.rule, color: Colors.black54),
            tooltip: 'Templates de Validação',
            onPressed: () {
              context.go('/construtoras/$construtoraId/validacao/templates');
            },
          ),
        if (hasEpi)
          IconButton(
            icon: const Icon(Icons.health_and_safety, color: Colors.black54),
            tooltip: 'Catálogo de EPIs',
            onPressed: () {
              context.go('/construtoras/$construtoraId/epis');
            },
          ),
        if (hasFornecedores)
          IconButton(
            icon: const Icon(Icons.storefront, color: Colors.black54),
            tooltip: 'Fornecedores',
            onPressed: () {
              context.go('/construtoras/$construtoraId/fornecedores');
            },
          ),
      ],
      child: obrasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (obras) {
          if (obras.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nenhum loteamento encontrado para você nesta construtora.',
                    textAlign: TextAlign.center,
                  ),
                  if (admin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) =>
                              _AddObraDialog(construtoraId: construtoraId),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Criar Novo Loteamento'),
                    ),
                  ],
                ],
              ),
            );
          }
          return Column(
            children: [
              despesasAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, _) => const SizedBox(),
                data: (despesas) {
                  if (despesas.isEmpty) return const SizedBox();

                  final Map<String, double> categoryTotals = {};
                  for (var d in despesas) {
                    categoryTotals[d.categoria] =
                        (categoryTotals[d.categoria] ?? 0) + d.valor;
                  }

                  final colors = [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                    Colors.teal,
                  ];
                  int cIdx = 0;

                  return SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: categoryTotals.entries.map((e) {
                                final color = colors[cIdx++ % colors.length];
                                return PieChartSectionData(
                                  value: e.value,
                                  color: color,
                                  title: '',
                                  radius: 20,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: categoryTotals.length,
                            itemBuilder: (context, index) {
                              final entry = categoryTotals.entries.elementAt(
                                index,
                              );
                              final color = colors[index % colors.length];
                              return ListTile(
                                leading: Container(
                                  width: 16,
                                  height: 16,
                                  color: color,
                                ),
                                title: Text(
                                  entry.key,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'R\$ ${entry.value.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 3 / 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: obras.length,
                  itemBuilder: (context, index) {
                    final obra = obras[index];
                    return Card(
                      elevation: 4,
                      child: InkWell(
                        onTap: () => context.go(
                          '/construtoras/$construtoraId/obra/${obra.id}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                obra.name,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              if (obra.description != null)
                                Text(
                                  obra.description!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddObraDialog extends ConsumerStatefulWidget {
  final String construtoraId;

  const _AddObraDialog({required this.construtoraId});

  @override
  ConsumerState<_AddObraDialog> createState() => _AddObraDialogState();
}

class _AddObraDialogState extends ConsumerState<_AddObraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final obra = Obra(
        id: const Uuid().v4(),
        construtoraId: widget.construtoraId,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        createdAt: DateTime.now(),
        isActive: true,
      );

      await ref.read(obraRepositoryProvider).createObra(obra);
      ref.invalidate(construtoraObrasProvider(widget.construtoraId));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loteamento cadastrado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cadastrar loteamento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Loteamento'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Loteamento *',
                    hintText: 'Ex: Residencial Flores',
                  ),
                  autofocus: true,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Campo obrigatório'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Ex: Construção de 20 casas geminadas',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Endereço (opcional)',
                    hintText: 'Ex: Rua das Palmeiras, 100',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
