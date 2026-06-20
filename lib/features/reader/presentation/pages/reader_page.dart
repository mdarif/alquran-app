import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../cubit/reader_cubit.dart';
import '../widgets/ayah_tile.dart';
import '../widgets/mushaf_view.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({required this.surahId, required this.title, super.key});

  final int surahId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<ReaderCubit>()..load(surahId),
      child: _ReaderView(surahId: surahId, title: title),
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({required this.surahId, required this.title});

  final int surahId;
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
  double _fontAtGestureStart = 28;

  // Default to the lightweight Mushaf reading view (PRD lists Reading first);
  // one touch on the app-bar toggle reveals the translations.
  _Viewport _viewport = _Viewport.reading;

  @override
  Widget build(BuildContext context) {
    final isReading = _viewport == _Viewport.reading;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: isReading ? 'Show translation' : 'Mushaf (Arabic only)',
            isSelected: isReading,
            onPressed: _toggleViewport,
            icon: const Icon(Icons.translate),
            selectedIcon: const Icon(Icons.menu_book),
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
      body: GestureDetector(
        onScaleStart: (_) => _fontAtGestureStart = _arabicFont,
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            _setFont(_fontAtGestureStart * details.scale);
          }
        },
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
                    arabicFontSize: _arabicFont,
                    surahNumber: widget.surahId,
                    surahName: widget.title,
                  );
                }
                return ListView.separated(
                  itemCount: state.ayahs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => AyahTile(
                    ayah: state.ayahs[i],
                    resources: state.resources,
                    arabicFontSize: _arabicFont,
                  ),
                );
            }
          },
        ),
      ),
    );
  }

  void _toggleViewport() {
    setState(() {
      _viewport = _viewport == _Viewport.reading
          ? _Viewport.detailed
          : _Viewport.reading;
    });
  }

  void _setFont(double value) {
    setState(() => _arabicFont = value.clamp(_minFont, _maxFont));
  }
}
