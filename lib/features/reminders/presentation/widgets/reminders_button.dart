import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../cubit/reminders_cubit.dart';
import '../cubit/reminders_state.dart';
import 'reminders_sheet.dart';

/// App-bar bell that opens the Sunnah-reminders sheet. Filled when reminders are
/// on, outline when off. Reads the cubit DEFENSIVELY (like the prayer pill) so a
/// screen pumped without it renders nothing.
class RemindersButton extends StatelessWidget {
  const RemindersButton({super.key});

  @override
  Widget build(BuildContext context) {
    RemindersCubit? cubit;
    try {
      cubit = BlocProvider.of<RemindersCubit>(context);
    } catch (_) {
      cubit = null;
    }
    if (cubit == null) return const SizedBox.shrink();

    final bloc = cubit;
    return BlocBuilder<RemindersCubit, RemindersState>(
      bloc: bloc,
      builder: (context, state) {
        return IconButton(
          key: WidgetKeys.remindersButton,
          tooltip: 'Sunnah reminders',
          icon: AppIcon(AppIcons.reminders, filled: state.enabled),
          onPressed: () => _open(context, bloc),
        );
      },
    );
  }

  void _open(BuildContext context, RemindersCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider<RemindersCubit>.value(
        value: cubit,
        child: const RemindersSheet(),
      ),
    );
  }
}
