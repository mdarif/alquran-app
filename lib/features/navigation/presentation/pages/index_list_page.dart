import 'package:flutter/material.dart';

import '../../domain/entities/index_kind.dart';
import '../widgets/index_list_view.dart';

/// A full screen for one index dimension (Page / Juz / Hizb / Ruku).
/// The Read tab embeds Juz/Page directly; this remains useful for standalone
/// or future advanced index entry points.
class IndexListPage extends StatelessWidget {
  const IndexListPage({required this.kind, required this.label, super.key});

  final IndexKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: IndexListView(kind: kind, label: label),
    );
  }
}
