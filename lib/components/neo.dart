import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A bordered block with a hard offset shadow. This is the core Bauhaus
/// container: thick 2px border, zero blur, solid shadow, square-ish corners.
class NeoCard extends StatelessWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.background = BColors.surfaceContainerLowest,
    this.padding = const EdgeInsets.all(BSpace.md),
    this.borderColor = BColors.outline,
    this.borderWidth = BBorder.thick,
    this.shadow = BShadow.md,
    this.borderRadius = BRadius.md,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final Color background;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadow;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Pressable block that physically depresses: the shadow shrinks to 1px and
/// the block shifts down-right by the same amount, so it stays aligned with its
/// own border. Mirrors `.neo-btn:active` from the designs.
class NeoButton extends StatefulWidget {
  const NeoButton({
    super.key,
    required this.child,
    this.onTap,
    this.background = BColors.primary,
    this.foreground = BColors.primaryContainer,
    this.borderColor = BColors.outline,
    this.padding =
        const EdgeInsets.symmetric(horizontal: BSpace.md, vertical: 12),
    this.shadow = BShadow.md,
    this.borderRadius = BRadius.md,
    this.borderWidth = BBorder.thick,
    this.height,
    this.enabled = true,
    this.hoverBackground,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadow;
  final double borderRadius;
  final double borderWidth;
  final double? height;
  final bool enabled;
  final Color? hoverBackground;

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _pressed = false;
  bool _hovered = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;

    Color bg = widget.background;
    if (_hovered && widget.hoverBackground != null) {
      bg = widget.hoverBackground!;
    }

    // Pressed: shift by the shadow offset and collapse the shadow.
    final offset = _pressed ? 3.0 : 0.0;
    final shadow = _pressed ? BShadow.pressed : widget.shadow;

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(offset, offset, 0),
      padding: widget.padding,
      constraints: widget.height != null
          ? BoxConstraints(minHeight: widget.height!)
          : null,
      decoration: BoxDecoration(
        color: widget.enabled ? bg : BColors.surfaceContainer,
        border:
            Border.all(color: widget.borderColor, width: widget.borderWidth),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: active || !_pressed ? shadow : BShadow.pressed,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
            color:
                widget.enabled ? widget.foreground : BColors.onSurfaceVariant),
        child: widget.child,
      ),
    );

    if (!active) return box;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: box,
      ),
    );
  }
}

/// Small square icon tile with a solid fill and thick border, used for
/// category and wallet iconography.
class NeoIconTile extends StatelessWidget {
  const NeoIconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 40,
    this.iconSize = 20,
    this.borderColor = BColors.outline,
    this.borderWidth = BBorder.thick,
    this.shadow = BShadow.sm,
    this.borderRadius = BRadius.sm,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadow;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadow,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

/// Uppercase tag / badge with a 1px border. Used for status chips.
class NeoTag extends StatelessWidget {
  const NeoTag({
    super.key,
    required this.text,
    this.background = BColors.primaryContainer,
    this.foreground = BColors.primary,
    this.icon,
    this.dot = false,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.borderWidth = BBorder.thin,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool dot;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: BColors.outline, width: borderWidth),
        borderRadius: BorderRadius.circular(BRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 7, height: 7, color: foreground),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                height: 1.2,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal progress track with a 2px border, matching the budget and
/// category bars.
class NeoProgressBar extends StatelessWidget {
  const NeoProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
    this.background = BColors.surfaceContainerLowest,
    this.showInnerBorder = false,
  });

  final double value;
  final Color color;
  final double height;
  final Color background;
  final bool showInnerBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
            color: BColors.outline,
            width: showInnerBorder ? BBorder.thick : BBorder.thin),
      ),
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(
          color: color,
          child: showInnerBorder
              ? const SizedBox.expand(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(
                              color: BColors.outline, width: BBorder.thick)),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
