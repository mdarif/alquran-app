/// Which Arabic script the reader renders the Quran text in.
///
/// [uthmani] is the default — the KFGQPC Madani/Uthmani text
/// (`text_arabic_uthmani`, UthmanicHafs font). [indopak] is the South-Asian
/// Naskh option (`text_arabic_indopak`, Noorehuda font), gated behind
/// `FeatureFlags.indopakScript`.
enum ArabicScript { uthmani, indopak }
