import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'cineva_buttons.dart';
import 'cineva_pressable.dart';

/// Ouvre une bottom sheet Cineva (scale + fade, surface modale, poignée).
Future<T?> showCinevaSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: CinevaColors.scrimMedium,
    elevation: 0,
    useSafeArea: true,
    showDragHandle: false,
  );
}

/// Conteneur de bottom sheet : poignée, titre optionnel, contenu.
class CinevaSheetContainer extends StatelessWidget {
  const CinevaSheetContainer({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.maxHeightFraction = 0.86,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
      decoration: const BoxDecoration(
        color: CinevaColors.modal,
        borderRadius: CinevaRadii.sheetBorder,
        boxShadow: CinevaShadows.modal,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(CinevaRadii.chip),
              ),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CinevaSpacing.lg,
                0,
                CinevaSpacing.lg,
                CinevaSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title!, style: CinevaTypography.sectionTitle.copyWith(fontSize: 18)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: CinevaTypography.bodyCompact),
                  ],
                ],
              ),
            ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Option sélectionnable dans une sheet (audio, sous-titres, qualité, vitesse).
class CinevaSheetOption<T> extends StatelessWidget {
  const CinevaSheetOption({
    super.key,
    required this.value,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.subtitle,
    this.enabled = true,
    this.trailing,
  });

  final T value;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final ValueChanged<T> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? CinevaColors.gold : CinevaColors.textHigh;

    return CinevaPressable(
      enabled: enabled,
      pressedScale: 0.99,
      onTap: enabled ? () => onSelected(value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinevaSpacing.lg,
          vertical: CinevaSpacing.sm + 2,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              child: selected
                  ? const Icon(Icons.check_rounded, size: 18, color: CinevaColors.gold)
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: CinevaTypography.cardTitle.copyWith(fontSize: 14.5, color: foreground),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: CinevaTypography.bodyCompact.copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Action plein largeur dans une sheet (menu d'actions rapides).
class CinevaSheetAction extends StatelessWidget {
  const CinevaSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tone = CinevaButtonTone.neutral,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final CinevaButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      CinevaButtonTone.neutral => CinevaColors.textHigh,
      CinevaButtonTone.gold => CinevaColors.gold,
      CinevaButtonTone.danger => CinevaColors.danger,
    };

    return CinevaPressable(
      pressedScale: 0.99,
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinevaSpacing.lg,
          vertical: CinevaSpacing.sm + 1,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CinevaColors.raised,
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: CinevaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: CinevaTypography.cardTitle.copyWith(fontSize: 14.5),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: CinevaTypography.bodyCompact.copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog Cineva : scale + fade, surface modale, actions alignées à droite.
class CinevaDialog extends StatelessWidget {
  const CinevaDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmer',
    this.cancelLabel = 'Annuler',
    this.onConfirm,
    this.onCancel,
    this.icon,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final bool destructive;

  /// Ouvre la dialog avec une animation scale + fade.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    IconData? icon,
    bool destructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierColor: CinevaColors.scrimMedium,
      builder: (BuildContext context) => CinevaDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        destructive: destructive,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Color confirmColor = destructive ? CinevaColors.danger : CinevaColors.gold;

    return Dialog(
      backgroundColor: CinevaColors.modal,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.large)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CinevaSpacing.xl,
          CinevaSpacing.xl,
          CinevaSpacing.xl,
          CinevaSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 26, color: confirmColor),
              const SizedBox(height: CinevaSpacing.md),
            ],
            Text(title, style: CinevaTypography.sectionTitle.copyWith(fontSize: 18)),
            const SizedBox(height: CinevaSpacing.xs),
            Text(message, style: CinevaTypography.body),
            const SizedBox(height: CinevaSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    cancelLabel,
                    style: CinevaTypography.button.copyWith(color: CinevaColors.textSoft),
                  ),
                ),
                const SizedBox(width: CinevaSpacing.xs),
                TextButton(
                  onPressed: onConfirm,
                  child: Text(
                    confirmLabel,
                    style: CinevaTypography.button.copyWith(color: confirmColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
