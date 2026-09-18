import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/diario_repository.dart';
import '../domain/diario.dart';
import '../../../common/services/geolocation_service.dart';
import '../../../common/services/watermark_service.dart';

class AddDiarioScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;

  const AddDiarioScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
  });

  @override
  ConsumerState<AddDiarioScreen> createState() => _AddDiarioScreenState();
}

class _AddDiarioScreenState extends ConsumerState<AddDiarioScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  WeatherCondition _weather = WeatherCondition.sol;
  final _obsController = TextEditingController();
  bool _isLoading = false;

  final List<EfetivoEntry> _efetivoList = [];
  final _roleController = TextEditingController();
  final _countController = TextEditingController();

  final List<Uint8List> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessingPhoto = false;

  Future<void> _pickPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _isProcessingPhoto = true);

      try {
        final watermarkService = ref.read(watermarkServiceProvider);
        final geoService = ref.read(geolocationServiceProvider);
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'offline_user';

        final stampedBytes = await watermarkService.stampPhoto(
          imageBytes: bytes,
          obraId: widget.obraId,
          responsavelId: uid,
          geolocationService: geoService,
        );

        if (!mounted) return;
        setState(() {
          _selectedPhotos.add(stampedBytes);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _selectedPhotos.add(bytes);
        });
      } finally {
        if (mounted) {
          setState(() => _isProcessingPhoto = false);
        }
      }
    }
  }

  void _addEfetivo() {
    final role = _roleController.text.trim();
    final count = int.tryParse(_countController.text) ?? 0;
    if (role.isNotEmpty && count > 0) {
      setState(() {
        _efetivoList.add(EfetivoEntry(role: role, count: count));
      });
      _roleController.clear();
      _countController.clear();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final diario = DiarioObra(
        id: const Uuid().v4(),
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        date: _selectedDate,
        weather: _weather,
        efetivo: _efetivoList,
        observacoes: _obsController.text,
        responsavelId: uid,
        createdAt: DateTime.now(),
      );

      await ref
          .read(diarioRepositoryProvider)
          .createDiario(diario, _selectedPhotos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Salvo neste dispositivo. Acompanhe a confirmação na fila.',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SigoLayout(
      title: 'Novo RDO',
      activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/diarios',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // 1. Data e Clima
                  ListTile(
                    title: Text(
                      'Data: ${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _selectedDate = d);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WeatherCondition>(
                    initialValue: _weather,
                    decoration: const InputDecoration(
                      labelText: 'Clima do Dia',
                    ),
                    items: WeatherCondition.values.map((w) {
                      return DropdownMenuItem(value: w, child: Text(w.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _weather = val);
                    },
                  ),
                  const Divider(height: 32),

                  // 2. Efetivo
                  const Text(
                    'Efetivo (Mão de Obra)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _roleController,
                          decoration: const InputDecoration(
                            labelText: 'Função (Ex: Pedreiro)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qtd'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _addEfetivo,
                      ),
                    ],
                  ),
                  if (_efetivoList.isNotEmpty)
                    Column(
                      children: _efetivoList
                          .map(
                            (e) => ListTile(
                              title: Text(e.role),
                              trailing: Text(e.count.toString()),
                            ),
                          )
                          .toList(),
                    ),
                  const Divider(height: 32),

                  // 3. Observações
                  TextFormField(
                    controller: _obsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Atividades e Observações do Dia',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Divider(height: 32),

                  // 4. Fotos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fotos do Canteiro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _isProcessingPhoto
                          ? const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Carimbando...',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            )
                          : TextButton.icon(
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Anexar'),
                            ),
                    ],
                  ),
                  if (_selectedPhotos.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedPhotos.length,
                        itemBuilder: (ctx, i) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Image.memory(
                            _selectedPhotos[i],
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Salvar Relatório Diário',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
