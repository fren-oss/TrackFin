import 'package:flutter/widgets.dart';

/// Exposes the root navigator to deep screens (e.g. the "+ Catat Keluar"
/// button on Beranda) without threading callbacks through every widget.
class NavScope extends InheritedWidget {
  const NavScope({super.key, required this.goTo, required super.child});

  final void Function(int index) goTo;

  static NavScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavScope>();

  @override
  bool updateShouldNotify(NavScope oldWidget) => false;
}
