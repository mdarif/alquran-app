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
        heightFactor: 0.94,
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
      heightFactor: 0.94,
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

class _AyahTafsirSheet extends StatefulWidget {
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
  State<_AyahTafsirSheet> createState() => _AyahTafsirSheetState();
}

class _AyahTafsirSheetState extends State<_AyahTafsirSheet> {
  late Future<List<TafsirAyahResult>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.cubit.entriesForAyah(
      surah: widget.ayah.surahId,
      ayah: widget.ayah.ayahNumber,
    );
  }

  @override
  void didUpdateWidget(covariant _AyahTafsirSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit ||
        oldWidget.ayah.surahId != widget.ayah.surahId ||
        oldWidget.ayah.ayahNumber != widget.ayah.ayahNumber) {
      _entriesFuture = widget.cubit.entriesForAyah(
        surah: widget.ayah.surahId,
        ayah: widget.ayah.ayahNumber,
      );
    }
  }

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
                future: _entriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final results = snapshot.data ?? const [];
                  if (results.isEmpty) {
                    return BlocProvider.value(
                      value: widget.cubit,
                      child: const TafsirPage(showHeader: false),
                    );
                  }
                  return _TafsirEntryView(
                    ayah: widget.ayah,
                    resources: widget.resources,
                    results: results,
                    label:
                        '${widget.surahName ?? 'Surah ${widget.ayah.surahId}'} '
                        '${widget.ayah.surahId}:${widget.ayah.ayahNumber}',
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

class _TafsirEntryView extends StatefulWidget {
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
  State<_TafsirEntryView> createState() => _TafsirEntryViewState();
}

class _TafsirEntryViewState extends State<_TafsirEntryView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _searchHitKey = GlobalKey();
  late final GlobalKey _ayahKey;
  late final List<GlobalKey> _sectionKeys;
  late final List<bool> _expandedSections;
  double _textScale = 1;
  String _query = '';
  int? _activeSearchResultIndex;
  int? _activeSearchBlockIndex;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _ayahKey = GlobalKey();
    _sectionKeys = [for (final _ in widget.results) GlobalKey()];
    _expandedSections = [
      for (var i = 0; i < widget.results.length; i++)
        widget.results.length == 1 || i == widget.results.length - 1,
    ];
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      final value = _searchController.text.trim();
      if (value != _query) {
        setState(() {
          _query = value;
          _activeSearchResultIndex = null;
          _activeSearchBlockIndex = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 160;
    if (show != _showBackToTop) setState(() => _showBackToTop = show);
  }

  void _changeTextScale(double delta) {
    setState(() {
      _textScale = (_textScale + delta).clamp(0.85, 1.35);
    });
  }

  Future<void> _scrollTo(GlobalKey key) async {
    if (!_scrollController.hasClients) return;
    final context = key.currentContext;
    if (context == null) return;
    final target = context.findRenderObject();
    final list = _listKey.currentContext?.findRenderObject();
    if (target is! RenderBox || list is! RenderBox) return;
    final y = target.localToGlobal(Offset.zero, ancestor: list).dy;
    final offset = (_scrollController.offset + y - 8).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _settleLayout() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  Future<void> _openAndScrollToSection(int index) async {
    if (index < 0 || index >= _sectionKeys.length) return;
    setState(() => _expandedSections[index] = true);
    await _settleLayout();
    await _scrollTo(_sectionKeys[index]);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollToSearchHit() async {
    if (_query.isEmpty) return;
    final lower = _query.toLowerCase();
    final matches = _matchingBlocks(lower);
    if (matches.isEmpty) return;
    var nextIndex = 0;
    final activeResult = _activeSearchResultIndex;
    final activeBlock = _activeSearchBlockIndex;
    if (activeResult != null && activeBlock != null) {
      final current = matches.indexWhere(
        (m) => m.resultIndex == activeResult && m.blockIndex == activeBlock,
      );
      if (current >= 0) nextIndex = (current + 1) % matches.length;
    }
    final match = matches[nextIndex];
    setState(() {
      _activeSearchResultIndex = match.resultIndex;
      _activeSearchBlockIndex = match.blockIndex;
      _expandedSections[match.resultIndex] = true;
    });
    await _settleLayout();
    if (_searchHitKey.currentContext == null) {
      await _scrollTo(_sectionKeys[match.resultIndex]);
      return;
    }
    await _scrollTo(_searchHitKey);
  }

  List<_SearchBlockMatch> _matchingBlocks(String lowerQuery) {
    final matches = <_SearchBlockMatch>[];
    for (var resultIndex = 0;
        resultIndex < widget.results.length;
        resultIndex++) {
      final blocks = htmlToTafsirBlocks(widget.results[resultIndex].entry.text);
      for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
        if (blocks[blockIndex].text.toLowerCase().contains(lowerQuery)) {
          matches.add(
            _SearchBlockMatch(
              resultIndex: resultIndex,
              blockIndex: blockIndex,
            ),
          );
        }
      }
    }
    return matches;
  }

  int get _searchHitCount {
    if (_query.isEmpty) return 0;
    final lower = _query.toLowerCase();
    var count = 0;
    for (final result in widget.results) {
      final haystack =
          '${_tafsirDisplayLabel(result.resource)} ${htmlToPlainText(result.entry.text)}'
              .toLowerCase();
      var start = 0;
      while (true) {
        final index = haystack.indexOf(lower, start);
        if (index < 0) break;
        count++;
        start = index + lower.length;
      }
    }
    return count;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hitCount = _searchHitCount;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TafsirControls(
                    textScale: _textScale,
                    queryController: _searchController,
                    searchFocus: _searchFocus,
                    hitCount: hitCount,
                    onDecreaseText: () => _changeTextScale(-0.05),
                    onIncreaseText: () => _changeTextScale(0.05),
                    onSubmitSearch: (_) => _scrollToSearchHit(),
                    onNextSearchHit: _scrollToSearchHit,
                    onClearSearch: () {
                      _searchController.clear();
                      _searchFocus.unfocus();
                    },
                  ),
                  const SizedBox(height: 10),
                  _TafsirJumpBar(
                    results: widget.results,
                    labelFor: _tafsirDisplayLabel,
                    onAyah: _scrollToTop,
                    onSection: _openAndScrollToSection,
                  ),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant, height: 1),
            Expanded(
              child: KeyedSubtree(
                key: WidgetKeys.tafsirEntryList,
                child: SingleChildScrollView(
                  key: _listKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 72),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KeyedSubtree(
                        key: _ayahKey,
                        child: _AyahStudyBlock(
                          ayah: widget.ayah,
                          resources: widget.resources,
                          textScale: _textScale,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Divider(color: cs.outlineVariant, height: 1),
                      for (var i = 0; i < widget.results.length; i++) ...[
                        KeyedSubtree(
                          key: _sectionKeys[i],
                          child: _TafsirEntrySection(
                            result: widget.results[i],
                            expanded: _expandedSections[i],
                            onToggle: () => setState(
                              () =>
                                  _expandedSections[i] = !_expandedSections[i],
                            ),
                            textScale: _textScale,
                            searchQuery: _query,
                            searchTargetBlockIndex:
                                _activeSearchResultIndex == i
                                    ? _activeSearchBlockIndex
                                    : null,
                            searchHitKey: _activeSearchResultIndex == i
                                ? _searchHitKey
                                : null,
                            displayLabel:
                                _tafsirDisplayLabel(widget.results[i].resource),
                          ),
                        ),
                        if (i == widget.results.length - 1)
                          const _TafsirEndMarker()
                        else
                          Divider(color: cs.outlineVariant, height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showBackToTop)
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.small(
              key: WidgetKeys.tafsirBackToTop,
              tooltip: 'Back to top',
              onPressed: _scrollToTop,
              child: const AppIcon(AppIcons.scrollTop),
            ),
          ),
      ],
    );
  }
}

class _TafsirEndMarker extends StatelessWidget {
  const _TafsirEndMarker();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineColor = cs.outlineVariant.withValues(alpha: 0.7);
    final ornamentColor = cs.primary.withValues(alpha: 0.72);
    return Padding(
      key: WidgetKeys.tafsirEndMarker,
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 6),
      child: Row(
        children: [
          Expanded(child: _EndMarkerLine(color: lineColor, reverse: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.12),
                ),
              ),
              child: SizedBox(
                width: 42,
                height: 18,
                child: Center(
                  child: Transform.rotate(
                    angle: 0.7853981634,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: ornamentColor,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _EndMarkerLine(color: lineColor)),
        ],
      ),
    );
  }
}

class _SearchBlockMatch {
  const _SearchBlockMatch({
    required this.resultIndex,
    required this.blockIndex,
  });

  final int resultIndex;
  final int blockIndex;
}

class _EndMarkerLine extends StatelessWidget {
  const _EndMarkerLine({required this.color, this.reverse = false});

  final Color color;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
          end: reverse ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0),
            color,
          ],
        ),
      ),
      child: const SizedBox(height: 1),
    );
  }
}

