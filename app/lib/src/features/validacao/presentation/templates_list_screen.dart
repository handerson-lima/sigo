import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/validacao_repository.dart';
import '../domain/validacao_template.dart';
import 'template_form_dialog.dart';

class TemplatesListScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const TemplatesListScreen({super.key, required this.construtoraId});

  @override
  ConsumerState<TemplatesListScreen> createState() =>
      _TemplatesListScreenState();
}

class _TemplatesListScreenState extends ConsumerState<TemplatesListScreen> {
  String _filtroDisciplina = 'todas';
  String _termoBusca = '';

  void _abrirDialogTemplate([ValidacaoTemplate? template]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TemplateFormDialog(
        construtoraId: widget.construtoraId,
        templateExistente: template,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(
      templatesListStreamProvider(widget.construtoraId),
    );

    return SigoLayout(
      title: 'Templates de Validação & Qualidade',
      activeRoute: '/construtoras/${widget.construtoraId}/validacao/templates',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _abrirDialogTemplate(),
          icon: const Icon(Icons.add),
          label: const Text('Novo Template'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar templates...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) => setState(() => _termoBusca = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _filtroDisciplina,
                  decoration: const InputDecoration(
                    labelText: 'Disciplina',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'todas',
                      child: Text('Todas as Disciplinas'),
                    ),
                    DropdownMenuItem(
                      value: 'alvenaria',
                      child: Text('Alvenaria'),
                    ),
                    DropdownMenuItem(
                      value: 'estrutura',
                      child: Text('Estrutura'),
                    ),
                    DropdownMenuItem(
                      value: 'fundacao',
                      child: Text('Fundação'),
                    ),
                    DropdownMenuItem(
                      value: 'eletrica',
                      child: Text('Elétrica'),
                    ),
                    DropdownMenuItem(
                      value: 'hidraulica',
                      child: Text('Hidráulica'),
                    ),
                    DropdownMenuItem(value: 'pintura', child: Text('Pintura')),
                    DropdownMenuItem(
                      value: 'acabamento',
                      child: Text('Acabamento'),
                    ),
                    DropdownMenuItem(
                      value: 'cobertura',
                      child: Text('Cobertura'),
                    ),
                    DropdownMenuItem(value: 'geral', child: Text('Geral')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _filtroDisciplina = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Erro ao carregar templates: $err')),
              data: (templates) {
                var filtrados = templates.where((t) {
                  final matchesBusca =
                      _termoBusca.isEmpty ||
                      t.titulo.toLowerCase().contains(
                        _termoBusca.toLowerCase(),
                      ) ||
                      t.disciplinaFormatada.toLowerCase().contains(
                        _termoBusca.toLowerCase(),
                      );
                  final matchesDisc =
                      _filtroDisciplina == 'todas' ||
                      t.disciplina.toLowerCase() ==
                          _filtroDisciplina.toLowerCase();
                  return matchesBusca && matchesDisc;
                }).toList();

                if (filtrados.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          templates.isEmpty
                              ? 'Nenhum template corporativo cadastrado ainda.'
                              : 'Nenhum template corresponde aos filtros selecionados.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (templates.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _abrirDialogTemplate(),
                            icon: const Icon(Icons.add),
                            label: const Text('Cadastrar Primeiro Template'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tpl = filtrados[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: tpl.ativo
                                  ? Theme.of(context).primaryColor.withAlpha(30)
                                  : Colors.grey[200],
                              child: Icon(
                                Icons.rule,
                                color: tpl.ativo
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tpl.titulo,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue[200]!,
                                          ),
                                        ),
                                        child: Text(
                                          'v${tpl.version}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tpl.ativo
                                              ? Colors.green[50]
                                              : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: tpl.ativo
                                                ? Colors.green[300]!
                                                : Colors.grey[400]!,
                                          ),
                                        ),
                                        child: Text(
                                          tpl.ativo ? 'Ativo' : 'Inativo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: tpl.ativo
                                                ? Colors.green[800]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Disciplina: ${tpl.disciplinaFormatada} • ${tpl.itens.length} itens de verificação',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Editar Template (Criar Versão)',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _abrirDialogTemplate(tpl),
                            ),
                            IconButton(
                              tooltip: tpl.ativo ? 'Desativar' : 'Reativar',
                              icon: Icon(
                                tpl.ativo ? Icons.toggle_on : Icons.toggle_off,
                                color: tpl.ativo ? Colors.green : Colors.grey,
                                size: 28,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(validacaoRepositoryProvider)
                                    .toggleTemplateAtivo(
                                      tpl.construtoraId,
                                      tpl.id,
                                      !tpl.ativo,
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
