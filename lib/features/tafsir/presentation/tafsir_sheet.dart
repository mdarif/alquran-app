import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/format/html_to_plain_text.dart';
import '../../../core/testing/widget_keys.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/experimental_pill.dart';
import '../../reader/domain/entities/ayah.dart';
import '../../reader/domain/entities/translation_resource.dart';
import '../domain/entities/tafsir_resource.dart';
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
  required List<TranslationResource> resources,
  required String? surahName,
}) {
  final cubit = GetIt.I<TafsirCubit>()..load();
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
        resources: resources,
        surahName: surahName,
      ),
    ),
  );
}

class _AyahTafsirSheet extends StatelessWidget {
  const _AyahTafsirSheet({
    required this.cubit,
    required this.ayah,
    required this.resources,
    required this.surahName,
  });

  final TafsirCubit cubit;
  final Ayah ayah;
  final List<TranslationResource> resources;
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
              child: FutureBuilder<List<TafsirAyahResult>>(
                future: cubit.entriesForAyah(
                  surah: ayah.surahId,
                  ayah: ayah.ayahNumber,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final results = snapshot.data ?? const [];
                  if (results.isEmpty) {
                    return BlocProvider.value(
                      value: cubit,
                      child: const TafsirPage(showHeader: false),
                    );
                  }
                  return _TafsirEntryView(
                    ayah: ayah,
                    resources: resources,
                    results: results,
                    label: '${surahName ?? 'Surah ${ayah.surahId}'} '
                        '${ayah.surahId}:${ayah.ayahNumber}',
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
  const _TafsirEntryView({
    required this.ayah,
    required this.resources,
    required this.results,
    required this.label,
  });

  final Ayah ayah;
  final List<TranslationResource> resources;
  final List<TafsirAyahResult> results;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _AyahStudyBlock(
          ayah: ayah,
          resources: resources,
        ),
        const SizedBox(height: 18),
        Divider(color: cs.outlineVariant, height: 1),
        for (var i = 0; i < results.length; i++) ...[
          _TafsirEntrySection(
            result: results[i],
            initiallyExpanded: results.length == 1 || i == results.length - 1,
          ),
          Divider(color: cs.outlineVariant, height: 1),
        ],
      ],
    );
  }
}

class _TafsirEntrySection extends StatelessWidget {
  const _TafsirEntrySection({
    required this.result,
    required this.initiallyExpanded,
  });

  final TafsirAyahResult result;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = result.entry;
    final coveredRange = entry.fromAyah == entry.toAyah
        ? null
        : '${entry.fromAyah} - ${entry.toAyah}';
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 18),
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        title: Text(
          _tafsirDisplayLabel(result.resource),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: coveredRange == null
            ? null
            : Text(
                'Covers $coveredRange',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
        children: [
          _TafsirBody(text: entry.text),
        ],
      ),
    );
  }

  String _tafsirDisplayLabel(TafsirResource resource) {
    final language = switch (resource.languageCode) {
      'en' => 'English',
      'ur' => 'Urdu',
      'ar' => 'Arabic',
      _ => resource.nativeName?.trim().isNotEmpty == true
          ? resource.nativeName!.trim()
          : resource.languageCode.toUpperCase(),
    };
    final suffix = resource.abridged ? ' (Abridged)' : '';
    return '$language - ${resource.name}$suffix';
  }
}

class _TafsirBody extends StatelessWidget {
  const _TafsirBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = htmlToTafsirBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: blocks[i].isHeading ? 24 : 14),
          _TafsirTextBlockView(block: blocks[i]),
          if (blocks[i].isHeading) const SizedBox(height: 4),
        ],
        if (blocks.isEmpty)
          SelectableText(
            htmlToPlainText(text),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
      ],
    );
  }
}

class _TafsirTextBlockView extends StatelessWidget {
  const _TafsirTextBlockView({required this.block});