class _TafsirControls extends StatelessWidget {
  const _TafsirControls({
    required this.textScale,
    required this.queryController,
    required this.searchFocus,
    required this.hitCount,
    required this.onDecreaseText,
    required this.onIncreaseText,
    required this.onSubmitSearch,
    required this.onNextSearchHit,
    required this.onClearSearch,
  });

  final double textScale;
  final TextEditingController queryController;
  final FocusNode searchFocus;
  final int hitCount;
  final VoidCallback onDecreaseText;
  final VoidCallback onIncreaseText;
  final ValueChanged<String> onSubmitSearch;
  final VoidCallback onNextSearchHit;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchLabel = queryController.text.isEmpty
        ? ''
        : '$hitCount ${hitCount == 1 ? 'match' : 'matches'}';
    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: IconButton(
              key: WidgetKeys.tafsirTextDecrease,
              tooltip: 'Smaller Tafsir text',
              onPressed: textScale <= 0.85 ? null : onDecreaseText,
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size.square(34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Text('A', textScaler: TextScaler.linear(0.9)),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: IconButton.filledTonal(
              key: WidgetKeys.tafsirTextIncrease,
              tooltip: 'Larger Tafsir text',
              onPressed: textScale >= 1.35 ? null : onIncreaseText,
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size.square(34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Text('A', textScaler: TextScaler.linear(1.12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 38,
                  child: TextField(
                    key: WidgetKeys.tafsirInTextSearchField,
                    controller: queryController,
                    focusNode: searchFocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSubmitSearch,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      prefixIcon: const AppIcon(AppIcons.search, size: 18),
                      prefixIconConstraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      suffixIcon: queryController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: onClearSearch,
                              icon: const AppIcon(AppIcons.close, size: 18),
                            ),
                      hintText: 'Find in Tafsir',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  height: 14,
                  child: Text(
                    matchLabel,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: IconButton.filledTonal(
              key: WidgetKeys.tafsirSearchNext,
              tooltip: 'Next match',
              onPressed: hitCount == 0 ? null : onNextSearchHit,
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size.square(34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const AppIcon(AppIcons.expand),
            ),
          ),
        ],
      ),
    );
  }
}

class _TafsirJumpBar extends StatelessWidget {
  const _TafsirJumpBar({
    required this.results,
    required this.labelFor,
    required this.onAyah,
    required this.onSection,
  });

  final List<TafsirAyahResult> results;
  final String Function(TafsirResource resource) labelFor;
  final VoidCallback onAyah;
  final ValueChanged<int> onSection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          if (index == 0) {
            return ActionChip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              avatar: const AppIcon(AppIcons.viewReading, size: 16),
              label: const Text('Ayah'),
              onPressed: onAyah,
            );
          }
          final resultIndex = index - 1;
          final result = results[resultIndex];
          return ActionChip(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(_shortJumpLabel(labelFor(result.resource))),
            onPressed: () => onSection(resultIndex),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: results.length + 1,
      ),
    );
  }

