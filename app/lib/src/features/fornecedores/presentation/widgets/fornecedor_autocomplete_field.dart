import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/fornecedores_repository.dart';
import '../../domain/fornecedor.dart';

/// Campo de autocomplete inteligente e reutilizável para seleção de fornecedores.
///
/// Integra busca rápida por Razão Social, Nome Fantasia e CNPJ/CPF,
/// filtrando prioritariamente fornecedores ativos da construtora.
class FornecedorAutocompleteField extends ConsumerWidget {
  final String construtoraId;
  final String? initialValue;
  final ValueChanged<Fornecedor> onSelected;
  final String labelText;
  final String hintText;
  final bool apenasAtivos;
  final bool required;

  const FornecedorAutocompleteField({
    super.key,
    required this.construtoraId,
    required this.onSelected,
    this.initialValue,
    this.labelText = 'Fornecedor / Prestador de Serviço',
    this.hintText = 'Digite a razão social, fantasia ou CNPJ/CPF...',
    this.apenasAtivos = true,
    this.required = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fornecedoresAsync = ref.watch(
      fornecedoresStreamProvider(
        (construtoraId: construtoraId, apenasAtivos: apenasAtivos),
      ),
    );

    return fornecedoresAsync.when(
      loading: () => TextFormField(
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          prefixIcon: const SizedBox(
            width: 20,
            height: 20,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        enabled: false,
      ),
      error: (err, _) => TextFormField(
        decoration: InputDecoration(
          labelText: labelText,
          hintText: 'Erro ao carregar lista de fornecedores',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.error_outline, color: Colors.red),
        ),
      ),
      data: (fornecedores) {
        return Autocomplete<Fornecedor>(
          initialValue: initialValue != null && initialValue!.isNotEmpty
              ? TextEditingValue(text: initialValue!)
              : null,
          displayStringForOption: (Fornecedor f) => f.nomeExibicao,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return fornecedores.take(8);
            }
            final query = textEditingValue.text.toLowerCase();
            return fornecedores.where((Fornecedor f) {
              final razao = f.razaoSocial.toLowerCase();
              final fantasia = (f.nomeFantasia ?? '').toLowerCase();
              final doc = f.documento;
              return razao.contains(query) ||
                  fantasia.contains(query) ||
                  doc.contains(query);
            });
          },
          onSelected: onSelected,
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: required ? '$labelText *' : labelText,
                hintText: hintText,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.business),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                  tooltip: 'Cadastrar Novo Fornecedor',
                  onPressed: () {
                    context.push(
                      '/construtoras/$construtoraId/fornecedores/novo',
                    );
                  },
                ),
              ),
              validator: required
                  ? (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Selecione ou informe o fornecedor.';
                      }
                      return null;
                    }
                  : null,
            );
          },
          optionsViewBuilder: (context, onAutoCompleteSelect, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final Fornecedor f = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          f.isPessoaJuridica
                              ? Icons.business
                              : Icons.person_outline,
                          size: 20,
                          color: f.isAtivo ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          f.nomeExibicao,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${f.isPessoaJuridica ? "CNPJ" : "CPF"}: ${f.documentoFormatado}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: f.dadosBancarios?.chavePix != null &&
                                f.dadosBancarios!.chavePix!.isNotEmpty
                            ? const Icon(Icons.pix, size: 14, color: Colors.teal)
                            : null,
                        onTap: () {
                          onAutoCompleteSelect(f);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
