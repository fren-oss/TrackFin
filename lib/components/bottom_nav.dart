import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../models/finance.dart';

/// Bottom navigation with 4 destinations. The third item ("Catat") is a
/// raised yellow block that breaks the bar's top edge, per the designs.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  static const List<NavSpec> specs = [
    NavSpec('Beranda', 'account_balance_wallet'),
    NavSpec('Analisis', 'analytics'),
    NavSpec('Catat', 'add'),
    NavSpec('Dompet', 'savings'),
  ];

  void _handle(int index) {
    if (index != current) onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BColors.surface,
        border: Border(
            top: BorderSide(color: BColors.outline, width: BBorder.thick)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _NavItem(
              spec: specs[0],
              active: current == 0,
              onTap: () => _handle(0),
            ),
            _NavItem(
              spec: specs[1],
              active: current == 1,
              onTap: () => _handle(1),
            ),
            _NavItem(
              spec: specs[2],
              active: current == 2,
              raised: true,
              onTap: () => _handle(2),
            ),
            _NavItem(
              spec: specs[3],
              active: current == 3,
              onTap: () => _handle(3),
            ),
          ],
        ),
      ),
    );
  }
}

class NavSpec {
  const NavSpec(this.label, this.icon);
  final String label;
  final String icon;
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.onTap,
    this.raised = false,
  });

  final NavSpec spec;
  final bool active;
  final VoidCallback onTap;
  final bool raised;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        widget.active ? BColors.primary : BColors.onSurface;

    Widget iconWidget;
    if (widget.raised) {
      iconWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: BColors.primaryContainer,
          border: Border.all(color: BColors.outline, width: BBorder.thick),
          boxShadow: _pressed ? BShadow.pressed : BShadow.md,
        ),
        transform: _pressed ? Matrix4.translationValues(2, 2, 0) : null,
        alignment: Alignment.center,
        child: const Icon(Icons.add, size: 28, color: BColors.primary),
      );
    } else {
      iconWidget = Icon(ms(widget.spec.icon), size: 24, color: labelColor);
    }

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.raised)
                Transform.translate(
                    offset: const Offset(0, -10), child: iconWidget)
              else
                SizedBox(height: 26, child: Center(child: iconWidget)),
              if (widget.raised)
                Transform.translate(
                    offset: const Offset(0, -4), child: _label())
              else
                _label(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label() {
    final Color color = _pressed
        ? BColors.secondary
        : (widget.active ? BColors.primary : BColors.onSurface);
    return Text(
      widget.spec.label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 11,
        fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: 0.9,
        height: 1.2,
        color: color,
      ),
    );
  }
}
