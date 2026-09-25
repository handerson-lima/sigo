import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/despesas_adm_repository.dart';
import '../domain/despesa_adm.dart';

class DespesaLiquidarDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final DespesaAdm despesa;
  final int? numeroParcela;
  final String userUid;

  const DespesaLiquidarDialog({
    super.key,
    required this.construtoraId,
    required this.obraId,
    required this.despesa,
    this.numeroParcela,
    required this.userUid,
  });

  @override
  ConsumerState<DespesaLiquidarDialog> createState() =>
      _DespesaLiquidarDialogState();
}

class _DespesaLiquidarDialogState extends ConsumerState<DespesaLiquidarDialog> {
  MetodoPagamento _metodo = MetodoPagamento.pix;
  DateTime _dataPagamento = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  Uint8List? _fileBytes;
  String? _fileName;

  Future<void> _pickFile() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _fileBytes = bytes;
          _fileName = image.name;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao selecionar comprovante: $e';
      });
    }
  }

  Future<void> _confirmarLiquidacao() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(despesasAdmRepositoryProvider);
      String? comprovanteUrl;
      String? comprovantePath;

      if (_fileBytes != null && _fileName != null) {
        final contentType = _fileName!.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : 'image/jpeg';

        final uploadResult = await repo.uploadComprovante(
          construtoraId: widget.construtoraId,
          obraId: widget.obraId,
          despesaId: widget.despesa.id,
          nomeArquivo: _fileName!,
          bytes: _fileBytes!,
          contentType: contentType,
        );
        comprovanteUrl = uploadResult.url;
        comprovantePath = uploadResult.path;
      }

      if (widget.numeroParcela != null) {
        await repo.liquidarParcela(
          construtoraId: widget.construtoraId,
          obraId: widget.obraId,
          despesaId: widget.despesa.id,
          numeroParcela: widget.numeroParcela!,
          pagoPorUid: widget.userUid,
          metodoPagamento: _metodo,
          dataPagamento: _dataPagamento,
          comprovanteUrl: comprovanteUrl,
          comprovantePath: comprovantePath,
        );
      } else {
        await repo.liquidarDespesa(
          construtoraId: widget.construtoraId,
          obraId: widget.obraId,
          despesaId: widget.despesa.id,
          pagoPorUid: widget.userUid,
          metodoPagamento: _metodo,
          dataPagamento: _dataPagamento,
          comprovanteUrl: comprovanteUrl,
          comprovantePath: comprovantePath,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao liquidar despesa: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final int valorCents = widget.numeroParcela != null
        ? widget.despesa.parcelas
              .firstWhere((p) => p.numero == widget.numeroParcela)
              .valorCents
        : widget.despesa.saldoDevedorCents;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Text('Confirmar Liquidação'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.despesa.descricao,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.numeroParcela != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Parcela ${widget.numeroParcela} de ${widget.despesa.parcelas.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Card com valor a pagar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valor da Liquidação:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                  ),
                  Text(
                    currency.format(valorCents / 100.0),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Forma de pagamento
            const Text(
              'Método de Pagamento:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<MetodoPagamento>(
              initialValue: _metodo,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: MetodoPagamento.values.map((m) {
                return DropdownMenuItem(value: m, child: Text(m.label));
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (val) {
                      if (val != null) setState(() => _metodo = val);
                    },
            ),
            const SizedBox(height: 16),

            // Data de quitação
            const Text(
              'Data do Pagamento:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _isLoading
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dataPagamento,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _dataPagamento = picked);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateFormat.format(_dataPagamento)),
                    const Icon(Icons.calendar_today, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Anexo de comprovante
            const Text(
              'Comprovante Bancário / Recibo (opcional):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _fileName != null
                    ? 'Arquivo: $_fileName'
                    : 'Anexar Comprovante / Foto',
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmarLiquidacao,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmar Pagamento'),
        ),
      ],
    );
  }
}
