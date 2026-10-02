import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../design/tokens.dart';

/// Fixed top bar: 2px bottom border, logo tile, brand lockup, page title, and a
/// settings button that opens the Google Sheets sync page.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.pageTitle, this.onSettings});

  final String pageTitle;

  /// Omitted on screens without a settings action.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: BColors.surface,
        border: Border(
            bottom: BorderSide(color: BColors.outline, width: BBorder.thick)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: BSpace.margin,
        right: BSpace.margin,
        bottom: 0,
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const _LogoTile(),
            const SizedBox(width: BSpace.sm),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TrackFin',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.15,
                    color: BColors.onSurface,
                  ),
                ),
                Text(
                  pageTitle.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    height: 1.2,
                    color: BColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (onSettings != null)
              _IconButton(
                icon: Icons.settings,
                tooltip: 'Pengaturan',
                onTap: onSettings!,
              ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: BColors.outline, width: BBorder.thick),
              borderRadius: BorderRadius.circular(6),
              boxShadow: BShadow.sm,
            ),
            child: Icon(icon, size: 20, color: BColors.onSurface),
          ),
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: BColors.surfaceContainerLowest,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        boxShadow: BShadow.sm,
      ),
      alignment: Alignment.center,
      child:
          const Icon(Icons.account_balance, size: 20, color: BColors.primary),
    );
  }
}
