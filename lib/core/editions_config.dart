/// Where downloadable translation editions are served from.
///
/// The artifacts are produced by `alquran-data/pipeline/build_editions.py`
/// (`<slug>.db.gz` + `catalogue.json`) and hosted on Cloudflare R2. Every
/// artifact URL is resolved **relative to this one**, so moving the bucket or
/// putting a custom domain in front of it is a one-line change here.
///
/// Overridable at build time so a device can be pointed at a staging bucket
/// without touching the source:
///
///     flutter run --dart-define=EDITIONS_CATALOGUE_URL=https://…/catalogue.json
///
/// The bucket is live in production. New editions published there appear on
/// the Translations screen without an app-store release — see
/// FeatureFlags.proactiveTranslationSync for the launch-time fetch, and note
/// the catalogue is expected to list more editions than are bundled in the
/// app binary; that's the intended, ongoing state, not a bug. If the bucket
/// is ever unreachable (no network, or genuinely down) the screen still lists
/// bundled and installed editions and reports the catalogue as unavailable —
/// the correct, honest behaviour rather than an error.
const String editionCatalogueUrl = String.fromEnvironment(
  'EDITIONS_CATALOGUE_URL',
  defaultValue: 'https://editions.alquranreader.com/catalogue.json',
);
