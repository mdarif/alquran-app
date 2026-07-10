import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/ayah_recitation_player.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../cubit/ayah_audio_cubit.dart';
import '../cubit/reader_cubit.dart';

/// Reciter name shown in the player (single reciter for now; a picker is a
/// follow-up). Mirrors the attribution in credits_page.
const String _kReciterName = 'Mishary Rashid Alafasy';

const List<double> _kSpeeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// The index of [id] in the loaded section, or -1. Drives the prev/next enable
/// state (disabled at the section's first/last verse).
int _indexOf(ReaderState s, int? id) =>
    id == null ? -1 : s.ayahs.indexWhere((a) => a.id == id);

/// Always-on, **single-row** player pinned below the reader in both viewports —
/// the whole playback UI (deliberately minimal: no modal sheet, no seek scrubber,
/// no stop). Lives in the Scaffold's bottomNavigationBar slot, outside the
/// reader's pinch/swipe gesture arena.
///
/// - **Idle** (nothing loaded): a Play + the reciter's name.
/// - **Active** (playing / paused / loading / error): a thin progress line over
///   one row — `repeat · prev · play-pause · next · speed`. There's no verse
///   label; the gold-highlighted verse on the page shows which one is playing.
class ReaderPlayerBar extends StatelessWidget {
  const ReaderPlayerBar({this.queuedAyahId, super.key});

