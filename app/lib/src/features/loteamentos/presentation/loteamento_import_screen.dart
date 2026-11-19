import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/loteamento_repository.dart';
import '../data/loteamentos_import_repository.dart';
import '../domain/loteamento.dart';

enum ImportDestinationMode { novoLoteamento, loteamentoExistente }

typedef ImportFilesPicker = Future<List<ImportUploadFile>> Function();

class LoteamentoImportScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  /// Seam opcional para injetar seleção de arquivos em testes de widget.
  final ImportFilesPicker? pickFilesOverride;

  /// Permite desabilitar a criação do `DropzoneView` (Web) em testes.
  final bool enableDropzone;

  const LoteamentoImportScreen({
    super.key,
    required this.construtoraId,
    this.pickFilesOverride,
    this.enableDropzone = kIsWeb,
  });

  @override
  ConsumerState<LoteamentoImportScreen> createState() =>
      _LoteamentoImportScreenState();
}

class _LoteamentoImportScreenState
    extends ConsumerState<LoteamentoImportScreen> {
  DropzoneViewController? _dropzoneController;
  bool _isHighlighted = false;
  bool _isUploading = false;

  ImportDestinationMode _destinationMode = ImportDestinationMode.novoLoteamento;
  String? _selectedLoteamentoId;
  final List<ImportUploadFile> _selectedFiles = [];

  void _addFiles(List<ImportUploadFile> incoming) {
    final invalidNames = <String>[];
    final validFiles = <ImportUploadFile>[];

    for (final file in incoming) {
      if (LoteamentosImportRepository.loteamentoNameFromFilename(
            file.filename,
          ) ==
          null) {
        invalidNames.add(file.filename);
      } else {
        validFiles.add(file);
      }
    }

    if (invalidNames.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arquivo(s) não suportado(s): ${invalidNames.join(', ')}. '
            'Envie arquivos .pdf, .dxf ou .dwf.',
          ),
        ),
      );
    }

    if (validFiles.isEmpty) return;

    setState(() {
      _selectedFiles.addAll(validFiles);
    });
  }

  Future<void> _pickFiles() async {
    if (widget.pickFilesOverride != null) {
      final picked = await widget.pickFilesOverride!();
      if (!mounted) return;
      _addFiles(picked);
      return;
    }

    // Em file_picker >= 13.x, `FilePicker.pickFiles` (plural) já habilita
    // seleção múltipla nativamente (o parâmetro `allowMultiple` foi removido).
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'dxf', 'dwf'],
    );

    if (result.isEmpty) return;

    final loaded = <ImportUploadFile>[];
    for (final file in result) {
      final bytes = await file.xFile.readAsBytes();
      loaded.add(ImportUploadFile(bytes: bytes, filename: file.name));
    }

    if (!mounted) return;
    _addFiles(loaded);
  }

  Future<void> _submitUpload(List<Loteamento> loteamentos) async {
    if (_selectedFiles.isEmpty) return;

    if (_destinationMode == ImportDestinationMode.loteamentoExistente &&
        (_selectedLoteamentoId == null ||
            _selectedLoteamentoId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione um loteamento existente para mesclar os dados.',
          ),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      String? targetLoteamentoId;
      String? loteamentoNameOverride;
      if (_destinationMode == ImportDestinationMode.loteamentoExistente) {
        targetLoteamentoId = _selectedLoteamentoId;
        for (final loteamento in loteamentos) {
          if (loteamento.id == targetLoteamentoId) {
            loteamentoNameOverride = loteamento.name;
            break;
          }
        }
      }

      final repo = ref.read(loteamentosImportRepositoryProvider);
      final draftId = await repo.uploadFiles(
        userId: user.uid,
        construtoraId: widget.construtoraId,
        files: List<ImportUploadFile>.unmodifiable(_selectedFiles),
        targetLoteamentoId: targetLoteamentoId,
        loteamentoNameOverride: loteamentoNameOverride,
      );

      if (mounted) {
        context.go(
          '/construtoras/${widget.construtoraId}/loteamentos/import/processing/$draftId',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
        setState(() => _isUploading = false);
      }
    }
  }

  IconData _iconForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.architecture_outlined;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final loteamentosAsync = ref.watch(
      watchLoteamentosProvider((construtoraId: widget.construtoraId)),
    );
    final loteamentos = loteamentosAsync.asData?.value ?? const <Loteamento>[];

    final effectiveSelectedLoteamentoId =
        loteamentos.any((l) => l.id == _selectedLoteamentoId)
            ? _selectedLoteamentoId
            : null;

    final canSubmit =
        !_isUploading &&
        _selectedFiles.isNotEmpty &&
        (_destinationMode == ImportDestinationMode.novoLoteamento ||
            effectiveSelectedLoteamentoId != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Loteamento (PDF, DXF ou DWF)'),
      ),
      body: Center(
        child: _isUploading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFiles.length == 1
                        ? 'Enviando arquivo...'
                        : 'Enviando ${_selectedFiles.length} arquivos para o mesmo rascunho...',
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '1. Destino da Importação',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              SegmentedButton<ImportDestinationMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ImportDestinationMode.novoLoteamento,
                                    icon: Icon(Icons.add_business_outlined),
                                    label: Text('Novo Loteamento'),
                                  ),
                                  ButtonSegment(
                                    value: ImportDestinationMode
                                        .loteamentoExistente,
                                    icon: Icon(Icons.merge_type_outlined),
                                    label: Text('Mesclar em Existente'),
                                  ),
                                ],
                                selected: {_destinationMode},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    _destinationMode = selection.first;
                                  });
                                },
                              ),
                              if (_destinationMode ==
                                  ImportDestinationMode
                                      .loteamentoExistente) ...[
                                const SizedBox(height: 16),
                                loteamentosAsync.when(
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (err, _) => Text(
                                    'Erro ao carregar loteamentos: $err',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                  data: (items) {
                                    if (items.isEmpty) {
                                      return const Text(
                                        'Nenhum loteamento cadastrado ainda. Escolha "Novo Loteamento".',
                                      );
                                    }
                                    return DropdownButtonFormField<String>(
                                      initialValue:
                                          effectiveSelectedLoteamentoId,
                                      decoration: const InputDecoration(
                                        labelText: 'Loteamento de destino',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: items
                                          .map(
                                            (l) => DropdownMenuItem(
                                              value: l.id,
                                              child: Text(l.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedLoteamentoId = value;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '2. Arquivos do Projeto (1 PDF, PDF Multipágina, Múltiplos PDFs, DXF ou DWF)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                constraints: const BoxConstraints(
                                  minHeight: 240,
                                ),
                                decoration: BoxDecoration(
                                  color: _isHighlighted
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Colors.grey[100],
                                  border: Border.all(
                                    color: _isHighlighted
                                        ? Colors.blue
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  children: [
                                    if (widget.enableDropzone)
                                      Positioned.fill(
                                        child: DropzoneView(
                                          operation: DragOperation.copy,
                                          cursor: CursorType.grab,
                                          onCreated: (controller) =>
                                              _dropzoneController = controller,
                                          onHover: () => setState(
                                            () => _isHighlighted = true,
                                          ),
                                          onLeave: () => setState(
                                            () => _isHighlighted = false,
                                          ),
                                          onDropFile: (dynamic ev) async {
                                            setState(
                                              () => _isHighlighted = false,
                                            );
                                            final controller =
                                                _dropzoneController;
                                            if (controller == null) return;
                                            final name = await controller
                                                .getFilename(ev);
                                            final bytes = await controller
                                                .getFileData(ev);
                                            if (!mounted) return;
                                            _addFiles([
                                              ImportUploadFile(
                                                bytes: bytes,
                                                filename: name,
                                              ),
                                            ]);
                                          },
                                        ),
                                      ),
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 20,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.cloud_upload_outlined,
                                              size: 52,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Arraste arquivos .pdf, .dxf ou .dwf aqui',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Você pode selecionar vários PDFs para combinar no mesmo rascunho.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black54,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 12),
                                            ElevatedButton.icon(
                                              onPressed: _pickFiles,
                                              icon: const Icon(
                                                Icons.folder_open,
                                              ),
                                              label: Text(
                                                _selectedFiles.isEmpty
                                                    ? 'Selecionar Arquivos'
                                                    : 'Adicionar Mais Arquivos',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedFiles.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Arquivos selecionados (${_selectedFiles.length})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _selectedFiles.clear());
                                      },
                                      child: const Text('Limpar lista'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 8),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _selectedFiles.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final file = _selectedFiles[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        _iconForFilename(file.filename),
                                      ),
                                      title: Text(file.filename),
                                      subtitle: Text(
                                        _formatBytes(file.bytes.length),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close),
                                        tooltip: 'Remover arquivo',
                                        onPressed: () {
                                          setState(() {
                                            _selectedFiles.removeAt(index);
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: canSubmit
                            ? () => _submitUpload(loteamentos)
                            : null,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Enviar e Extrair Dados'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