  String _shortJumpLabel(String label) {
    if (label.startsWith('English - ')) return 'English';
    if (label.startsWith('Urdu - ')) return 'Urdu';
    if (label.startsWith('Arabic - ')) return 'Arabic';
    return label;
  }
}

class _TafsirEntrySection extends StatelessWidget {
  const _TafsirEntrySection({
    required this.result,
    required this.expanded,
    required this.onToggle,
    required this.textScale,
    required this.searchQuery,
    required this.searchTargetBlockIndex,
    required this.searchHitKey,
    required this.displayLabel,
  });

  final TafsirAyahResult result;
  final bool expanded;
  final VoidCallback onToggle;
  final double textScale;
  final String searchQuery;
  final int? searchTargetBlockIndex;
  final GlobalKey? searchHitKey;
  final String displayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = result.entry;
    final coveredRange = entry.fromAyah == entry.toAyah
        ? null
        : '${entry.fromAyah} - ${entry.toAyah}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (coveredRange != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Covers $coveredRange',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: AppIcon(
                    AppIcons.expand,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _TafsirBody(
              text: entry.text,
              textScale: textScale,
              searchQuery: searchQuery,
              searchTargetBlockIndex: searchTargetBlockIndex,
              searchHitKey: searchHitKey,
            ),
          ),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

class _TafsirBody extends StatelessWidget {
  const _TafsirBody({
    required this.text,
    required this.textScale,
    required this.searchQuery,
    required this.searchTargetBlockIndex,
    required this.searchHitKey,
  });

