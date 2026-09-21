import 'package:flutter/material.dart';

import 'role_chip.dart';

/// Linha do membro: avatar 40px por papel, title, subtitle
/// `Cargo · N obras`, trailing chip + chevron.
///
/// Reuso em 8.2/8.3. Acessibilidade: anuncia nome, cargo, N obras e status;
/// alvo mínimo 48dp (ListTile).
class MemberRow extends StatelessWidget {
  final String nome;
  final String subtitle;
  final String semanticsLabel;
  final PapelChip papel;
  final String chipLabel;
  final bool isPendente;
  final VoidCallback? onTap;

  const MemberRow({
    super.key,
    required this.nome,
    required this.subtitle,
    required this.semanticsLabel,
    required this.papel,
    required this.chipLabel,
    this.isPendente = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late final Color? avatarBg;
    late final IconData avatarIcon;
    late final Color? avatarIconColor;
    switch (papel) {
      case PapelChip.proprietario:
        avatarBg = Colors.amber.shade100;
        avatarIcon = Icons.stars_rounded;
        avatarIconColor = Colors.amber.shade900;
        break;
      case PapelChip.administrador:
        avatarBg = Colors.blue.shade50;
        avatarIcon = Icons.admin_panel_settings;
        avatarIconColor = Colors.blue.shade800;
        break;
      case PapelChip.pendente:
        avatarBg = Colors.orange.shade100;
        avatarIcon = Icons.hourglass_top_rounded;
        avatarIconColor = Colors.orange.shade700;
        break;
      case PapelChip.operario:
        avatarBg = null;
        avatarIcon = Icons.person;
        avatarIconColor = null;
        break;
    }

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: ListTile(
        minVerticalPadding: 8,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: avatarBg,
          child: Icon(avatarIcon, color: avatarIconColor),
        ),
        title: Text(
          nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ExcludeSemantics(
                  child: RoleChip(papel: papel, label: chipLabel),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
