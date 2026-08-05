import 'package:flutter/material.dart';

import 'pages/tafsir_page.dart';

Future<void> showTafsirSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.78,
      alignment: Alignment.bottomCenter,
      child: TafsirPage(),
    ),
  );
}
