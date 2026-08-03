import 'package:flutter/material.dart';

/// Small "Experimental" badge for editions still `beta-unverified` upstream
/// (see `TranslationResource.experimental` / `EditionItem.experimental`,
/// sourced from the DB's `resources.experimental` column). Shared by the
/// Translations picker and the reader's per-verse credit line.
class ExperimentalPill extends StatelessWidget {
  const ExperimentalPill({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          'Experimental',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onTertiaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
