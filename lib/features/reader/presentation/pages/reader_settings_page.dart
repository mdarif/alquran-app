import 'package:flutter/material.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/arabic_script.dart';
import '../../domain/entities/translation_resource.dart';

// Samples are copied from real DB text (text_arabic_uthmani /
// text_arabic_indopak) rather than hand-typed, so the IndoPak form renders
// cleanly in Noorehuda.
const String _uthmaniSample = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';
const String _indopakSample = 'بِسۡمِ اللّٰهِ الرَّحۡمٰنِ الرَّحِيۡمِ';

class SettingsAction {
  const SettingsAction({
    required this.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.section = SettingsActionSection.app,
    this.showsChevron = false,
    this.switchValue,
    this.onSwitchChanged,
  });

  final Key key;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final SettingsActionSection section;
  final bool showsChevron;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
}

enum SettingsActionSection {
  reading('Reading'),
  reminders('Reminders'),
  app('App'),
  debug('Debug');

  const SettingsActionSection(this.label);

  final String label;
}

/// The unified Settings screen: reading preferences first, optional app-level
/// actions after them. Reader opens this with live callbacks; Home opens it with
/// persisted callbacks, so both paths feel like one place.
class ReaderSettingsPage extends StatefulWidget {
  const ReaderSettingsPage({
    required this.fontSize,
    required this.minFont,
    required this.maxFont,
    required this.onFontChanged,
    required this.script,
    required this.onScriptChanged,
    required this.resources,
    required this.activeTranslationSummary,
    required this.onOpenTranslations,
    this.showTranslations = true,
    required this.isReading,
    required this.showTranslationPeek,
    required this.onToggleTranslationPeek,
    required this.showArabicMatn,
    required this.onToggleShowArabic,
    required this.onReset,
    this.appActions = const [],
    super.key,
  });

  final double fontSize;
  final double minFont;
  final double maxFont;
  final ValueChanged<double> onFontChanged;
  final ArabicScript script;
  final ValueChanged<ArabicScript> onScriptChanged;
  final List<TranslationResource> resources;
  final String activeTranslationSummary;
  final VoidCallback onOpenTranslations;
  final bool showTranslations;
  final bool isReading;
  final bool showTranslationPeek;
  final ValueChanged<bool> onToggleTranslationPeek;
  final bool showArabicMatn;
  final ValueChanged<bool> onToggleShowArabic;
  final VoidCallback onReset;
  final List<SettingsAction> appActions;

  @override
  State<ReaderSettingsPage> createState() => _ReaderSettingsPageState();
}

class _ReaderSettingsPageState extends State<ReaderSettingsPage> {
  static const double _step = 2;
  static const double _sectionGap = 18;
  static const double _labelGap = 7;

  late double _fontSize = widget.fontSize;
  late ArabicScript _script = widget.script;
  late bool _showPeek = widget.showTranslationPeek;
  late bool _showArabic = widget.showArabicMatn;

  List<SettingsAction> _actions(SettingsActionSection section) => [
        for (final action in widget.appActions)
          if (action.section == section) action,
      ];

  void _setFont(double value) {
    final v = value.clamp(widget.minFont, widget.maxFont).roundToDouble();
    if (v == _fontSize) return;
    setState(() => _fontSize = v);
    widget.onFontChanged(v);
  }

