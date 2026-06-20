import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
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
      child: _ReaderView(title: target.title),
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({required this.title});

  final String title;

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
  double _arabicFont = 28;

  // Default to the lightweight Mushaf reading view (PRD lists Reading first);
  // one touch on the app-bar toggle reveals the translations.
  _Viewport _viewport = _Viewport.reading;

  // Pinch tracking. We use a raw Listener (not GestureDetector.onScale) so the
  // gesture does NOT enter the arena — single-finger scroll and text selection
  // keep working, and only a genuine two-finger pinch rescales the font.
  final Map<int, Offset> _pointers = {};
  double? _pinchBaseDistance;
  double _fontAtPinchStart = 28;

  @override
  Widget build(BuildContext context) {
    final isReading = _viewport == _Viewport.reading;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
            onPressed: () => _setFont(_arabicFont - 2),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Larger',
            onPressed: () => _setFont(_arabicFont + 2),
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
              switch (state.status) {
                case ReaderStatus.initial:
                case ReaderStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case ReaderStatus.error:
                  return Center(child: Text(state.error ?? 'Failed to load'));
                case ReaderStatus.loaded:
                  if (isReading) {
                    return MushafView(
                      ayahs: state.ayahs,
                      headings: state.headings,
                      arabicFontSize: _arabicFont,
                    );
                  }
                  return _DetailedList(
                    ayahs: state.ayahs,
                    resources: state.resources,
                    headings: state.headings,
                    arabicFontSize: _arabicFont,
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  // --- Pinch-to-zoom (two-finger) -------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
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
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchBaseDistance = null;
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
  });

  final List<Ayah> ayahs;
  final List<TranslationResource> resources;
  final Map<int, SurahHeading> headings;
  final double arabicFontSize;

  @override
  Widget build(BuildContext context) {
    // Flatten into header/ayah rows so the list stays lazy.
    final rows = <Object>[];
    int? lastSurah;
    for (final ayah in ayahs) {
      if (ayah.surahId != lastSurah) {
        rows.add(_HeaderMarker(ayah.surahId));
        lastSurah = ayah.surahId;
      }
      rows.add(ayah);
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) {
        return const SizedBox.shrink();
      },
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is _HeaderMarker) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, i == 0 ? 12 : 20, 16, 4),
            child: SurahHeaderCard(
              heading: headings[row.surahId],
              fallbackNumber: row.surahId,
            ),
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
  const _HeaderMarker(this.surahId);
  final int surahId;
}