  final TafsirTextBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isArabic = block.isArabic;
    final isRtl = !isArabic && _looksRtlScript(block.text);
    final headingSize = _headingSize(block.headingLevel);
    final baseStyle = block.isHeading
        ? theme.textTheme.headlineSmall
        : theme.textTheme.bodyLarge;
    final style = isArabic
        ? QuranTextStyle.madani.copyWith(
            fontSize: block.isHeading ? headingSize : 23,
            fontWeight: block.isHeading ? FontWeight.w700 : FontWeight.w400,
            height: 1.7,
          )
        : block.isHeading
            ? (isRtl ? 'ur' : 'en').scriptStyle(
                baseStyle?.copyWith(
                      fontWeight: isRtl ? FontWeight.w400 : FontWeight.w700,
                      fontSize: isRtl ? 20 : headingSize,
                      height: isRtl ? 2.35 : 1.22,
                    ) ??
                    const TextStyle(),
                isRtl: isRtl,
              )
            : (isRtl ? 'ur' : 'en').scriptStyle(
                baseStyle?.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize: isRtl ? 18 : baseStyle.fontSize,
                      height: isRtl ? 2.65 : 1.55,
                    ) ??
                    const TextStyle(),
                isRtl: isRtl,
              );
    if (isArabic) {
      return SelectableText(
        block.text,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: style,
      );
    }
    final textStyle = style.copyWith(
      color: block.isLead ? cs.error : style.color,
      fontWeight: block.isLead ? FontWeight.w600 : style.fontWeight,
    );
    return SelectableText.rich(
      TextSpan(
        style: textStyle,
        children: [
          for (final span in block.spans)
            TextSpan(
              text: span.text,
              style: _spanStyle(
                span,
                textStyle,
                cs.onSurfaceVariant.withValues(alpha: 0.62),
                cs.primary,
              ),
            ),
        ],
      ),
      textAlign: isRtl ? TextAlign.right : TextAlign.left,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  double _headingSize(int? level) {
    return switch (level) {
      1 => 27,
      2 => 24,
      3 => 21,
      4 => 19,
      5 => 17,
      6 => 16,
      _ => 24,
    };
  }

  TextStyle? _spanStyle(
    TafsirTextSpan span,
    TextStyle? baseStyle,
    Color mutedColor,
    Color arabicColor,
  ) {
    if (span.isArabic) {
      return QuranTextStyle.madani.copyWith(
        color: span.isMuted ? mutedColor : arabicColor,
        fontSize: (baseStyle?.fontSize ?? 17) + 3,
        fontWeight: FontWeight.w400,
        height: 1.65,
      );
    }
    final color = span.isMuted ? mutedColor : baseStyle?.color;
    return span.isMuted ? TextStyle(color: color) : null;
  }
}

bool _looksRtlScript(String text) {
  final letters =
      RegExp(r'[\p{Letter}]', unicode: true).allMatches(text).length;
  if (letters == 0) return false;
  final rtl = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
  ).allMatches(text).length;
  return rtl / letters >= 0.45;
}

class _AyahStudyBlock extends StatelessWidget {
  const _AyahStudyBlock({
    required this.ayah,
    required this.resources,
  });

  final Ayah ayah;
  final List<TranslationResource> resources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              ayah.textArabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: QuranTextStyle.madani.copyWith(fontSize: 26),
            ),
            for (final resource in resources)
              if (ayah.translations[resource.slug] != null)
                _TafsirTranslationText(
                  resource: resource,
                  text: ayah.translations[resource.slug]!,
                ),
          ],
        ),
      ),
    );
  }
}

class _TafsirTranslationText extends StatelessWidget {
  const _TafsirTranslationText({
    required this.resource,
    required this.text,
  });

  final TranslationResource resource;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isRtl = resource.isRtl;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  resource.displayCredit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (resource.experimental) ...[
                const SizedBox(width: 6),
                const ExperimentalPill(),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            text,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            style: resource.languageCode.scriptStyle(
              theme.textTheme.bodyMedium!.copyWith(height: 1.5),
              isRtl: isRtl,
            ),
          ),
        ],
      ),
    );
  }
}
