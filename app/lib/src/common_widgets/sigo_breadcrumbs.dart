import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BreadcrumbSegment {
  final String label;
  final String? url;

  const BreadcrumbSegment({required this.label, this.url});
}

class SigoBreadcrumbs extends StatelessWidget {
  final List<BreadcrumbSegment> segments;

  const SigoBreadcrumbs({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: segments.asMap().entries.map((entry) {
          final index = entry.key;
          final segment = entry.value;
          final isLast = index == segments.length - 1;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: (segment.url != null && !isLast)
                    ? () => context.go(segment.url!)
                    : null,
                child: Text(
                  segment.label,
                  style: TextStyle(
                    color: isLast ? Colors.black : Theme.of(context).primaryColor,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (!isLast) const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Text('/')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
