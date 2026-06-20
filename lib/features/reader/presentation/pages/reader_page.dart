import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../../../core/theme/theme_toggle_button.dart';
import '../../domain/reader_navigation.dart';
import '../../domain/repositories/reader_settings_repository.dart';
import '../cubit/reader_cubit.dart';
import '../widgets/ayah_tile.dart';
import '../widgets/mushaf_view.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({required this.target, super.key});

  final ReaderTarget target;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<ReaderCubit>()..load(target),
      child: _ReaderView(initialTarget: target),
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({required this.initialTarget});

  final ReaderTarget initialTarget;

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

/// Dual viewport (PRD 3 / 4.3): Reading = Arabic-only Mushaf flow;
/// Detailed = Arabic stacked over Urdu + Hindi translations.
enum _Viewport { reading, detailed }

class _ReaderViewState extends State<_ReaderView> {
  // Pinch-to-zoom font scaling is an accessibility requirement (PRD 4.1).
  // Bounds target 20–48pt; tune on-device.
  static const double _minFont = 20;
  static const double _maxFont = 48;

  // Reading preferences persist across launches (zoom + viewport).
  final ReaderSettingsRepository _settings =
      GetIt.I<ReaderSettingsRepository>();

  late double _arabicFont = _settings.fontSize.clamp(_minFont, _maxFont);

  // The currently displayed section. Swiping moves it to an adjacent section
  // (next/previous) within the same dimension, keeping font/viewport state.
  late ReaderTarget _target = widget.initialTarget;

  // Viewport preference (PRD lists Reading first), restored from settings.
  late _Viewport _viewport =
      _settings.detailed ? _Viewport.detailed : _Viewport.reading;

  // Pinch + swipe are both handled through a raw Listener (not GestureDetector)
  // so they do NOT enter the gesture arena. This matters because SelectionArea
  // and the scroll view claim drags in the arena — a Listener still sees every
  // pointer event, so pinch-zoom, vertical scroll, text selection, and the
  // horizontal swipe all coexist.
  final Map<int, Offset> _pointers = {};
  double? _pinchBaseDistance;
  double _fontAtPinchStart = 28;

  // Single-finger swipe tracking (distance-based; ignored once a 2nd finger
  // joins, so a pinch is never mistaken for a swipe).
  Offset? _swipeStart;
  bool _multiTouch = false;
  static const double _swipeDistance = 64;

  @override
  Widget build(BuildContext context) {
    final isReading = _viewport == _Viewport.reading;
    return Scaffold(
      appBar: AppBar(
        title: Text(_target.title),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: isReading
                ? 'Detailed view (with translation)'
                : 'Mushaf view (Arabic only)',
            onPressed: _toggleViewport,
            icon: Icon(
              isReading ? Icons.subject_rounded : Icons.menu_book_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Smaller',
            onPressed: () => _nudgeFont(-2),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Larger',
            onPressed: () => _nudgeFont(2),
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: SelectionArea(
          child: BlocBuilder<ReaderCubit, ReaderState>(
            builder: (context, state) {
              if (state.status == ReaderStatus.error) {
                return Center(child: Text(state.error ?? 'Failed to load'));
              }
              // Keep showing the previous section while the next one loads
              // (no spinner flash on swipe); spinner only before first load.
              if (state.ayahs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              // Key by the section's first ayah so a new section starts at the
              // top, while a same-section rebuild preserves scroll position.
              final sectionKey = ValueKey(state.ayahs.first.id);
              if (isReading) {
                return MushafView(
                  key: sectionKey,
                  ayahs: state.ayahs,
                  headings: state.headings,
                  arabicFontSize: _arabicFont,
                );
              }
              return _DetailedList(
                key: sectionKey,
                ayahs: state.ayahs,
                resources: state.resources,
                headings: state.headings,
                arabicFontSize: _arabicFont,
              );
            },
          ),
        ),
      ),
    );
  }

  void _goToAdjacent(int delta) {
    final cubit = context.read<ReaderCubit>();
    final next = adjacentTarget(_target, delta, cubit.state.headings);
    if (next == null) return; // at the first/last section — no wrap-around
    setState(() => _target = next);
    cubit.load(next);
  }

  // --- Pinch-to-zoom (two-finger) + swipe (one-finger) ----------------------

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 1) {
      _swipeStart = event.position;
      _multiTouch = false;
    }
    if (_pointers.length == 2) {
      // A pinch — disqualify this gesture from also being treated as a swipe.
      _multiTouch = true;
      _pinchBaseDistance = _pointerDistance();
      _fontAtPinchStart = _arabicFont;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final base = _pinchBaseDistance;
    if (_pointers.length == 2 && base != null && base > 0) {
      _setFont(_fontAtPinchStart * (_pointerDistance() / base));
    }
  }

  void _onPointerEnd(PointerEvent event) {
    final endPosition = _pointers[event.pointer] ?? event.position;
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchBaseDistance = null;
    if (_pointers.isEmpty) {
      final start = _swipeStart;
      if (_multiTouch) {
        // End of a pinch — persist the final zoom level.
        unawaited(_settings.setFontSize(_arabicFont));
      } else if (start != null) {
        _maybeSwipe(start, endPosition);
      }
      _swipeStart = null;
      _multiTouch = false;
    }
  }

  /// A deliberate, mostly-horizontal one-finger drag moves to an adjacent
  /// section: left → next, right → previous (no wrap at the bounds).
  void _maybeSwipe(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx.abs() >= _swipeDistance && dx.abs() > dy.abs()) {
      _goToAdjacent(dx < 0 ? 1 : -1);
    }
  }

