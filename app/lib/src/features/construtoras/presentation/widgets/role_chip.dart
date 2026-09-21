import 'package:flutter/material.dart';

/// Papel exibido no chip (tokens do DESIGN.md).
enum PapelChip { proprietario, administrador, operario, pendente }

/// Chip de papel com ícone + texto, `r=12`, borda 1px, padding 8h/4v.
///
/// Tokens (DESIGN.md):
/// - Proprietário: âmbar `#FEF3C7`/`#F59E0B`/`#92400E`, `stars_rounded`.
/// - Administrador: azul `#EFF6FF`/`#BFDBFE`/`#1E40AF`, `admin_panel_settings`.
/// - Operário: neutro, `person`.
/// - Pendente: laranja `#FFF7ED`/`#FDBA74`/`#9A3412`, `hourglass_top_rounded`.
class RoleChip extends StatelessWidget {
  final PapelChip papel;
  final String label;

  const RoleChip({super.key, required this.papel, required this.label});

  factory RoleChip.proprietario() => const RoleChip(
        papel: PapelChip.proprietario,
        label: 'Proprietário',
      );

  factory RoleChip.administrador() => const RoleChip(
        papel: PapelChip.administrador,
        label: 'Administrador',
      );

  factory RoleChip.operario() => const RoleChip(
        papel: PapelChip.operario,
        label: 'Operário',
      );

  factory RoleChip.pendente(String cargo) => RoleChip(
        papel: PapelChip.pendente,
        label: 'Pendente · $cargo',
      );

  /// Mapeia [Membro] (isOwner/isAdmin) para o chip da construtora.
  static PapelChip papelDe(bool isOwner, bool isAdmin) {
    if (isOwner) return PapelChip.proprietario;
    if (isAdmin) return PapelChip.administrador;
    return PapelChip.operario;
  }

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color border;
    late final Color ink;
    late final IconData icon;
    switch (papel) {
      case PapelChip.proprietario:
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFF59E0B);
        ink = const Color(0xFF92400E);
        icon = Icons.stars_rounded;
        break;
      case PapelChip.administrador:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        ink = const Color(0xFF1E40AF);
        icon = Icons.admin_panel_settings;
        break;
      case PapelChip.pendente:
        bg = const Color(0xFFFFF7ED);
        border = const Color(0xFFFDBA74);
        ink = const Color(0xFF9A3412);
        icon = Icons.hourglass_top_rounded;
        break;
      case PapelChip.operario:
        bg = Colors.grey.shade100;
        border = Colors.grey.shade300;
        ink = Colors.grey.shade800;
        icon = Icons.person;
        break;
    }
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
