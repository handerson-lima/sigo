import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/validacao_repository.dart';
import '../domain/validacao_template.dart';

class TemplateFormDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final ValidacaoTemplate? templateExistente;

  const TemplateFormDialog({
    super.key,
    required this.construtoraId,
    this.templateExistente,
  });

  @override
  ConsumerState<TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends ConsumerState<TemplateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  String _disciplinaSelecionada = 'alvenaria';
  late bool _ativo;
  bool _salvando = false;

  final List<ChecklistTemplateItem> _itens = [];

  final List<Map<String, String>> _disciplinasDisponiveis = [
    {'value': 'alvenaria', 'label': 'Alvenaria e Vedações'},
    {'value': 'estrutura', 'label': 'Estrutura e Concreto'},
    {'value': 'fundacao', 'label': 'Fundação e Solo'},
    {'value': 'eletrica', 'label': 'Instalações Elétricas'},
    {'value': 'hidraulica', 'label': 'Instalações Hidrossanitárias'},
    {'value': 'pintura', 'label': 'Pintura e Tratamento'},
    {'value': 'acabamento', 'label': 'Acabamentos e Revestimentos'},
    {'value': 'cobertura', 'label': 'Cobertura e Impermeabilização'},
    {'value': 'geral', 'label': 'Geral / Outros'},
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.templateExistente;
    _tituloController = TextEditingController(text: t?.titulo ?? '');
    _disciplinaSelecionada = t?.disciplina ?? 'alvenaria';
    _ativo = t?.ativo ?? true;

    if (t != null && t.itens.isNotEmpty) {
      _itens.addAll(t.itens);
    } else {
      // Itens padrão de exemplo para agilizar o preenchimento
      _itens.add(
        const ChecklistTemplateItem(
          id: 'item_1',
          titulo: 'Alinhamento e Prumo',
          descricao: 'Verificar prumo de face e nivelamento dos cantos.',
          obrigatorio: true,
          requerFotoSeReprovado: true,
        ),
      );
      _itens.add(
        const ChecklistTemplateItem(
          id: 'item_2',
          titulo: 'Amarração e Fixação',
          descricao: 'Fixação correta das telas e interfaces estruturais.',
          obrigatorio: true,
          requerFotoSeReprovado: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  void _adicionarItem() {
    setState(() {
      final novoId = 'item_${const Uuid().v4().substring(0, 8)}';
      _itens.add(
        ChecklistTemplateItem(
          id: novoId,
          titulo: 'Novo Item ${_itens.length + 1}',
          descricao: '',
          obrigatorio: true,
          requerFotoSeReprovado: true,
        ),
      );
    });
  }

  void _editarItem(int index) async {
    final item = _itens[index];
    final tituloCtrl = TextEditingController(text: item.titulo);
    final descCtrl = TextEditingController(text: item.descricao);
    bool obrigatorio = item.obrigatorio;
    bool requerFoto = item.requerFotoSeReprovado;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Configurar Item do Checklist'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título do Item *',
                        hintText: 'Ex.: Prumo das paredes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Critério / Descrição Técnica',
                        hintText: 'Ex.: Usar régua de nível e tolerância de 2mm',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Item Obrigatório'),
                      subtitle: const Text('Exige resposta para concluir vistoria'),
                      value: obrigatorio,
                      onChanged: (v) => setDlgState(() => obrigatorio = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Exigir Foto se Reprovado'),
                      subtitle: const Text('Obriga evidência fotográfica em não-conformidade'),
                      value: requerFoto,
                      onChanged: (v) => setDlgState(() => requerFoto = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tituloCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _itens[index] = item.copyWith(
                          titulo: tituloCtrl.text.trim(),
                          descricao: descCtrl.text.trim(),
                          obrigatorio: obrigatorio,
                          requerFotoSeReprovado: requerFoto,
                        );
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removerItem(int index) {
    setState(() {
      _itens.removeAt(index);
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos 1 item ao checklist do template.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final now = DateTime.now();
      final existente = widget.templateExistente;

      final templateId = existente?.id ?? const Uuid().v4();
      // Ao editar um template existente, incrementa a versão
      final novaVersao = existente != null ? existente.version + 1 : 1;

      final templateSalvar = ValidacaoTemplate(
        id: templateId,
        construtoraId: widget.construtoraId,
        titulo: _tituloController.text.trim(),
        disciplina: _disciplinaSelecionada,
        version: novaVersao,
        ativo: _ativo,
        createdAt: existente?.createdAt ?? now,
        updatedAt: now,
        itens: _itens,
      );

      await ref.read(validacaoRepositoryProvider).saveTemplate(templateSalvar);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existente != null
                  ? 'Template atualizado para versão $novaVersao com sucesso!'
                  : 'Template criado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existente = widget.templateExistente;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      existente != null ? Icons.edit_note : Icons.add_task,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        existente != null
                            ? 'Editar Template (Criar v${existente.version + 1})'
                            : 'Novo Template de Validação',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _tituloController,
                        decoration: const InputDecoration(
                          labelText: 'Título do Template *',
                          hintText: 'Ex.: Checklist de Alvenaria e Vedações',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o título do template'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _disciplinasDisponiveis.any((d) => d['value'] == _disciplinaSelecionada)
                            ? _disciplinaSelecionada
                            : 'geral',
                        decoration: const InputDecoration(
                          labelText: 'Disciplina Técnica *',
                          border: OutlineInputBorder(),
                        ),
                        items: _disciplinasDisponiveis.map((d) {
                          return DropdownMenuItem<String>(
                            value: d['value'],
                            child: Text(d['label']!),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _disciplinaSelecionada = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Template Ativo'),
                        subtitle: const Text('Templates inativos não aparecem para novas vistorias'),
                        value: _ativo,
                        onChanged: (v) => setState(() => _ativo = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Itens de Verificação (${_itens.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _adicionarItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_itens.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('Nenhum item adicionado ao checklist.'),
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _itens.length,
                          // ignore: deprecated_member_use
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _itens.removeAt(oldIndex);
                              _itens.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = _itens[index];
                            return Card(
                              key: ValueKey(item.id),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                title: Text(
                                  item.titulo,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  item.descricao.isNotEmpty
                                      ? item.descricao
                                      : (item.requerFotoSeReprovado
                                          ? 'Exige foto em não-conformidade'
                                          : 'Sem foto mandatória'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editarItem(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () => _removerItem(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _salvando ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        existente != null ? 'Salvar Nova Versão' : 'Criar Template',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