  double _pointerDistance() {
    final points = _pointers.values.toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  // --------------------------------------------------------------------------

  void _toggleViewport() {
    setState(() {
      _viewport = _viewport == _Viewport.reading
          ? _Viewport.detailed
          : _Viewport.reading;
    });
    unawaited(_settings.setDetailed(_viewport == _Viewport.detailed));
  }

  /// +/- buttons: change the zoom and persist it.
  void _nudgeFont(double delta) {
    _setFont(_arabicFont + delta);
    unawaited(_settings.setFontSize(_arabicFont));
  }

  void _setFont(double value) {
    final clamped = value.clamp(_minFont, _maxFont);
    if (clamped != _arabicFont) setState(() => _arabicFont = clamped);
  }
}

/// Detailed viewport: a lazy list of ayah tiles, with a surah header inserted
/// wherever the section crosses into a new surah.
class _DetailedList extends StatelessWidget {
  const _DetailedList({
    required this.ayahs,
    required this.resources,
    required this.headings,
    required this.arabicFontSize,
    super.key,
  });

  final List<Ayah> ayahs;
  final List<TranslationResource> resources;
  final Map<int, SurahHeading> headings;
  final double arabicFontSize;

  @override
  Widget build(BuildContext context) {
    // Flatten into header/ayah rows so the list stays lazy. A header marks each
    // surah boundary, and notes whether the Basmala should precede it (shown for
    // every surah except Al-Fatihah — where it is ayah 1 — and At-Tawbah).
    final rows = <Object>[];
    int? lastSurah;
    for (final ayah in ayahs) {
      if (ayah.surahId != lastSurah) {
        rows.add(
          _HeaderMarker(
            surahId: ayah.surahId,
            showBismillah:
                ayah.ayahNumber == 1 && ayah.surahId != 1 && ayah.surahId != 9,
          ),
        );
        lastSurah = ayah.surahId;
      }
      rows.add(ayah);
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is _HeaderMarker) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, i == 0 ? 12 : 20, 16, 4),
                child: SurahHeaderCard(
                  heading: headings[row.surahId],
                  fallbackNumber: row.surahId,
                ),
              ),
              if (row.showBismillah)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Bismillah(fontSize: arabicFontSize),
                ),
            ],
          );
        }
        return AyahTile(
          ayah: row as Ayah,
          resources: resources,
          arabicFontSize: arabicFontSize,
        );
      },
    );
  }
}

class _HeaderMarker {
  const _HeaderMarker({required this.surahId, required this.showBismillah});
  final int surahId;
  final bool showBismillah;
}
