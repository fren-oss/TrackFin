import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'dompet_screen.dart';

/// First-run screen shown until the user creates their first wallet. Step 1 of
/// the two-step setup: there is nothing to record spending against until a
/// wallet exists, so this is intentionally not skippable.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<({String title, String body, IconData icon})> _steps =
      <({String title, String body, IconData icon})>[
    (
      title: 'Buat dompet',
      body:
          'Masukkan nama dan saldo awal. Dompet pertama otomatis jadi sumber pengeluaran.',
      icon: Icons.add_card,
    ),
    (
      title: 'Catat pengeluaran',
      body:
          'Pilih kategori lalu masukkan nominal. Grafik Analisis langsung ikut berubah.',
      icon: Icons.edit_note,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  BSpace.margin,
                  BSpace.lg,
                  BSpace.margin,
                  BSpace.md,
                ),
                children: [
                  const _Brand(),
                  const SizedBox(height: BSpace.lg),
                  Text(
                    'MULAI DARI NOL',
                    style: BText.labelWide.copyWith(
                      color: BColors.secondary,
                      fontSize: 11,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Belum ada data',
                    style: TextStyle(
                      fontFamily: BFont.headline,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.1,
                      color: BColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: BSpace.sm),
                  Text(
                    'Semua angka di TrackFin dihitung dari catatanmu sendiri. '
                    'Tidak ada saldo contoh, tidak ada pengeluaran palsu.',
                    style: BText.body.copyWith(fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: BSpace.lg),
                  for (int i = 0; i < _steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BSpace.sm),
                      child: _StepTile(index: i + 1, step: _steps[i]),
                    ),
                  const SizedBox(height: BSpace.md),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: BBorder.thick,
                        color: BColors.outline,
                      ),
                      const SizedBox(width: BSpace.sm),
                      Expanded(
                        child: Text(
                          'LANGKAH 1 DARI 2',
                          style: BText.labelTiny.copyWith(
                            color: BColors.onSurfaceVariant,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BSpace.sm),
                  const AddWalletForm(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                BSpace.margin,
                BSpace.sm,
                BSpace.margin,
                BSpace.md,
              ),
              decoration: const BoxDecoration(
                color: scaffoldBackground,
                border: Border(
                    top: BorderSide(
                        color: BColors.outline, width: BBorder.thick)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tambahkan dompet dulu sebelum mencatat pengeluaran.',
                      style: TextStyle(
                        fontFamily: BFont.body,
                        fontSize: 12,
                        height: 1.35,
                        color: BColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: BSpace.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: BColors.surfaceContainerHigh,
                      border: Border.all(
                          color: BColors.outline, width: BBorder.thick),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LANGKAH 2',
                          style: BText.label.copyWith(
                            color: BColors.onSurfaceVariant,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color:
                              BColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: BColors.primaryContainer,
            border: Border.all(color: BColors.outline, width: BBorder.thick),
            boxShadow: BShadow.md,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.account_balance,
              size: 26, color: BColors.primary),
        ),
        const SizedBox(width: BSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TrackFin', style: BText.brand.copyWith(fontSize: 24)),
              const SizedBox(height: 2),
              Text(
                'PELACAK PENGELUARAN PRIBADI',
                style: BText.labelWide.copyWith(
                  color: BColors.onSurfaceVariant,
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});

  final int index;
  final ({String title, String body, IconData icon}) step;

  @override
  Widget build(BuildContext context) {
    final bool isFirst = index == 1;

    return Container(
      padding: const EdgeInsets.all(BSpace.md),
      decoration: BoxDecoration(
        color: isFirst
            ? BColors.surfaceContainerLowest
            : BColors.surfaceContainerLow,
        border: Border.all(color: BColors.outline, width: BBorder.thick),
        boxShadow: isFirst ? BShadow.md : const <BoxShadow>[],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isFirst ? BColors.primary : BColors.surfaceContainerHigh,
              border: Border.all(color: BColors.outline, width: BBorder.thick),
            ),
            alignment: Alignment.center,
            child: isFirst
                ? Text(
                    '$index',
                    style: BText.amountMd.copyWith(
                      color: BColors.primaryContainer,
                      fontSize: 15,
                    ),
                  )
                : Icon(
                    step.icon,
                    size: 17,
                    color: BColors.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFirst ? step.title : '$index. ${step.title}',
                  style: BText.h3.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(step.body,
                    style:
                        BText.bodySmall.copyWith(fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
