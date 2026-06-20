import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_cubit.dart';

/// One-tap light/dark switch, placed in app bars so it's always within reach.
/// Shows the mode it will switch TO (moon in light, sun in dark).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Light mode' : 'Dark mode',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => context.read<ThemeCubit>().toggle(),
    );
  }
}
