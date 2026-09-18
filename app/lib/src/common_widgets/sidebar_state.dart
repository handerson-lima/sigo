import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controla se a barra lateral do SIGO está recolhida (compacta, exibindo apenas ícones)
/// em resoluções de desktop e tablet.
final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(SidebarCollapsedNotifier.new);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void setCollapsed(bool value) => state = value;
}
