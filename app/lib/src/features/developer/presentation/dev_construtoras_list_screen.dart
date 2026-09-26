import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../construtoras/domain/construtora.dart';

class DevConstrutorasListScreen extends StatefulWidget {
  const DevConstrutorasListScreen({super.key});

  @override
  State<DevConstrutorasListScreen> createState() =>
      _DevConstrutorasListScreenState();
}

class _DevConstrutorasListScreenState extends State<DevConstrutorasListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'Todas'; // 'Todas', 'Ativas', 'Inativas'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SigoLayout(
      activeRoute: '/dev',
      title: 'Gestão Global de Construtoras',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Construtoras Cadastradas',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const _AddConstrutoraDialog(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Construtora'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Barra de busca e filtros
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.toLowerCase()),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por Nome ou CNPJ',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Todas', label: Text('Todas')),
                    ButtonSegment(value: 'Ativas', label: Text('Ativas')),
                    ButtonSegment(value: 'Inativas', label: Text('Inativas')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _statusFilter = newSelection.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('construtoras')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }

                  var docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma construtora encontrada no banco de dados.',
                      ),
                    );
                  }

                  // Aplicar os filtros locais (client-side)
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] as String?)?.toLowerCase() ?? '';
                    final cnpj = (data['cnpj'] as String?)?.toLowerCase() ?? '';
                    final isActive = data['isActive'] == true;

                    // Filtro de status
                    if (_statusFilter == 'Ativas' && !isActive) return false;
                    if (_statusFilter == 'Inativas' && isActive) return false;

                    // Filtro de busca (nome ou cnpj)
                    if (_searchQuery.isNotEmpty) {
                      if (!name.contains(_searchQuery) &&
                          !cnpj.contains(_searchQuery)) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma construtora corresponde aos filtros.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = Map<String, dynamic>.from(
                        doc.data() as Map<String, dynamic>,
                      );
                      data['id'] = (data['id'] as String?)?.isNotEmpty == true
                          ? data['id']
                          : doc.id;
                      data['name'] =
                          (data['name'] as String?)?.isNotEmpty == true
                          ? data['name']
                          : doc.id;

                      if (data['createdAt'] is Timestamp) {
                        data['createdAt'] = (data['createdAt'] as Timestamp)
                            .toDate()
                            .toIso8601String();
                      }
                      if (data['updatedAt'] is Timestamp) {
                        data['updatedAt'] = (data['updatedAt'] as Timestamp)
                            .toDate()
                            .toIso8601String();
                      }

                      final construtora = Construtora.fromJson(data);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: construtora.isActive
                                ? Colors.orange.shade100
                                : Colors.grey.shade200,
                            backgroundImage: construtora.logoUrl != null
                                ? NetworkImage(construtora.logoUrl!)
                                : null,
                            child: construtora.logoUrl == null
                                ? Icon(
                                    Icons.business,
                                    color: construtora.isActive
                                        ? Colors.orange
                                        : Colors.grey,
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Text(
                                construtora.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: construtora.isActive
                                      ? null
                                      : Colors.grey,
                                  decoration: construtora.isActive
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (construtora.isActive)
                                const Chip(
                                  label: Text(
                                    'Ativa',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(color: Colors.white),
                                  visualDensity: VisualDensity.compact,
                                )
                              else
                                const Chip(
                                  label: Text(
                                    'Inativa',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.red,
                                  labelStyle: TextStyle(color: Colors.white),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          subtitle: Text(
                            'ID: ${construtora.id} | CNPJ: ${construtora.cnpj ?? 'N/A'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => _EditConstrutoraDialog(
                                construtora: construtora,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddConstrutoraDialog extends StatefulWidget {
  const _AddConstrutoraDialog();

  @override
  State<_AddConstrutoraDialog> createState() => _AddConstrutoraDialogState();
}

class _AddConstrutoraDialogState extends State<_AddConstrutoraDialog> {
  final _nameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _telefoneMask = MaskTextInputFormatter(mask: '## ####-####', filter: {"#": RegExp(r'[0-9]')});
  String? _logoUrl;
  bool _isSaving = false;
  late final String _construtoraId;

  @override
  void initState() {
    super.initState();
    _construtoraId = FirebaseFirestore.instance.collection('construtoras').doc().id;
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Logo',
            toolbarColor: Colors.orange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Recortar Logo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isSaving = true);
        try {
          final bytes = await croppedFile.readAsBytes();
          
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {},
          );
          final storageRef = FirebaseStorage.instance.ref().child('construtoras/$_construtoraId/logos/${DateTime.now().millisecondsSinceEpoch}_logo.jpg');
          
          await storageRef.putData(bytes, metadata);
          final url = await storageRef.getDownloadURL();
          
          setState(() {
            _logoUrl = url;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao fazer upload da logo: $e')));
          }
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final telefone = _telefoneController.text.trim();
    if (name.isEmpty) return;

    if (telefone.isNotEmpty && telefone.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O telefone deve estar completo no formato ## ####-####')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('construtoras')
          .doc(_construtoraId);
      final data = {
        'id': docRef.id,
        'name': name,
        'cnpj': _cnpjController.text.trim(),
        'telefone': telefone.isNotEmpty ? telefone : null,
        'logoUrl': _logoUrl,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      final ownerEmail = _ownerEmailController.text.trim();
      if (ownerEmail.isNotEmpty) {
        await FirebaseFunctions.instance
            .httpsCallable('setConstrutoraRole')
            .call({
              'email': ownerEmail,
              'construtoraId': docRef.id,
              'role': 'owner',
              'isOwner': true,
            });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    _ownerEmailController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Construtora'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _isSaving ? null : _pickLogo,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                    child: _logoUrl == null ? const Icon(Icons.add_a_photo, color: Colors.grey) : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Construtora',
                    ),
                    autofocus: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _telefoneController,
              inputFormatters: [_telefoneMask],
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone (WhatsApp)', hintText: '84 9999-9999'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cnpjController,
              decoration: const InputDecoration(labelText: 'CNPJ (opcional)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ownerEmailController,
              decoration: const InputDecoration(
                labelText: 'E-mail do Proprietário inicial (opcional)',
                hintText: 'ex: socio@construtora.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
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

class _EditConstrutoraDialog extends StatefulWidget {
  final Construtora construtora;
  const _EditConstrutoraDialog({required this.construtora});

  @override
  State<_EditConstrutoraDialog> createState() => _EditConstrutoraDialogState();
}

class _EditConstrutoraDialogState extends State<_EditConstrutoraDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cnpjController;
  late final TextEditingController _telefoneController;
  final _telefoneMask = MaskTextInputFormatter(mask: '## ####-####', filter: {"#": RegExp(r'[0-9]')});
  String? _logoUrl;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.construtora.name);
    _cnpjController = TextEditingController(
      text: widget.construtora.cnpj ?? '',
    );
    _telefoneController = TextEditingController(
      text: widget.construtora.telefone ?? '',
    );
    _logoUrl = widget.construtora.logoUrl;
    _isActive = widget.construtora.isActive;
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Logo',
            toolbarColor: Colors.orange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Recortar Logo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isSaving = true);
        try {
          final bytes = await croppedFile.readAsBytes();
          
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {},
          );
          final storageRef = FirebaseStorage.instance.ref().child('construtoras/${widget.construtora.id}/logos/${DateTime.now().millisecondsSinceEpoch}_logo.jpg');
          
          await storageRef.putData(bytes, metadata);
          final url = await storageRef.getDownloadURL();
          
          setState(() {
            _logoUrl = url;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao fazer upload da logo: $e')));
          }
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final telefone = _telefoneController.text.trim();
    if (name.isEmpty) return;

    if (telefone.isNotEmpty && telefone.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O telefone deve estar completo no formato ## ####-####')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('construtoras')
          .doc(widget.construtora.id);
      await docRef.update({
        'name': name,
        'cnpj': _cnpjController.text.trim(),
        'telefone': telefone.isNotEmpty ? telefone : null,
        'logoUrl': _logoUrl,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isActive
                  ? 'Construtora ativada com sucesso.'
                  : 'Construtora inativada com sucesso.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Construtora'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _isSaving ? null : _pickLogo,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                    child: _logoUrl == null ? const Icon(Icons.add_a_photo, color: Colors.grey) : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Construtora',
                    ),
                    autofocus: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _telefoneController,
              inputFormatters: [_telefoneMask],
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone (WhatsApp)', hintText: '84 9999-9999'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cnpjController,
              decoration: const InputDecoration(labelText: 'CNPJ (opcional)'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Construtora Ativa'),
              subtitle: const Text(
                'Desativar suspende o acesso globalmente no app.',
              ),
              value: _isActive,
              onChanged: (val) {
                setState(() => _isActive = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
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
