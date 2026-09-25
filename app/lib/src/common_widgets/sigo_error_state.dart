import 'package:flutter/material.dart';

class SigoErrorState extends StatelessWidget {
  final String message;
  final Object? cause;
  final VoidCallback onRetry;
  final String retryLabel;

  const SigoErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.cause,
    this.retryLabel = 'Tentar novamente',
  });

  String? get _causeSummary {
    if (cause == null) return null;
    final text = cause.toString().replaceAll('\n', ' ').trim();
    if (text.isEmpty) return null;
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _causeSummary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (resumo != null) ...[
              const SizedBox(height: 8),
              Text(
                resumo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
