import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// Neon-brutalist confirm dialog. Returns true only when the caller picks the
/// destructive action, so a tap outside or on cancel is a safe no-op.
Future<bool> showNeoConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'BATAL',
  IconData icon = Icons.warning,
  bool destructive = true,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _NeoConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _NeoConfirmDialog extends StatelessWidget {
  const _NeoConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color confirmBg = destructive ? BColors.error : BColors.primary;
    final Color confirmFg =
        destructive ? BColors.onError : BColors.primaryContainer;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(BSpace.margin),
      child: Container(
        decoration: BoxDecoration(
          color: BColors.surface,
          border: Border.all(color: BColors.outline, width: BBorder.thick),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: BColors.outline, offset: Offset(6, 6)),
          ],
        ),
        padding: const EdgeInsets.all(BSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: confirmBg,
                    border: Border.all(
                        color: BColors.outline, width: BBorder.thick),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: confirmFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      title,
                      style: BText.h2.copyWith(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BSpace.md),
            Text(message,
                style: BText.body.copyWith(fontSize: 13, height: 1.45)),
            const SizedBox(height: BSpace.lg),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: cancelLabel,
                    background: BColors.surfaceContainerLowest,
                    foreground: BColors.onSurface,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: BSpace.sm),
                Expanded(
                  child: _DialogButton(
                    label: confirmLabel,
                    background: confirmBg,
                    foreground: confirmFg,
                    onTap: () => Navigator.of(context).pop(true),
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

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: BColors.outline, width: BBorder.thick),
            boxShadow: BShadow.md,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: BText.label.copyWith(
              color: foreground,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small labelled readout used inside dialogs.
class NeoInfoRow extends StatelessWidget {
  const NeoInfoRow(
      {super.key,
      required this.label,
      required this.value,
      this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: BText.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: BSpace.sm),
          Text(
            value,
            style: BText.amountMd.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