  void _setScript(ArabicScript value) {
    if (value == _script) return;
    setState(() => _script = value);
    widget.onScriptChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rowTitleStyle =
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    final rowSubtitleStyle = theme.textTheme.labelLarge
        ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w400);
    return Scaffold(
      key: WidgetKeys.readerSettingsPage,
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(
                'Text Size',
                trailing: Text(
                  '${_fontSize.round()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _StepButton(
                    key: WidgetKeys.fontDecrease,
                    glyphSize: 14,
                    tooltip: 'Smaller text',
                    onPressed: _fontSize > widget.minFont
                        ? () => _setFont(_fontSize - _step)
                        : null,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 9,
                          elevation: 1,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                        activeTickMarkColor: Colors.transparent,
                        inactiveTickMarkColor: Colors.transparent,
                      ),
                      child: Slider(
                        value: _fontSize.clamp(widget.minFont, widget.maxFont),
                        min: widget.minFont,
                        max: widget.maxFont,
                        divisions:
                            ((widget.maxFont - widget.minFont) / _step).round(),
                        semanticFormatterCallback: (v) => '${v.round()} points',
                        onChanged: _setFont,
                      ),
                    ),
                  ),
                  _StepButton(
                    key: WidgetKeys.fontIncrease,
                    glyphSize: 22,
                    tooltip: 'Larger text',
                    onPressed: _fontSize < widget.maxFont
                        ? () => _setFont(_fontSize + _step)
                        : null,
                  ),
                ],
              ),
              if (FeatureFlags.indopakScript) ...[
                const SizedBox(height: _sectionGap),
                const _SectionLabel('Arabic Script'),
                const SizedBox(height: _labelGap),
                Column(
                  key: WidgetKeys.scriptToggle,
                  children: [
                    _ScriptPreview(
                      script: ArabicScript.uthmani,
                      label: 'Uthmani/Madani',
                      description: 'Madinah Mushaf',
                      sample: _uthmaniSample,
                      sampleStyle: QuranTextStyle.madani,
                      selected: _script == ArabicScript.uthmani,
                      onTap: () => _setScript(ArabicScript.uthmani),
                    ),
                    const SizedBox(height: 6),
                    _ScriptPreview(
                      script: ArabicScript.indopak,
                      label: 'IndoPak/Asian',
                      description: 'South-Asian Naskh',
                      sample: _indopakSample,
                      sampleStyle: QuranTextStyle.indopak,
                      selected: _script == ArabicScript.indopak,
                      onTap: () => _setScript(ArabicScript.indopak),
                    ),
                  ],
                ),
              ],
              _ActionSection(
                label: SettingsActionSection.reading.label,
                actions: _actions(SettingsActionSection.reading),
                rowTitleStyle: rowTitleStyle,
                colorScheme: cs,
                trailing: ListTile(
                  key: WidgetKeys.readerSettingsReset,
                  dense: true,
                  minVerticalPadding: 4,
                  contentPadding: EdgeInsets.zero,
                  leading: AppIcon(AppIcons.reset, color: cs.error),
                  title: Text(
                    'Reset Reading Preferences',
                    style: rowTitleStyle?.copyWith(color: cs.error),
                  ),
                  subtitle: Text(
                    'Font size, script, translations shown and reading aids.',
                    style: rowSubtitleStyle,
                  ),
                  onTap: widget.onReset,
                ),
              ),
              if (widget.showTranslations && widget.resources.isNotEmpty) ...[
                const SizedBox(height: _sectionGap),
                const _SectionLabel('Translation'),
                ListTile(
                  dense: true,
                  minVerticalPadding: 4,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Translations', style: rowTitleStyle),
                  subtitle: Text(
                    widget.activeTranslationSummary,
                    style: rowSubtitleStyle,
                  ),
                  trailing: const AppIcon(AppIcons.chevronRight),
                  onTap: widget.onOpenTranslations,
                ),
              ],
              if (FeatureFlags.readingTranslationPeek &&
                  widget.isReading &&
                  widget.resources.isNotEmpty) ...[
                const SizedBox(height: _sectionGap),
                const _SectionLabel('Reading'),
                SwitchListTile.adaptive(
                  key: WidgetKeys.translationPeekToggle,
                  value: _showPeek,
                  onChanged: (v) {
                    setState(() => _showPeek = v);
                    widget.onToggleTranslationPeek(v);
                  },
                  dense: true,
                  minVerticalPadding: 4,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Show translation', style: rowTitleStyle),
                  subtitle: Text(
                    'Tap a verse to see its translation.',
                    style: rowSubtitleStyle,
                  ),
                ),
              ],
              if (!widget.isReading && widget.resources.isNotEmpty) ...[
                const SizedBox(height: _sectionGap),
                const _SectionLabel('Detailed'),
                SwitchListTile.adaptive(
                  key: WidgetKeys.showArabicToggle,
                  value: _showArabic,
                  onChanged: (v) {
                    setState(() => _showArabic = v);
                    widget.onToggleShowArabic(v);
                  },
                  dense: true,
                  minVerticalPadding: 4,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Show Arabic', style: rowTitleStyle),
                  subtitle: Text(
                    'Turn off to read translations only.',
                    style: rowSubtitleStyle,
                  ),
                ),
              ],
              _ActionSection(
                label: SettingsActionSection.reminders.label,
                actions: _actions(SettingsActionSection.reminders),
                rowTitleStyle: rowTitleStyle,
                colorScheme: cs,
              ),
              _ActionSection(
                label: SettingsActionSection.app.label,
                actions: _actions(SettingsActionSection.app),
                rowTitleStyle: rowTitleStyle,
                colorScheme: cs,
              ),
              _ActionSection(
                label: SettingsActionSection.debug.label,
                actions: _actions(SettingsActionSection.debug),
                rowTitleStyle: rowTitleStyle,
                colorScheme: cs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.label,
    required this.actions,
    required this.rowTitleStyle,
    required this.colorScheme,
    this.trailing,
  });

  final String label;
  final List<SettingsAction> actions;
  final TextStyle? rowTitleStyle;
  final ColorScheme colorScheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && trailing == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _ReaderSettingsPageState._sectionGap),
        _SectionLabel(label),
        const SizedBox(height: 2),
        for (final action in actions)
          ListTile(
            key: action.key,
            dense: true,
            minVerticalPadding: 4,
            contentPadding: EdgeInsets.zero,
            leading: AppIcon(
              action.icon,
              size: AppIconSize.action,
              color: colorScheme.onSurface.withValues(alpha: 0.70),
            ),
            title: Text(action.title, style: rowTitleStyle),
            trailing: action.switchValue != null
                ? Switch.adaptive(
                    value: action.switchValue!,
                    onChanged: action.onSwitchChanged,
                  )
                : (action.showsChevron
                    ? const AppIcon(AppIcons.chevronRight)
                    : null),
            onTap: action.onTap,
          ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.glyphSize,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final double glyphSize;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Text(
        'A',
        style: TextStyle(
          fontSize: glyphSize,
          fontWeight: FontWeight.w600,
          color: onPressed == null
              ? cs.onSurface.withValues(alpha: 0.3)
              : cs.onSurface,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _ScriptPreview extends StatelessWidget {
  const _ScriptPreview({
    required this.script,
    required this.label,
    required this.description,
    required this.sample,
    required this.sampleStyle,
    required this.selected,
    required this.onTap,
  });

  final ArabicScript script;
  final String label;
  final String description;
  final String sample;
  final TextStyle sampleStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.32)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: InkWell(
          key: WidgetKeys.scriptCard(script.name),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            sample,
                            textDirection: TextDirection.rtl,
                            locale: const Locale('ar'),
                            style: sampleStyle.copyWith(
                              fontSize: 25,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 22,
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: cs.primary,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: '  ·  $description'),
                    ],
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