  /// The verse the reader tapped/selected in Reading — the target of the idle
  /// Play. Null falls back to the section's first verse.
  final int? queuedAyahId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      // Rebuild on status/verse/settings — NOT on position (that rides the
      // progressStream in the thin line below).
      builder: (context, audio) {
        final cs = Theme.of(context).colorScheme;
        // Active = a verse is loaded (playing / paused / buffering) or errored.
        final active = audio.playingAyahId != null ||
            audio.status == RecitationStatus.error;
        return Material(
          key: WidgetKeys.playerBar,
          color: cs.surfaceContainer,
          elevation: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) _ProgressLine(cs: cs),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.symmetric(horizontal: 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: active
                      ? _ActiveRow(audio: audio)
                      : _IdleRow(queuedAyahId: queuedAyahId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Active transport — everything in one row (no sheet, no scrubber, no stop).
class _ActiveRow extends StatelessWidget {
  const _ActiveRow({required this.audio});
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderCubit>().state;
    final idx = _indexOf(reader, audio.playingAyahId);
    final hasPrev = idx > 0;
    final hasNext = idx >= 0 && idx < reader.ayahs.length - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RepeatButton(audio: audio),
        _TransportButton(
          keyValue: WidgetKeys.playerBarPrev,
          icon: AppIcons.skipPrevious,
          tooltip: 'Previous verse',
          onPressed: hasPrev
              ? () => context.read<AyahAudioCubit>().playPrevious()
              : null,
        ),
        _PlayPauseButton(keyValue: WidgetKeys.playerBarPlay, audio: audio),
        _TransportButton(
          keyValue: WidgetKeys.playerBarNext,
          icon: AppIcons.skipNext,
          tooltip: 'Next verse',
          onPressed:
              hasNext ? () => context.read<AyahAudioCubit>().playNext() : null,
        ),
        _SpeedButton(audio: audio),
      ],
    );
  }
}

/// The idle row (nothing loaded) — minimal, quran.com-style: just a Play and the
/// reciter's name. Play starts the cued verse (the one the reader tapped), or the
/// section's first verse when nothing is cued.
class _IdleRow extends StatelessWidget {
  const _IdleRow({required this.queuedAyahId});
  final int? queuedAyahId;

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderCubit>().state;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final target = queuedAyahId ??
        (reader.ayahs.isNotEmpty ? reader.ayahs.first.id : null);
    return Row(
      children: [
        IconButton(
          key: WidgetKeys.playerBarPlay,
          tooltip: 'Play',
          visualDensity: VisualDensity.compact,
          icon: AppIcon(
            AppIcons.play,
            size: AppIconSize.action,
            color: target == null ? cs.onSurfaceVariant : cs.primary,
          ),
          onPressed: target == null
              ? null
              : () => context.read<AyahAudioCubit>().toggle(target),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _kReciterName,
            style: t.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

/// The thin 2px progress line at the top of the bar — its own StreamBuilder so
/// only it repaints on the ~5×/s position tick.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackProgress>(
      stream: context.read<AyahAudioCubit>().progress,
      builder: (context, snap) {
        final p = snap.data;
        final dur = p?.duration?.inMilliseconds ?? 0;
        // Determinate (0 when the duration is unknown), never the indeterminate
        // form — that animates forever and would hang `pumpAndSettle` in tests
        // and burn frames in the app while buffering.
        final value = (p != null && dur > 0)
            ? (p.position.inMilliseconds / dur).clamp(0.0, 1.0)
            : 0.0;
        return LinearProgressIndicator(
          value: value,
          minHeight: 2,
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.tertiary,
        );
      },
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.keyValue,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key keyValue;
  final IconData icon;
  final String tooltip;
  // Null → the button renders disabled (dimmed) — e.g. prev/next at a bound.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: keyValue,
      icon: AppIcon(icon, size: AppIconSize.action),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

/// Play/pause (with a loading spinner and error-retry), keyed off the audio
/// status. Calls `toggle` on the loaded verse.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.keyValue, required this.audio});

  final Key keyValue;
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    const size = AppIconSize.action;
    final cs = Theme.of(context).colorScheme;
    final id = audio.playingAyahId;
    if (audio.status == RecitationStatus.loading) {
      return SizedBox(
        width: size + 16,
        height: size + 16,
        child: Center(
          child: SizedBox(
            width: size * 0.8,
            height: size * 0.8,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
        ),
      );
    }
    final isPlaying = audio.status == RecitationStatus.playing;
    final isError = audio.status == RecitationStatus.error;
    return IconButton(
      key: keyValue,
      icon: AppIcon(
        isError
            ? AppIcons.audioError
            : (isPlaying ? AppIcons.pause : AppIcons.play),
        size: size,
        color: isError ? cs.error : cs.primary,
      ),
      tooltip: isError ? 'Retry' : (isPlaying ? 'Pause' : 'Play'),
      visualDensity: VisualDensity.compact,
      onPressed:
          id == null ? null : () => context.read<AyahAudioCubit>().toggle(id),
    );
  }
}

/// Repeat cycle: off → repeat verse → repeat surah → off. The icon tells them
/// apart — a dim repeat glyph is off, primary repeat-one is verse, primary repeat
/// is the whole surah (loops back to the first verse at the end).
class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.audio});
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repeat = audio.repeat;
    final (IconData icon, String tip, RecitationRepeat next) = switch (repeat) {
      RecitationRepeat.off => (
          AppIcons.repeat,
          'Repeat: off',
          RecitationRepeat.one,
        ),
      RecitationRepeat.one => (
          AppIcons.repeatOne,
          'Repeat verse',
          RecitationRepeat.all,
        ),
      RecitationRepeat.all => (
          AppIcons.repeat,
          'Repeat surah',
          RecitationRepeat.off,
        ),
    };
    return IconButton(
      key: WidgetKeys.playerRepeat,
      tooltip: tip,
      icon: AppIcon(
        icon,
        color:
            repeat == RecitationRepeat.off ? cs.onSurfaceVariant : cs.primary,
      ),
      onPressed: () => context.read<AyahAudioCubit>().setRepeat(next),
    );
  }
}

String _speedLabel(double s) =>
    s == s.roundToDouble() ? '${s.toStringAsFixed(0)}×' : '$s×';

/// Playback speed — a menu of the presets (with the current one checked), so the
/// choice is visible up-front rather than a blind cycle-on-tap.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.audio});
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<double>(
      key: WidgetKeys.playerSpeed,
      tooltip: 'Playback speed',
      initialValue: audio.speed,
      onSelected: (v) => context.read<AyahAudioCubit>().setSpeed(v),
      itemBuilder: (context) => [
        for (final s in _kSpeeds)
          CheckedPopupMenuItem<double>(
            value: s,
            checked: s == audio.speed,
            child: Text(_speedLabel(s)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          _speedLabel(audio.speed),
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
