import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/loteamentos_import_repository.dart';

class LoteamentoImportScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const LoteamentoImportScreen({
    super.key,
    required this.construtoraId,
  });

  @override
  ConsumerState<LoteamentoImportScreen> createState() => _LoteamentoImportScreenState();
}

class _LoteamentoImportScreenState extends ConsumerState<LoteamentoImportScreen> {
  late DropzoneViewController dropzoneController;
  bool isHighlighted = false;
  bool isUploading = false;

  Future<void> _uploadFileBytes(Uint8List bytes, String name) async {
    setState(() => isUploading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final repo = ref.read(loteamentosImportRepositoryProvider);
      final draftId = await repo.uploadDxf(
        userId: user.uid,
        fileBytes: bytes,
        filename: name,
      );

      if (mounted) {
        context.go('/construtoras/${widget.construtoraId}/loteamentos/import/processing/$draftId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no upload: $e')),
        );
        setState(() => isUploading = false);
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['dxf'],
    );

    if (result.isNotEmpty) {
      final file = result.first;
      final bytes = await file.xFile.readAsBytes();
      await _uploadFileBytes(bytes, file.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Loteamento (DXF)'),
      ),
      body: Center(
        child: isUploading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Enviando arquivo...'),
                ],
              )
            : Container(
                width: 600,
                height: 400,
                decoration: BoxDecoration(
                  color: isHighlighted ? Colors.blue.withValues(alpha: 0.1) : Colors.grey[100],
                  border: Border.all(
                    color: isHighlighted ? Colors.blue : Colors.grey,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    DropzoneView(
                      operation: DragOperation.copy,
                      cursor: CursorType.grab,
                      onCreated: (controller) => dropzoneController = controller,
                      onHover: () => setState(() => isHighlighted = true),
                      onLeave: () => setState(() => isHighlighted = false),
                      onDropFile: (dynamic ev) async {
                        setState(() => isHighlighted = false);
                        final name = await dropzoneController.getFilename(ev);
                        final bytes = await dropzoneController.getFileData(ev);
                        if (!name.toLowerCase().endsWith('.dxf')) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, envie um arquivo .dxf')),
                            );
                          }
                          return;
                        }
                        await _uploadFileBytes(bytes, name);
                      },
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_upload, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Arraste e solte o arquivo .dxf aqui',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Selecionar Arquivo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
