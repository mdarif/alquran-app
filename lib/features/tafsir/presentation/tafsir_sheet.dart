import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/testing/widget_keys.dart';
import '../../../core/theme/app_icons.dart';
import '../../reader/domain/entities/ayah.dart';
import 'cubit/tafsir_cubit.dart';
import 'pages/tafsir_page.dart';

Future<void> showTafsirSheet(BuildContext context) {
  final cubit = GetIt.I<TafsirCubit>()..load();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const FractionallySizedBox(
        heightFactor: 0.78,
        alignment: Alignment.bottomCenter,
        child: TafsirPage(),
      ),
    ),
  );
}

Future<void> showTafsirForAyahSheet(
  BuildContext context, {
  required Ayah ayah,
  required String? surahName,
}) {
  final cubit = GetIt.I<TafsirCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.72,
      alignment: Alignment.bottomCenter,
      child: _AyahTafsirSheet(
        cubit: cubit,
        ayah: ayah,
        surahName: surahName,
      ),
    ),
  );
}

class _AyahTafsirSheet extends StatelessWidget {
  const _AyahTafsirSheet({
    required this.cubit,
    required this.ayah,
    required this.surahName,
  });

  final TafsirCubit cubit;
  final Ayah ayah;
  final String? surahName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      key: WidgetKeys.tafsirAyahSheet,
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Close',
                            icon: const AppIcon(AppIcons.close),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        Text(
                          'Tafsir',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<TafsirAyahResult?>(
                future: cubit.entryForAyah(
                  surah: ayah.surahId,
                  ayah: ayah.ayahNumber,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final result = snapshot.data;
                  if (result == null) {
                    return _NoInstalledTafsir(
                      onOpenDownloads: () {
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.of(context).maybePop();
                        showTafsirSheet(rootContext);
                      },
                    );
                  }
                  return _TafsirEntryView(
                    result: result,
                    label: '${surahName ?? 'Surah ${ayah.surahId}'} '
                        '${ayah.ayahNumber}',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TafsirEntryView extends StatelessWidget {
  const _TafsirEntryView({required this.result, required this.label});

  final TafsirAyahResult result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = result.entry;
    final range = entry.fromAyah == entry.toAyah
        ? label
        : '${entry.fromAyah} - ${entry.toAyah}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        Text(
          range,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          result.resource.displayCredit,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          entry.text,
          textDirection:
              result.resource.isRtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: result.resource.isRtl ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
        ),
      ],
    );
  }
}

class _NoInstalledTafsir extends StatelessWidget {
  const _NoInstalledTafsir({required this.onOpenDownloads});

  final VoidCallback onOpenDownloads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.70),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Tafsir downloaded',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Download a Tafsir edition once and it will be available offline from each ayah.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenDownloads,
                    icon: const AppIcon(AppIcons.alKahf),
                    label: const Text('Open Tafsir Downloads'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
