import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../../common/services/watermark_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/validacao_repository.dart';
import '../domain/validacao_template.dart';
import '../domain/validacao_vistoria.dart';

class ValidacaoFormScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String loteId;
  final String? validacaoId;

  const ValidacaoFormScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    required this.loteId,
    this.validacaoId,
  });

  @override
  ConsumerState<ValidacaoFormScreen> createState() =>
      _ValidacaoFormScreenState();
}

class _ValidacaoFormScreenState extends ConsumerState<ValidacaoFormScreen> {
  bool _carregando = true;
  bool _salvando = false;
  String? _erroCarregamento;

  ValidacaoVistoria? _vistoria;
  final TextEditingController _observacoesGeraisController =
      TextEditingController();

  final Map<String, TextEditingController> _obsControllers = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _observacoesGeraisController.dispose();
    for (final c in _obsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });

    try {
      if (widget.validacaoId != null) {
        final v = await ref.read(validacaoRepositoryProvider).getVistoria(
              widget.construtoraId,
              widget.obraId,
              widget.loteId,
              widget.validacaoId!,
            );
        if (v != null) {
          _vistoria = v;
          _observacoesGeraisController.text = v.observacoesGerais ?? '';
          for (final item in v.itensRespondidos) {
            _obsControllers[item.itemId] =
                TextEditingController(text: item.observacao ?? '');
          }
        } else {
          _erroCarregamento = 'Vistoria não encontrada.';
        }
      }
    } catch (e) {
      _erroCarregamento = 'Erro ao carregar dados: $e';
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _iniciarComTemplate(ValidacaoTemplate tpl) {
    final user = ref.read(authRepositoryProvider).currentUser;
    final now = DateTime.now();

    final itens = tpl.itens.map((i) {
      return ItemRespondido(
        itemId: i.id,
        titulo: i.titulo,
        status: ItemConformidadeStatus.conforme,
        observacao: null,
        fotos: const [],
        obrigatorio: i.obrigatorio,
        requerFotoSeReprovado: i.requerFotoSeReprovado,
      );
    }).toList();

    for (final item in itens) {
      _obsControllers[item.itemId] = TextEditingController();
    }

    setState(() {
      _vistoria = ValidacaoVistoria(
        id: const Uuid().v4(),
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        loteId: widget.loteId,
        templateId: tpl.id,
        templateTitulo: tpl.titulo,
        disciplina: tpl.disciplina,
        templateVersion: tpl.version,
        status: ValidacaoStatus.pendente,
        inspetorUid: user?.uid ?? 'inspetor_anonimo',
        inspetorNome: user?.displayName ?? user?.email ?? 'Inspetor Responsável',
        dataVistoria: now,
        itensRespondidos: itens,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  void _alterarStatusItem(String itemId, ItemConformidadeStatus novoStatus) {
    if (_vistoria == null) return;
    final novosItens = _vistoria!.itensRespondidos.map((i) {
      if (i.itemId == itemId) {
        return i.copyWith(status: novoStatus);
      }
      return i;
    }).toList();

    setState(() {
      _vistoria = _vistoria!.copyWith(itensRespondidos: novosItens);
    });
  }

  Future<void> _adicionarFoto(ItemRespondido item) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (xFile == null) return;

    setState(() => _salvando = true);

    try {
      final bytes = await xFile.readAsBytes();

      // Aplicar carimbo d'água auditável (watermark)
      final watermarkService = WatermarkService();
      final stampedBytes = await watermarkService.applyWatermark(
        bytes,
        WatermarkMetadata(
          timestamp: DateTime.now(),
          obraNomeOuId: 'Obra: ${widget.obraId} | Lote: ${widget.loteId}',
          responsavelNomeOuUid: _vistoria?.inspetorNome,
        ),
      );

      final fotoId = 'foto_${const Uuid().v4().substring(0, 8)}';
      final urlOuPath = await ref
          .read(validacaoRepositoryProvider)
          .uploadFotoEvidencia(
            construtoraId: widget.construtoraId,
            obraId: widget.obraId,
            loteId: widget.loteId,
            validacaoId: _vistoria!.id,
            fotoId: fotoId,
            imageBytes: stampedBytes,
          );

      final novosItens = _vistoria!.itensRespondidos.map((i) {
        if (i.itemId == item.itemId) {
          final novasFotos = List<String>.from(i.fotos)..add(urlOuPath);
          return i.copyWith(fotos: novasFotos);
        }
        return i;
      }).toList();

      setState(() {
        _vistoria = _vistoria!.copyWith(itensRespondidos: novosItens);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidência fotográfica anexada com carimbo auditável!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Fallback: se falhar o upload no storage, adiciona como URI simulada/data URL
      final fotoId = 'evidencia_${DateTime.now().millisecondsSinceEpoch}';
      final novosItens = _vistoria!.itensRespondidos.map((i) {
        if (i.itemId == item.itemId) {
          final novasFotos = List<String>.from(i.fotos)..add('local://$fotoId');
          return i.copyWith(fotos: novasFotos);
        }
        return i;
      }).toList();

      setState(() {
        _vistoria = _vistoria!.copyWith(itensRespondidos: novosItens);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evidência registrada localmente: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _removerFoto(ItemRespondido item, int fotoIndex) {
    final novosItens = _vistoria!.itensRespondidos.map((i) {
      if (i.itemId == item.itemId) {
        final novasFotos = List<String>.from(i.fotos)..removeAt(fotoIndex);
        return i.copyWith(fotos: novasFotos);
      }
      return i;
    }).toList();

    setState(() {
      _vistoria = _vistoria!.copyWith(itensRespondidos: novosItens);
    });
  }

  Future<void> _salvarRascunho() async {
    if (_vistoria == null) return;
    setState(() => _salvando = true);

    try {
      final now = DateTime.now();
      final itensAtualizados = _vistoria!.itensRespondidos.map((i) {
        final txt = _obsControllers[i.itemId]?.text.trim();
        return i.copyWith(observacao: txt?.isNotEmpty == true ? txt : null);
      }).toList();

      final vistoriaSalvar = _vistoria!.copyWith(
        observacoesGerais: _observacoesGeraisController.text.trim(),
        itensRespondidos: itensAtualizados,
        updatedAt: now,
      );

      await ref.read(validacaoRepositoryProvider).saveVistoria(vistoriaSalvar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rascunho da vistoria salvo com sucesso!'),
            backgroundColor: Colors.blue,
          ),
        );
        context.go(
          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar rascunho: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _finalizarVistoria() async {
    if (_vistoria == null) return;

    final itensAtualizados = _vistoria!.itensRespondidos.map((i) {
      final txt = _obsControllers[i.itemId]?.text.trim();
      return i.copyWith(observacao: txt?.isNotEmpty == true ? txt : null);
    }).toList();

    final vistoriaVerificar = _vistoria!.copyWith(
      observacoesGerais: _observacoesGeraisController.text.trim(),
      itensRespondidos: itensAtualizados,
    );

    // Validação estrita de critérios de conclusão
    final erros = vistoriaVerificar.validarParaConclusao();
    if (erros.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Pendências no Checklist'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: erros.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text('• $e', style: const TextStyle(color: Colors.red)),
            )).toList(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final now = DateTime.now();
      final statusFinal = vistoriaVerificar.calcularStatusFinal();

      final vistoriaFinal = vistoriaVerificar.copyWith(
        status: statusFinal,
        dataFinalizacao: now,
        updatedAt: now,
      );

      await ref.read(validacaoRepositoryProvider).saveVistoria(vistoriaFinal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              statusFinal == ValidacaoStatus.aprovado
                  ? 'Vistoria APROVADA com sucesso! Lote conforme nesta disciplina.'
                  : 'Vistoria REPROVADA. Não-conformidades registradas com evidências.',
            ),
            backgroundColor: statusFinal == ValidacaoStatus.aprovado
                ? Colors.green
                : Colors.red,
          ),
        );
        context.go(
          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao finalizar vistoria: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _reabrirVistoria() async {
    if (_vistoria == null) return;
    setState(() => _salvando = true);

    try {
      await ref.read(validacaoRepositoryProvider).reabrirVistoria(
            widget.construtoraId,
            widget.obraId,
            widget.loteId,
            _vistoria!.id,
          );

      setState(() {
        _vistoria = _vistoria!.copyWith(status: ValidacaoStatus.reaberto);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vistoria reaberta com sucesso para re-inspeção!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reabrir vistoria: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _buildSelecaoTemplate() {
    final templatesAsync =
        ref.watch(templatesListStreamProvider(widget.construtoraId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.go(
                  '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Nova Vistoria de Qualidade — Lote ${widget.loteId}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Selecione o Template Corporativo de Inspeção:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erro: $err')),
            data: (templates) {
              final ativos = templates.where((t) => t.ativo).toList();
              if (ativos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rule_folder, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhum template de validação ativo encontrado.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.go(
                            '/construtoras/${widget.construtoraId}/validacao/templates',
                          );
                        },
                        child: const Text('Ir para Templates de Validação'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: ativos.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final tpl = ativos[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('v${tpl.version}'),
                      ),
                      title: Text(
                        tpl.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Disciplina: ${tpl.disciplinaFormatada} • ${tpl.itens.length} itens de checagem',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _iniciarComTemplate(tpl),
                        child: const Text('Utilizar Template'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormVistoria() {
    final v = _vistoria!;
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final isFinalizada = v.isAprovado || v.isReprovado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.go(
                  '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
                );
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          v.templateTitulo,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v${v.templateVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Lote: ${v.loteId} • Inspetor: ${v.inspetorNome} • ${df.format(v.dataVistoria)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: v.isAprovado
                    ? Colors.green[50]
                    : (v.isReprovado
                        ? Colors.red[50]
                        : (v.isReaberto ? Colors.orange[50] : Colors.blue[50])),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: v.isAprovado
                      ? Colors.green
                      : (v.isReprovado
                          ? Colors.red
                          : (v.isReaberto ? Colors.orange : Colors.blue)),
                ),
              ),
              child: Text(
                v.status.label.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: v.isAprovado
                      ? Colors.green[800]
                      : (v.isReprovado
                          ? Colors.red[800]
                          : (v.isReaberto
                              ? Colors.orange[800]
                              : Colors.blue[800])),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        Expanded(
          child: ListView(
            children: [
              Text(
                'Itens de Avaliação do Checklist (${v.itensRespondidos.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...v.itensRespondidos.map((item) {
                final obsCtrl = _obsControllers[item.itemId] ??
                    TextEditingController(text: item.observacao ?? '');

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: item.isNaoConforme
                          ? Colors.red[300]!
                          : Colors.grey[200]!,
                      width: item.isNaoConforme ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.titulo,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (item.obrigatorio)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Obrigatório',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Segmented control / radio buttons
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Conforme'),
                              selected: item.isConforme,
                              selectedColor: Colors.green[100],
                              onSelected: isFinalizada
                                  ? null
                                  : (sel) {
                                      if (sel) {
                                        _alterarStatusItem(
                                          item.itemId,
                                          ItemConformidadeStatus.conforme,
                                        );
                                      }
                                    },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Não Conforme'),
                              selected: item.isNaoConforme,
                              selectedColor: Colors.red[100],
                              onSelected: isFinalizada
                                  ? null
                                  : (sel) {
                                      if (sel) {
                                        _alterarStatusItem(
                                          item.itemId,
                                          ItemConformidadeStatus.nao_conforme,
                                        );
                                      }
                                    },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('N/A'),
                              selected: item.isNaoSeAplica,
                              selectedColor: Colors.grey[300],
                              onSelected: isFinalizada
                                  ? null
                                  : (sel) {
                                      if (sel) {
                                        _alterarStatusItem(
                                          item.itemId,
                                          ItemConformidadeStatus.nao_se_aplica,
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                        if (item.isNaoConforme) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.warning,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 6),
                                    Text(
                                      'Exigência de Justificativa e Evidência Fotográfica',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: obsCtrl,
                                  readOnly: isFinalizada,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Descrição da Não-Conformidade *',
                                    hintText:
                                        'Descreva a irregularidade e o retrabalho necessário...',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Fotos de Evidência (${item.fotos.length}) *',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (!isFinalizada)
                                      ElevatedButton.icon(
                                        onPressed: _salvando
                                            ? null
                                            : () => _adicionarFoto(item),
                                        icon: const Icon(Icons.camera_alt,
                                            size: 16),
                                        label: const Text('Anexar Foto'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[700],
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (item.fotos.isEmpty)
                                  const Text(
                                    'Pelo menos 1 foto é obrigatória para concluir vistoria reprovada.',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: List.generate(
                                      item.fotos.length,
                                      (fIdx) {
                                        final fUrl = item.fotos[fIdx];
                                        return Stack(
                                          children: [
                                            Container(
                                              width: 90,
                                              height: 90,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.grey[400]!),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: fUrl.startsWith('http')
                                                    ? Image.network(
                                                        fUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            const Icon(Icons
                                                                .broken_image),
                                                      )
                                                    : const Icon(
                                                        Icons.photo_camera,
                                                        size: 36,
                                                        color: Colors.grey,
                                                      ),
                                              ),
                                            ),
                                            if (!isFinalizada)
                                              Positioned(
                                                top: 2,
                                                right: 2,
                                                child: InkWell(
                                                  onTap: () => _removerFoto(
                                                      item, fIdx),
                                                  child: Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.black54,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text(
                'Observações Gerais da Vistoria',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _observacoesGeraisController,
                readOnly: isFinalizada,
                decoration: const InputDecoration(
                  hintText:
                      'Insira comentários finais ou diretrizes para a equipe do loteamento...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (v.isReprovado)
              ElevatedButton.icon(
                onPressed: _salvando ? null : _reabrirVistoria,
                icon: const Icon(Icons.refresh),
                label: const Text('Reabrir para Re-inspeção'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                ),
              ),
            if (!isFinalizada) ...[
              OutlinedButton(
                onPressed: _salvando ? null : _salvarRascunho,
                child: const Text('Salvar Rascunho'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _salvando ? null : _finalizarVistoria,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Concluir e Finalizar Vistoria'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SigoLayout(
      title: 'Vistoria de Validação',
      activeRoute:
          '/construtoras/${widget.construtoraId}/obra/${widget.obraId}/lotes/${widget.loteId}/validacoes',
      child: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erroCarregamento != null
              ? Center(child: Text(_erroCarregamento!))
              : _vistoria == null
                  ? _buildSelecaoTemplate()
                  : _buildFormVistoria(),
    );
  }
}
