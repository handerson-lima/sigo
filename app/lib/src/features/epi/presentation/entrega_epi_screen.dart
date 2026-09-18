import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../authentication/data/auth_repository.dart';
import '../../rh/data/rh_repository.dart';
import '../../rh/domain/funcionario.dart';
import '../data/epi_repository.dart';
import '../domain/epi_event.dart';
import '../domain/epi_item.dart';
import '../domain/termo_epi.dart';

class EntregaEpiScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String? preselectedFuncionarioId;

  const EntregaEpiScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    this.preselectedFuncionarioId,
  });

  @override
  ConsumerState<EntregaEpiScreen> createState() => _EntregaEpiScreenState();
}

class _EntregaEpiScreenState extends ConsumerState<EntregaEpiScreen> {
  final _formKey = GlobalKey<FormState>();
  Funcionario? _selectedFuncionario;
  EpiItem? _selectedEpi;
  int _quantidade = 1;
  String _motivo = 'Admissão';
  final _obsController = TextEditingController();
  final _justificativaCaController = TextEditingController();

  final List<Offset?> _signaturePoints = [];
  bool _isLoading = false;

  final List<String> _motivosPadrao = [
    'Admissão',
    'Substituição Periódica (Vida Útil)',
    'Desgaste / Dano Natural',
    'Dano Acidental',
    'Perda / Extravio',
    'Mudança de Função / Nova Atividade',
  ];

  @override
  void dispose() {
    _obsController.dispose();
    _justificativaCaController.dispose();
    super.dispose();
  }

  bool get _isCaExpirado => _selectedEpi != null && _selectedEpi!.isCaVencido;

  Future<Uint8List?> _renderSignatureToBytes() async {
    if (_signaturePoints.isEmpty) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 200);

      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      final paint = Paint()
        ..color = Colors.black87
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0;

