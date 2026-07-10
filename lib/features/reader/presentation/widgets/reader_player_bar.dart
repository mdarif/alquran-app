import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/ayah_recitation_player.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/ayah.dart';
import '../cubit/ayah_audio_cubit.dart';
import '../cubit/reader_cubit.dart';

/// Reciter name shown in the player (single reciter for now; a picker is a
/// follow-up — see the audio plan). Mirrors the attribution in credits_page.
const String _kReciterName = 'Mishary Rashid Alafasy';

const List<double> _kSpeeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// "{Surah} · {ayah}" for the verse currently loaded in the player, resolved from
/// the reader's loaded section. Null if the verse isn't in the section (shouldn't
/// happen — audio is section-bounded).
String? _nowPlayingRef(ReaderState s, int? playingId) {
  if (playingId == null) return null;
  Ayah? ayah;
  for (final a in s.ayahs) {
    if (a.id == playingId) {
      ayah = a;
      break;
    }
  }
  if (ayah == null) return null;
  final name = s.headings[ayah.surahId]?.nameEnglish ?? 'Surah ${ayah.surahId}';
  return '$name · ${ayah.ayahNumber}';
}

/// Persistent mini player pinned below the reader while a verse is loaded. Shows
/// the reciter/verse, a thin progress line, and the core transport; tapping the
/// body opens the full [ReaderPlayerSheet]. Lives in the Scaffold's
/// bottomNavigationBar slot, so it's outside the reader's pinch/swipe gesture
/// arena and stacks naturally below the Reading peek card.
class ReaderPlayerBar extends StatelessWidget {
  const ReaderPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      // Rebuild on status/verse/settings — NOT on position (that rides the
      // progressStream in the thin line below).
      builder: (context, audio) {
        final id = audio.playingAyahId;
        final visible = id != null || audio.status == RecitationStatus.error;
        final cs = Theme.of(context).colorScheme;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !visible
              ? const SizedBox(width: double.infinity)
              : Material(
                  key: WidgetKeys.playerBar,
                  color: cs.surfaceContainer,
                  elevation: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ProgressLine(cs: cs),
                      SafeArea(
                        top: false,
                        minimum: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => _openPlayerSheet(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                AppIcon(
                                  AppIcons.play,
                                  size: AppIconSize.label,
                                  color: cs.tertiary,
                                  filled: true,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: _NowPlayingLabel(audio: audio)),
                                _TransportButton(
                                  keyValue: WidgetKeys.playerBarPrev,
                                  icon: AppIcons.skipPrevious,
                                  tooltip: 'Previous verse',
                                  onPressed: () => context
                                      .read<AyahAudioCubit>()
                                      .playPrevious(),
                                ),
                                _PlayPauseButton(
                                  keyValue: WidgetKeys.playerBarPlay,
                                  audio: audio,
                                  size: AppIconSize.action,
                                ),
                                _TransportButton(
                                  keyValue: WidgetKeys.playerBarNext,
                                  icon: AppIcons.skipNext,
                                  tooltip: 'Next verse',
                                  onPressed: () =>
                                      context.read<AyahAudioCubit>().playNext(),
                                ),
                                _TransportButton(
                                  keyValue: WidgetKeys.playerBarClose,
                                  icon: AppIcons.close,
                                  tooltip: 'Stop',
                                  onPressed: () =>
                                      context.read<AyahAudioCubit>().stopAll(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
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

class _NowPlayingLabel extends StatelessWidget {
  const _NowPlayingLabel({required this.audio});
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderCubit>().state;
    final ref = _nowPlayingRef(reader, audio.playingAyahId) ?? 'Recitation';
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ref,
          style: t.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          _kReciterName,
          style: t.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.keyValue,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = AppIconSize.action,
  });

  final Key keyValue;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: keyValue,
      icon: AppIcon(icon, size: size),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

/// Session play/pause (with loading spinner and error-retry), keyed off the
/// audio status. Calls `toggle` on the loaded verse, matching the per-verse
/// buttons' semantics.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.keyValue,
    required this.audio,
    this.size = AppIconSize.action,
  });

  final Key keyValue;
  final AyahAudioState audio;
  final double size;

  @override
  Widget build(BuildContext context) {
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

/// Opens the expanded full player.
void _openPlayerSheet(BuildContext context) {
  final audioCubit = context.read<AyahAudioCubit>();
  final readerCubit = context.read<ReaderCubit>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: audioCubit),
        BlocProvider.value(value: readerCubit),
      ],
      child: const ReaderPlayerSheet(),
    ),
  );
}

/// The expanded full player: reciter, now-playing reference, a seek scrubber, the
/// full transport (prev / play-pause / next), repeat, speed, and a continuous
/// toggle. Reads transport state from [AyahAudioCubit]; position from its
/// progressStream (scoped to the scrubber).
class ReaderPlayerSheet extends StatelessWidget {
  const ReaderPlayerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (context, audio) {
        final ref = _nowPlayingRef(
              context.watch<ReaderCubit>().state,
              audio.playingAyahId,
            ) ??
            'Recitation';
        return SafeArea(
          top: false,
          child: Padding(
            key: WidgetKeys.playerSheet,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ref, style: t.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(
                  _kReciterName,
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _Scrubber(cs: cs),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RepeatButton(audio: audio),
                    _TransportButton(
                      keyValue: WidgetKeys.playerBarPrev,
                      icon: AppIcons.skipPrevious,
                      tooltip: 'Previous verse',
                      size: AppIconSize.bar,
                      onPressed: () =>
                          context.read<AyahAudioCubit>().playPrevious(),
                    ),
                    _BigPlayPause(audio: audio),
                    _TransportButton(
                      keyValue: WidgetKeys.playerBarNext,
                      icon: AppIcons.skipNext,
                      tooltip: 'Next verse',
                      size: AppIconSize.bar,
                      onPressed: () =>
                          context.read<AyahAudioCubit>().playNext(),
                    ),
                    _SpeedButton(audio: audio),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  key: WidgetKeys.playerContinuous,
                  value: audio.continuousPlay,
                  onChanged: (v) =>
                      context.read<AyahAudioCubit>().setContinuous(v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Continuous play'),
                  subtitle:
                      const Text('Roll into the next verse automatically'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The seek slider. Local drag state so dragging isn't yanked by the incoming
/// position stream; commits on drag end via `seek`.
class _Scrubber extends StatefulWidget {
  const _Scrubber({required this.cs});
  final ColorScheme cs;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  double? _dragValue; // 0..1 while dragging; null otherwise

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackProgress>(
      stream: context.read<AyahAudioCubit>().progress,
      builder: (context, snap) {
        final p = snap.data ?? const PlaybackProgress();
        final dur = p.duration ?? Duration.zero;
        final durMs = dur.inMilliseconds;
        final posFrac = durMs > 0
            ? (p.position.inMilliseconds / durMs).clamp(0.0, 1.0)
            : 0.0;
        final value = _dragValue ?? posFrac;
        return Column(
          children: [
            Slider(
              key: WidgetKeys.playerScrubber,
              value: value,
              onChanged:
                  durMs > 0 ? (v) => setState(() => _dragValue = v) : null,
              onChangeEnd: durMs > 0
                  ? (v) {
                      context.read<AyahAudioCubit>().seek(
                            Duration(milliseconds: (v * durMs).round()),
                          );
                      setState(() => _dragValue = null);
                    }
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(Duration(milliseconds: (value * durMs).round())),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _fmt(dur),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BigPlayPause extends StatelessWidget {
  const _BigPlayPause({required this.audio});
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = audio.playingAyahId;
    final isPlaying = audio.status == RecitationStatus.playing;
    final isLoading = audio.status == RecitationStatus.loading;
    final isError = audio.status == RecitationStatus.error;
    return SizedBox(
      width: 64,
      height: 64,
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          : IconButton.filled(
              key: WidgetKeys.playerSheetPlay,
              iconSize: 36,
              icon: AppIcon(
                isError
                    ? AppIcons.audioError
                    : (isPlaying ? AppIcons.pause : AppIcons.play),
                size: 36,
                color: cs.onPrimary,
              ),
              onPressed: id == null
                  ? null
                  : () => context.read<AyahAudioCubit>().toggle(id),
            ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.audio});
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = audio.repeat == RecitationRepeat.one;
    return IconButton(
      key: WidgetKeys.playerRepeat,
      tooltip: on ? 'Repeat verse: on' : 'Repeat verse: off',
      icon: AppIcon(
        on ? AppIcons.repeatOne : AppIcons.repeat,
        color: on ? cs.primary : cs.onSurfaceVariant,
      ),
      onPressed: () => context.read<AyahAudioCubit>().setRepeat(
            on ? RecitationRepeat.off : RecitationRepeat.one,
          ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.audio});
  final AyahAudioState audio;

  @override
  Widget build(BuildContext context) {
    final label = audio.speed == audio.speed.roundToDouble()
        ? '${audio.speed.toStringAsFixed(0)}×'
        : '${audio.speed}×';
    return TextButton(
      key: WidgetKeys.playerSpeed,
      onPressed: () {
        final i = _kSpeeds.indexOf(audio.speed);
        final next = _kSpeeds[(i < 0 ? 1 : (i + 1) % _kSpeeds.length)];
        context.read<AyahAudioCubit>().setSpeed(next);
      },
      child: Text(label),
    );
  }
}
