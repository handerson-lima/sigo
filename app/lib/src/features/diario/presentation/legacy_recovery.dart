import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/diario.dart';
import '../data/diario_repository.dart';

class LegacyRecovery extends ConsumerWidget {
  final String c, o;
  const LegacyRecovery({super.key, required this.c, required this.o});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('construtoras/$c/obras/$o/diarios')
          .where('isPendingSync', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Não foi possível consultar pendências legadas deste loteamento.',
          );
        }
        final docs = (snapshot.data?.docs ?? []).where(
          (d) => d.data()['responsavelId'] == uid,
        );
        return Column(
          children: docs.map((doc) {
            final diario = DiarioObra.fromJson(doc.data());
            return ListTile(
              title: const Text('RDO legado: recuperação necessária'),
              subtitle: Text(
                '${diario.localPhotoPaths.length} arquivos devem ser selecionados no dispositivo que os possui. Nada será removido automaticamente.',
              ),
              trailing: TextButton(
                child: const Text('Recuperar arquivos'),
                onPressed: () async {
                  try {
                    final files = await ImagePicker().pickMultiImage();
                    if (files.isEmpty) return;
                    final expected =
                        diario.localPhotoPaths
                            .map((p) => p.replaceAll('\\', '/').split('/').last)
                            .toList()
                          ..sort();
                    final selected = files.map((f) => f.name).toList()..sort();
                    if (expected.length != selected.length ||
                        expected.asMap().entries.any(
                          (e) => e.value != selected[e.key],
                        )) {
                      throw StateError(
                        'Selecione todos os arquivos originais com os nomes registrados. Arquivo perdido exige recuperação manual.',
                      );
                    }
                    final photos = <Uint8List>[];
                    for (final file in files) {
                      photos.add(await file.readAsBytes());
                    }
                    await ref
                        .read(diarioRepositoryProvider)
                        .createDiario(diario, photos);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Arquivos preservados na fila local. Aguarde confirmação integral.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Não recuperado: $e')),
                      );
                    }
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
