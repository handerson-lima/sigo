import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BreadcrumbSegment {
  final String label;
  final String? url;

  const BreadcrumbSegment({required this.label, this.url});
}

class SigoBreadcrumbs extends StatelessWidget {
  const SigoBreadcrumbs({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final uri = state.uri;
    final pathSegments = uri.pathSegments;

    final List<BreadcrumbSegment> segments = [
      if (pathSegments.isNotEmpty && pathSegments[0] == 'construtoras')
        BreadcrumbSegment(label: 'Minhas Construtoras', url: '/'),
    ];
    String currentUrl = '';

    for (int i = 0; i < pathSegments.length; i++) {
      currentUrl += '/${pathSegments[i]}';

      if (pathSegments[i] == 'construtoras') {
        if (i + 1 < pathSegments.length) {
          final cid = pathSegments[i + 1];
          segments.add(
            BreadcrumbSegment(label: 'Construtora', url: '/construtoras/$cid'),
          );
        }
      } else if (pathSegments[i] == 'obra') {
        if (i + 1 < pathSegments.length) {
          segments.add(BreadcrumbSegment(label: 'Loteamento', url: currentUrl));
        } else {
          segments.add(BreadcrumbSegment(label: 'Loteamentos'));
        }
      } else if (pathSegments[i] == 'loteamentos') {
        if (i + 1 < pathSegments.length) {
          segments.add(BreadcrumbSegment(label: 'Loteamento', url: currentUrl));
        } else {
          segments.add(BreadcrumbSegment(label: 'Loteamentos'));
        }
      } else if (pathSegments[i] == 'quadras') {
        if (i + 1 < pathSegments.length) {
          segments.add(BreadcrumbSegment(label: 'Quadra', url: currentUrl));
        } else {
          segments.add(BreadcrumbSegment(label: 'Quadras'));
        }
      } else if (pathSegments[i] == 'lotes') {
        if (i + 1 < pathSegments.length) {
          segments.add(BreadcrumbSegment(label: 'Lote', url: currentUrl));
        } else {
          segments.add(BreadcrumbSegment(label: 'Lotes'));
        }
      } else if (pathSegments[i] == 'etapas') {
        if (i + 1 < pathSegments.length) {
          segments.add(BreadcrumbSegment(label: 'Etapa', url: currentUrl));
        } else {
          segments.add(BreadcrumbSegment(label: 'Etapas'));
        }
      } else if (pathSegments[i] == 'equipes') {
        if (i + 1 < pathSegments.length) {
          segments.add(BreadcrumbSegment(label: 'Equipe', url: currentUrl));
        } else {
          segments.add(BreadcrumbSegment(label: 'Equipes'));
        }
      }
    }

    if (segments.isNotEmpty) {
      final last = segments.last;
      segments[segments.length - 1] = BreadcrumbSegment(
        label: last.label,
        url: null,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: segments.asMap().entries.map((entry) {
          final index = entry.key;
          final segment = entry.value;
          final isLast = index == segments.length - 1;
          final theme = Theme.of(context);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: segment.url != null,
                label: segment.label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: (segment.url != null && !isLast)
                      ? () => context.go(segment.url!)
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      segment.label,
                      style: TextStyle(
                        color: isLast
                            ? theme.textTheme.bodyLarge?.color
                            : (segment.url != null
                                  ? theme.primaryColor
                                  : theme.disabledColor),
                        fontWeight: isLast
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text('/'),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
