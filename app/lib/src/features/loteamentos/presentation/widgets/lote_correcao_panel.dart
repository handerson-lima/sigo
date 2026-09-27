import 'package:flutter/material.dart';

class LoteCorrecaoPanel extends StatefulWidget {
  final Map<String, dynamic> properties;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  const LoteCorrecaoPanel({
    super.key,
    required this.properties,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<LoteCorrecaoPanel> createState() => _LoteCorrecaoPanelState();
}

class _LoteCorrecaoPanelState extends State<LoteCorrecaoPanel> {
  late TextEditingController _nameController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.properties['nome'] as String? ?? '');
    // Auto-focus after the widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant LoteCorrecaoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.properties != widget.properties) {
      final newText = widget.properties['nome'] as String? ?? '';
      _nameController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome/número do lote é obrigatório.')),
      );
      return;
    }
    widget.onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.properties['status'] as String? ?? 'desconhecido';
    final tipo = widget.properties['tipo'] as String? ?? 'lote';
    final isQuadra = tipo == 'quadra';
    final isReparada = widget.properties['geometria_reparada'] == true;

    return Container(
      width: 300,
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isQuadra ? 'Confirmar Quadra' : 'Corrigir Lote',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Status atual: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (isQuadra && isReparada) ...[
            const SizedBox(height: 16),
            const Text('A geometria desta quadra precisou ser recuperada. Por favor, verifique visualmente se as partes no canvas estão corretas e confirme.', style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(widget.properties['nome'] as String? ?? '');
                },
                child: const Text('Confirmar Geometria'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                labelText: 'Nome/Número do Lote',
                border: OutlineInputBorder(),
                helperText: 'Pressione ENTER para salvar',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Salvar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