      for (int i = 0; i < _signaturePoints.length - 1; i++) {
        if (_signaturePoints[i] != null && _signaturePoints[i + 1] != null) {
          canvas.drawLine(_signaturePoints[i]!, _signaturePoints[i + 1]!, paint);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _concluirEntrega() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFuncionario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um colaborador'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedEpi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um EPI do catálogo'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isCaExpirado && _justificativaCaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O C.A. deste EPI está vencido. É obrigatório registrar justificativa formal.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      final responsavelUid = user?.uid ?? 'sistema';
      final responsavelNome = user?.displayName ?? 'Usuário Responsável';

      final repo = ref.read(epiRepositoryProvider);
      final eventId = const Uuid().v4();
      final termoId = const Uuid().v4();

      final dataAgora = DateTime.now();
      final dataTrocaPrevista = _selectedEpi!.vidaUtilDias > 0
          ? dataAgora.add(Duration(days: _selectedEpi!.vidaUtilDias))
          : null;

      final event = EpiEvent(
        id: eventId,
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        funcionarioId: _selectedFuncionario!.id,
        funcionarioNome: _selectedFuncionario!.name,
        epiId: _selectedEpi!.id,
        epiNome: _selectedEpi!.nome,
        caNumero: _selectedEpi!.caNumero,
        tipoEvento: _motivo.startsWith('Substituição') ? 'substituicao' : 'entrega',
        quantidade: _quantidade,
        motivo: _isCaExpirado
            ? '$_motivo [C.A. Vencido Justificado: ${_justificativaCaController.text.trim()}]'
            : _motivo,
        dataEvento: dataAgora,
        responsavelUid: responsavelUid,
        responsavelNome: responsavelNome,
        termoId: termoId,
        status: 'ativo',
        dataTrocaPrevista: dataTrocaPrevista,
        observacoes: _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
      );

      final itensTermo = [
        {
          'epiNome': _selectedEpi!.nome,
          'caNumero': _selectedEpi!.caNumero,
          'quantidade': _quantidade,
          'dataEntrega': dataAgora.toIso8601String().split('T').first,
        }
      ];

      final termo = TermoEpi(
        id: termoId,
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        funcionarioId: _selectedFuncionario!.id,
        funcionarioNome: _selectedFuncionario!.name,
        funcionarioCpf: _selectedFuncionario!.cpf,
        itens: itensTermo,
        tipoConfirmacao: _signaturePoints.isNotEmpty ? 'assinatura_canvas' : 'confirmacao_presencial',
        dataAssinatura: dataAgora,
        responsavelUid: responsavelUid,
      );

      Uint8List? assinaturaBytes;
      if (_signaturePoints.isNotEmpty) {
        assinaturaBytes = await _renderSignatureToBytes();
      }

      await repo.registrarEntrega(
        event: event,
        termo: termo,
        assinaturaBytes: assinaturaBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EPI entregue e Termo de Responsabilidade gerado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar entrega: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final funcionariosAsync = ref.watch(funcionariosStreamProvider(widget.construtoraId));
    final episAsync = ref.watch(catalogoEpisStreamProvider(widget.construtoraId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrega de EPI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Colaborador Destinatário',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      funcionariosAsync.when(
                        data: (funcionarios) {
                          final ativos = funcionarios.where((f) => f.isActive).toList();

                          if (_selectedFuncionario == null && widget.preselectedFuncionarioId != null) {
                            final match = ativos.where((f) => f.id == widget.preselectedFuncionarioId);
                            if (match.isNotEmpty) {
                              _selectedFuncionario = match.first;
                            }
                          }

                          return DropdownButtonFormField<Funcionario>(
                            initialValue: _selectedFuncionario,
                            decoration: const InputDecoration(
                              labelText: 'Selecione o Colaborador *',
                              border: OutlineInputBorder(),
                            ),
                            items: ativos
                                .map((f) => DropdownMenuItem(
                                      value: f,
                                      child: Text('${f.name} (CPF: ${f.cpf}) • ${f.role}'),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedFuncionario = val),
                            validator: (v) => v == null ? 'Colaborador obrigatório' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erro ao carregar colaboradores: $err'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Equipamento (EPI) e Quantidade',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      episAsync.when(
                        data: (epis) {
                          final ativos = epis.where((e) => e.isActive).toList();
                          return DropdownButtonFormField<EpiItem>(
                            initialValue: _selectedEpi,
                            decoration: const InputDecoration(
                              labelText: 'Selecione o EPI do Catálogo *',
                              border: OutlineInputBorder(),
                            ),
                            items: ativos
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text('${e.nome} • C.A.: ${e.caNumero} (${e.categoriaFormatada})'),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedEpi = val),
                            validator: (v) => v == null ? 'EPI obrigatório' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Erro ao carregar catálogo: $err'),
                      ),
                      if (_selectedEpi != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Fabricante: ${_selectedEpi!.fabricante} • C.A.: ${_selectedEpi!.caNumero}'),
                            const SizedBox(width: 8),
                            _isCaExpirado
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red),
                                    ),
                                    child: const Text('C.A. EXPIRADO', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: const Text('C.A. VÁLIDO', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                          ],
                        ),
                      ],
                      if (_isCaExpirado) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade800),
                                  const SizedBox(width: 8),
                                  const Text('Atenção: Validade de C.A. Expirada', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'A entrega de EPI com C.A. expirado viola a NR-6 e só pode ser efetuada sob estrita justificativa formal de segurança.',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _justificativaCaController,
                                decoration: const InputDecoration(
                                  labelText: 'Justificativa de Segurança Obrigatória *',
                                  hintText: 'Ex: Lote fabricado durante vigência do CA com laudo técnico.',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  if (_isCaExpirado && (v == null || v.trim().isEmpty)) {
                                    return 'Justificativa obrigatória para C.A. vencido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _motivo,
                              decoration: const InputDecoration(labelText: 'Motivo da Entrega *'),
                              items: _motivosPadrao
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _motivo = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              initialValue: '1',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Quantidade *'),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n <= 0) return 'Qtd inválida';
                                return null;
                              },
                              onChanged: (v) => _quantidade = int.tryParse(v) ?? 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _obsController,
                        decoration: const InputDecoration(
                          labelText: 'Observações Adicionais',
                          hintText: 'Numeração, tamanho, detalhes de ajuste...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Termo de Responsabilidade (NR-6 / CLT)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          TermoEpi.termoPadraoNr6,
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Assinatura do Colaborador (Canvas Touch / Mouse):',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Limpar Assinatura'),
                            onPressed: () {
                              setState(() => _signaturePoints.clear());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                final renderBox = context.findRenderObject() as RenderBox?;
                                if (renderBox != null) {
                                  _signaturePoints.add(details.localPosition);
                                }
                              });
                            },
                            onPanEnd: (_) => _signaturePoints.add(null),
                            child: CustomPaint(
                              painter: _SignaturePainter(_signaturePoints),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '* O sistema gera o hash criptográfico SHA-256 do termo assinado para validação jurídica.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _concluirEntrega,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(
                  _isLoading ? 'Registrando...' : 'Confirmar Entrega e Assinatura do Termo',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
