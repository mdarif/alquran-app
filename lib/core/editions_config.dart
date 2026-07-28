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
/// NOTE: the bucket is not provisioned yet. Until it is, the Translations
/// screen will list only what is bundled and report the catalogue as
/// unavailable — which is the correct, honest behaviour rather than an error.
const String editionCatalogueUrl = String.fromEnvironment(
  'EDITIONS_CATALOGUE_URL',
  defaultValue: 'https://editions.alquranreader.com/catalogue.json',
);
