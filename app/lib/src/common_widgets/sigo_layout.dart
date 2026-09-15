import 'package:flutter/material.dart';
import 'sigo_sidebar.dart';
import 'sigo_top_bar.dart';

class SigoLayout extends StatelessWidget {
  final String title;
  final String activeRoute;
  final Widget child;
  final List<Widget>? actions;

  const SigoLayout({
    super.key,
    required this.title,
    required this.activeRoute,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC), // Fundo claro da imagem
            body: Row(
              children: [
                SigoSidebar(activeRoute: activeRoute),
                Expanded(
                  child: Column(
                    children: [
                      SigoTopBar(title: title, actions: actions),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile / Tablet Portrait
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: SigoTopBar(title: title, actions: actions),
          drawer: SigoSidebar(activeRoute: activeRoute),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        );
      },
    );
  }
}
