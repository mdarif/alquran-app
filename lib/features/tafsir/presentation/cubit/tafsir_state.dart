part of 'tafsir_cubit.dart';

enum TafsirStatus { initial, loading, ready }

enum TafsirItemStatus { available, installing, installed, failed, unavailable }

class TafsirState extends Equatable {
  const TafsirState({
    this.status = TafsirStatus.initial,
    this.items = const [],
    this.catalogueUnavailable = false,
    this.failure,
  });

  final TafsirStatus status;
  final List<TafsirItem> items;
  final bool catalogueUnavailable;
  final String? failure;

  bool isInstalling(String slug) =>
      item(slug)?.status == TafsirItemStatus.installing;

  TafsirItem? item(String slug) {
    for (final item in items) {
      if (item.slug == slug) return item;
    }
    return null;
  }

  TafsirState copyWith({
    TafsirStatus? status,
    List<TafsirItem>? items,
    bool? catalogueUnavailable,
    String? failure,
    bool clearFailure = false,
  }) =>
      TafsirState(
        status: status ?? this.status,
        items: items ?? this.items,
        catalogueUnavailable: catalogueUnavailable ?? this.catalogueUnavailable,
        failure: clearFailure ? null : failure ?? this.failure,
      );

  @override
  List<Object?> get props => [status, items, catalogueUnavailable, failure];
}

class TafsirItem extends Equatable {
  const TafsirItem({
    required this.slug,
    required this.status,
    this.catalogueEntry,
    this.resource,
    this.progress = 0,
    this.plannedName,
    this.plannedSubtitle,
  });

  final String slug;
  final TafsirItemStatus status;
  final TafsirCatalogueEntry? catalogueEntry;
  final TafsirResource? resource;
  final double progress;
  final String? plannedName;
  final String? plannedSubtitle;

  String get name =>
      resource?.name ?? catalogueEntry?.name ?? plannedName ?? slug;

  String get languageCode =>
      resource?.languageCode ?? catalogueEntry?.languageCode ?? '';

  String? get nativeName => resource?.nativeName ?? catalogueEntry?.nativeName;

  String? get author =>
      resource?.displayCredit ??
      catalogueEntry?.creditName ??
      catalogueEntry?.author;

  bool get abridged => resource?.abridged ?? catalogueEntry?.abridged ?? false;

  int get sortOrder => resource?.sortOrder ?? catalogueEntry?.sortOrder ?? 0;

  String? get error => null;

  String get subtitle {
    final author = this.author;
    final language = languageCode;
    final parts = [
      if (language.isNotEmpty) language.toUpperCase(),
      if (catalogueEntry?.abridged == true || resource?.abridged == true)
        'abridged',
      if (author != null && author.isNotEmpty) author,
    ];
    return parts.isEmpty ? plannedSubtitle ?? '' : parts.join(' · ');
  }

  int get downloadBytes => catalogueEntry?.bytes ?? resource?.bytes ?? 0;

  TafsirItem copyWith({
    TafsirItemStatus? status,
    double? progress,
  }) =>
      TafsirItem(
        slug: slug,
        status: status ?? this.status,
        catalogueEntry: catalogueEntry,
        resource: resource,
        progress: progress ?? this.progress,
        plannedName: plannedName,
        plannedSubtitle: plannedSubtitle,
      );

  @override
  List<Object?> get props => [
        slug,
        status,
        catalogueEntry,
        resource,
        progress,
        plannedName,
        plannedSubtitle,
      ];
}

class TafsirAyahResult extends Equatable {
  const TafsirAyahResult({required this.resource, required this.entry});

  final TafsirResource resource;
  final TafsirEntry entry;

  @override
  List<Object?> get props => [resource, entry];
}
