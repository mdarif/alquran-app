import 'package:flutter/material.dart';

/// A selectable language pill — the **shared** translation selector used by both
/// the reader's Settings sheet and the Reading peek card, so both places feel
/// identical.
///
/// Deliberately a constant-width pill: the label never changes and there's no
/// checkmark popping in/out, only the colour flips on selection. That keeps a
/// row of these from reflowing ("jumping") when you toggle a language — the
/// problem with Material's `FilterChip`, whose width grows when its checkmark
/// appears.
class TranslationChip extends StatelessWidget {
  const TranslationChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
