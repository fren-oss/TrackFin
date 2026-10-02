import 'package:flutter/material.dart';

import 'components/app_header.dart';
import 'components/bottom_nav.dart';
import 'components/nav_scope.dart';
import 'design/tokens.dart';
import 'screens/analisis_screen.dart';
import 'screens/beranda_screen.dart';
import 'screens/catat_screen.dart';
import 'screens/dompet_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_state.dart';

class TrackFinApp extends StatefulWidget {
  const TrackFinApp({super.key});

  @override
  State<TrackFinApp> createState() => _TrackFinAppState();
}

class _TrackFinAppState extends State<TrackFinApp> {
  final AppState _state = AppState();
  int _index = 0;

  // Nav order matches the bottom bar layout, not the screen declaration order.
  static const List<String> _titles = [
    'Beranda',
    'Analisis',
    'Catat Pengeluaran',
    'Dompet Akun',
  ];

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  void _openSettings() {
    // A pushed route lands above AppStateScope in the tree, so the scope has to
    // be re-provided here or SettingsScreen cannot reach the state.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppStateScope(
          notifier: _state,
          child: const SettingsPage(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _state.attachStorage();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Widget _screenFor(int index) {
    switch (index) {
      case 1:
        return const AnalisisScreen();
      case 2:
        return const CatatScreen();
      case 3:
        return const DompetScreen();
      case 0:
      default:
        return BerandaScreen(state: _state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _state,
      child: NavScope(
        goTo: _goTo,
        child: Scaffold(
          backgroundColor: scaffoldBackground,
          body: AnimatedBuilder(
            animation: _state,
            builder: (BuildContext context, Widget? _) {
              // Hold a blank frame until storage is read, otherwise a returning
              // user sees the onboarding flash before their wallets load.
              if (!_state.storageResolved) {
                return const SizedBox.shrink();
              }
              if (!_state.hasWallet) {
                return const OnboardingScreen();
              }

              return Column(
                children: [
                  AppHeader(
                    pageTitle: _titles[_index],
                    onSettings: _openSettings,
                  ),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: _screenFor(_index),
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: AnimatedBuilder(
            animation: _state,
            builder: (BuildContext context, Widget? _) {
              if (!_state.storageResolved || !_state.hasWallet) {
                return const SizedBox.shrink();
              }
              return BottomNav(current: _index, onSelect: _goTo);
            },
          ),
        ),
      ),
    );
  }
}