  final String text;
  final double textScale;
  final String searchQuery;
  final int? searchTargetBlockIndex;
  final GlobalKey? searchHitKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = htmlToTafsirBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: blocks[i].isHeading ? 24 : 14),
          KeyedSubtree(
            key: i == searchTargetBlockIndex ? searchHitKey : null,
            child: _TafsirTextBlockView(
              block: blocks[i],
              textScale: textScale,
              searchQuery: searchQuery,
            ),
          ),
          if (blocks[i].isHeading) const SizedBox(height: 4),
        ],
        if (blocks.isEmpty)
          SelectableText(
            htmlToPlainText(text),
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) * textScale,
            ),
          ),
      ],
    );
  }
}

class _TafsirTextBlockView extends StatelessWidget {
  const _TafsirTextBlockView({
    required this.block,
    required this.textScale,
    required this.searchQuery,
  });

  final TafsirTextBlock block;
  final double textScale;
  final String searchQuery;

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
            fontSize: (block.isHeading ? headingSize : 23) * textScale,
            fontWeight: block.isHeading ? FontWeight.w700 : FontWeight.w400,
            height: 1.7,
          )
        : block.isHeading
            ? (isRtl ? 'ur' : 'en').scriptStyle(
                baseStyle?.copyWith(
                      fontWeight: isRtl ? FontWeight.w400 : FontWeight.w700,
                      fontSize: (isRtl ? 20 : headingSize) * textScale,
                      height: isRtl ? 2.35 : 1.22,
                    ) ??
                    const TextStyle(),
                isRtl: isRtl,
              )
            : (isRtl ? 'ur' : 'en').scriptStyle(
                baseStyle?.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize:
                          (isRtl ? 18 : baseStyle.fontSize ?? 16) * textScale,
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
      _highlightedSpan(
        textStyle: textStyle,
        spans: block.spans,
        mutedColor: cs.onSurfaceVariant.withValues(alpha: 0.62),
        arabicColor: cs.primary,
        highlightColor: cs.tertiaryContainer.withValues(alpha: 0.72),
      ),
      textAlign: isRtl ? TextAlign.right : TextAlign.left,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  TextSpan _highlightedSpan({
    required TextStyle textStyle,
    required List<TafsirTextSpan> spans,
    required Color mutedColor,
    required Color arabicColor,
    required Color highlightColor,
  }) {
    final query = searchQuery.trim();
    if (query.isEmpty) {
      return TextSpan(
        style: textStyle,
        children: [
          for (final span in spans)
            TextSpan(
              text: span.text,
              style: _spanStyle(span, textStyle, mutedColor, arabicColor),
            ),
        ],
      );
    }
    return TextSpan(
      style: textStyle,
      children: [
        for (final span in spans)
          ..._highlightPieces(
            span,
            query,
            _spanStyle(span, textStyle, mutedColor, arabicColor),
            highlightColor,
          ),
      ],
    );
  }

  List<TextSpan> _highlightPieces(
    TafsirTextSpan span,
    String query,
    TextStyle? style,
    Color highlightColor,
  ) {
    final lowerText = span.text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final pieces = <TextSpan>[];
    var offset = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, offset);
      if (index < 0) break;
      if (index > offset) {
        pieces.add(
          TextSpan(text: span.text.substring(offset, index), style: style),
        );
      }
      pieces.add(
        TextSpan(
          text: span.text.substring(index, index + query.length),
          style: (style ?? const TextStyle()).copyWith(
            backgroundColor: highlightColor,
          ),
        ),
      );
      offset = index + query.length;
    }
    if (offset < span.text.length) {
      pieces.add(TextSpan(text: span.text.substring(offset), style: style));
    }
    return pieces.isEmpty ? [TextSpan(text: span.text, style: style)] : pieces;
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
        fontSize: ((baseStyle?.fontSize ?? 17) + 3) * textScale,
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
    required this.textScale,
  });

  final Ayah ayah;
  final List<TranslationResource> resources;
  final double textScale;

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
              style: QuranTextStyle.madani.copyWith(fontSize: 26 * textScale),
            ),
            for (final resource in resources)
              if (ayah.translations[resource.slug] != null)
                _TafsirTranslationText(
                  resource: resource,
                  text: ayah.translations[resource.slug]!,
                  textScale: textScale,
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
    required this.textScale,
  });

  final TranslationResource resource;
  final String text;
  final double textScale;

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
              theme.textTheme.bodyMedium!.copyWith(
                height: 1.5,
                fontSize:
                    (theme.textTheme.bodyMedium?.fontSize ?? 14) * textScale,
              ),
              isRtl: isRtl,
            ),
          ),
        ],
      ),
    );
  }
}
