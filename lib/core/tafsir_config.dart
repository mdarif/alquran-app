/// Where downloadable Tafsir resources are served from.
///
/// Artifacts are produced by `alquran-data/pipeline/build_tafsir.py` and are
/// separate from translation editions because Tafsir preserves grouped/ranged
/// commentary rows.
const String tafsirCatalogueUrl = String.fromEnvironment(
  'TAFSIR_CATALOGUE_URL',
  defaultValue: 'https://editions.alquranreader.com/tafsir/catalogue.json',
);
