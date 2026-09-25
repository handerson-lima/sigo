import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/fornecedores_repository.dart';
import '../domain/fornecedor.dart';
import '../domain/fornecedor_validator.dart';
import 'fornecedores_controller.dart';

class FornecedoresListScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const FornecedoresListScreen({super.key, required this.construtoraId});

  @override
  ConsumerState<FornecedoresListScreen> createState() =>
      _FornecedoresListScreenState();
}

class _FornecedoresListScreenState
    extends ConsumerState<FornecedoresListScreen> {
  String _filtroStatus = 'ativos'; // 'ativos', 'todos', 'inativos'
  String _categoriaSelecionada = 'todas';
  String _termoBusca = '';

  Future<void> _toggleStatusFornecedor(Fornecedor fornecedor) async {
    final novoStatusAtivo = !fornecedor.isAtivo;
    final acao = novoStatusAtivo ? 'Reativar' : 'Inativar';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$acao Fornecedor'),
        content: Text(
          novoStatusAtivo
              ? 'Deseja reativar "${fornecedor.nomeExibicao}"? Ele voltará a estar disponível para seleção em compras e almoxarifado.'
              : 'Deseja inativar "${fornecedor.nomeExibicao}"? Ele ficará oculto em novas seleções de compras e despesas, mas o histórico passado será rigorosamente preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: novoStatusAtivo ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(acao),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      final sucesso = await ref
          .read(fornecedoresControllerProvider.notifier)
          .toggleStatus(
            construtoraId: widget.construtoraId,
            fornecedorId: fornecedor.id,
            ativo: novoStatusAtivo,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: sucesso ? Colors.green : Colors.red,
            content: Text(
              sucesso
                  ? 'Fornecedor ${novoStatusAtivo ? "reativado" : "inativado"} com sucesso!'
                  : 'Erro ao alterar status do fornecedor.',
            ),
          ),
        );
      }
    }
  }

  void _copiarPix(String chavePix) {
    Clipboard.setData(ClipboardData(text: chavePix));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Chave Pix copiada: $chavePix'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fornecedoresAsync = ref.watch(
      fornecedoresStreamProvider((
        construtoraId: widget.construtoraId,
        apenasAtivos: false,
      )),
    );

    return SigoLayout(
      title: 'Catálogo de Fornecedores',
      activeRoute: '/construtoras/${widget.construtoraId}/fornecedores',
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            context.push(
              '/construtoras/${widget.construtoraId}/fornecedores/novo',
            );
          },
          icon: const Icon(Icons.add_business),
          label: const Text('Novo Fornecedor'),
        ),
      ],
      child: fornecedoresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Erro ao carregar fornecedores: $err')),
        data: (fornecedores) {
          // Extrai todas as categorias cadastradas para o filtro
          final todasCategorias = <String>{};
          for (final f in fornecedores) {
            todasCategorias.addAll(f.categorias);
          }

          // Filtragem
          final filtrados = fornecedores.where((f) {
            // Filtro de status
            if (_filtroStatus == 'ativos' && !f.isAtivo) return false;
            if (_filtroStatus == 'inativos' && f.isAtivo) return false;

            // Filtro de categoria
            if (_categoriaSelecionada != 'todas' &&
                !f.categorias.contains(_categoriaSelecionada)) {
              return false;
            }

            // Busca textual
            if (_termoBusca.isNotEmpty) {
              final query = _termoBusca.toLowerCase();
              final razao = f.razaoSocial.toLowerCase();
              final fantasia = (f.nomeFantasia ?? '').toLowerCase();
              final doc = f.documento;
              final tel = f.telefone ?? '';
              final email = (f.email ?? '').toLowerCase();

              if (!razao.contains(query) &&
                  !fantasia.contains(query) &&
                  !doc.contains(query) &&
                  !tel.contains(query) &&
                  !email.contains(query)) {
                return false;
              }
            }

            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de filtros e pesquisa
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Campo de busca
                      SizedBox(
                        width: 320,
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Buscar razão, fantasia, CNPJ/CPF...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: const OutlineInputBorder(),
                            suffixIcon: _termoBusca.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() => _termoBusca = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            setState(() => _termoBusca = val.trim());
                          },
                        ),
                      ),

                      // Segmented Button de Status
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'ativos',
                            label: Text('Ativos'),
                            icon: Icon(Icons.check_circle_outline, size: 16),
                          ),
                          ButtonSegment(value: 'todos', label: Text('Todos')),
                          ButtonSegment(
                            value: 'inativos',
                            label: Text('Inativos'),
                            icon: Icon(Icons.pause_circle_outline, size: 16),
                          ),
                        ],
                        selected: {_filtroStatus},
                        onSelectionChanged: (set) {
                          setState(() => _filtroStatus = set.first);
                        },
                      ),

                      // Filtro de Categorias (se houver)
                      if (todasCategorias.isNotEmpty)
                        DropdownButton<String>(
                          value: _categoriaSelecionada,
                          items: [
                            const DropdownMenuItem(
                              value: 'todas',
                              child: Text('Todas as categorias'),
                            ),
                            ...todasCategorias.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(_formatarCategoria(c)),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _categoriaSelecionada = val);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Contagem e lista
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '${filtrados.length} fornecedor(es) encontrado(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              // Lista vazia
              if (filtrados.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum fornecedor encontrado para os filtros atuais.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push(
                              '/construtoras/${widget.construtoraId}/fornecedores/novo',
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Cadastrar Primeiro Fornecedor'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final f = filtrados[idx];
                      return _buildFornecedorCard(f);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFornecedorCard(Fornecedor f) {
    return Card(
      elevation: f.isAtivo ? 1.5 : 0.5,
      color: f.isAtivo ? null : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: f.isAtivo ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha superior: Nome e Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: f.isAtivo
                      ? (f.isPessoaJuridica
                            ? Colors.blue.shade100
                            : Colors.teal.shade100)
                      : Colors.grey.shade300,
                  foregroundColor: f.isAtivo
                      ? (f.isPessoaJuridica
                            ? Colors.blue.shade800
                            : Colors.teal.shade800)
                      : Colors.grey.shade700,
                  child: Icon(
                    f.isPessoaJuridica ? Icons.business : Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              f.nomeExibicao,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: f.isAtivo ? null : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: f.isAtivo
                                  ? Colors.green.shade50
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: f.isAtivo
                                    ? Colors.green.shade300
                                    : Colors.grey.shade400,
                              ),
                            ),
                            child: Text(
                              f.isAtivo ? 'ATIVO' : 'INATIVO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: f.isAtivo
                                    ? Colors.green.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (f.nomeFantasia != null &&
                          f.nomeFantasia!.isNotEmpty &&
                          f.razaoSocial != f.nomeFantasia)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Razão Social: ${f.razaoSocial}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              f.isPessoaJuridica ? 'CNPJ' : 'CPF',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            f.documentoFormatado,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Contatos e Endereço
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (f.telefone != null && f.telefone!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        FornecedorValidator.formatarTelefone(f.telefone),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                if (f.whatsapp != null && f.whatsapp!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 15,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        FornecedorValidator.formatarTelefone(f.whatsapp),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                if (f.email != null && f.email!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(f.email!, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                if (f.endereco != null && f.endereco!.cidade != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${f.endereco!.cidade}/${f.endereco!.uf ?? ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),

            // Categorias em Chips
            if (f.categorias.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: f.categorias.map((c) {
                  return Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    label: Text(
                      _formatarCategoria(c),
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.blueGrey.shade50,
                  );
                }).toList(),
              ),
            ],

            // Dados Bancários / Pix
            if (f.dadosBancarios?.chavePix != null &&
                f.dadosBancarios!.chavePix!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pix, size: 16, color: Colors.teal.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'Pix: ${f.dadosBancarios!.chavePix}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _copiarPix(f.dadosBancarios!.chavePix!),
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 20),

            // Ações de Rodapé
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _toggleStatusFornecedor(f),
                  icon: Icon(
                    f.isAtivo
                        ? Icons.pause_circle_outline
                        : Icons.check_circle_outline,
                    size: 18,
                    color: f.isAtivo ? Colors.orange.shade800 : Colors.green,
                  ),
                  label: Text(
                    f.isAtivo ? 'Inativar' : 'Reativar',
                    style: TextStyle(
                      color: f.isAtivo ? Colors.orange.shade800 : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push(
                      '/construtoras/${widget.construtoraId}/fornecedores/${f.id}/editar',
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatarCategoria(String cat) {
    return switch (cat) {
      'materiais_basicos' => 'Materiais Básicos',
      'eletrica_hidraulica' => 'Elétrica & Hidráulica',
      'acabamento' => 'Acabamento',
      'locacao_equipamentos' => 'Locação de Equipamentos',
      'servicos_empreiteiro' => 'Empreiteiro / Mão de Obra',
      'transporte_cacamba' => 'Transporte & Caçambas',
      'epi' => 'EPI & Segurança',
      'alimentacao' => 'Alimentação',
      'servicos_adm' => 'Serviços ADM',
      _ => cat,
    };
  }
}
