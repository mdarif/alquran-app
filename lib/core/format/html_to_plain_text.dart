/// Converts tafsir-source HTML (block tags + a handful of entities) into
/// plain, readable text: block-level tags become paragraph breaks, everything
/// else is stripped. Not a general-purpose HTML parser — just enough for the
/// tafsir corpus's `<p>`/`<div>`/`<h2>`/`<span>` markup.
String htmlToPlainText(String html) {
  var text = html
      .replaceAll(RegExp(r'<(p|div|h[1-6])[^>]*>', caseSensitive: false), '')
      .replaceAll(
        RegExp(r'</(p|div|h[1-6])>', caseSensitive: false),
        '\n\n',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp('<[^>]+>'), '');

  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  return text
      .split('\n')
      .map((line) => _cleanTafsirMarkers(line.trim()))
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class TafsirTextBlock {
  const TafsirTextBlock({
    required this.text,
    this.spans = const [],
    this.headingLevel,
    this.isArabic = false,
    this.isLead = false,
  });

  final String text;
  final List<TafsirTextSpan> spans;
  final int? headingLevel;
  final bool isArabic;
  final bool isLead;

  bool get isHeading => headingLevel != null;
}

class TafsirTextSpan {
  const TafsirTextSpan({
    required this.text,
    this.isMuted = false,
    this.isArabic = false,
  });

  final String text;
  final bool isMuted;
  final bool isArabic;
}

List<TafsirTextBlock> htmlToTafsirBlocks(String html) {
  final source = html.trim();
  if (!source.contains('<')) {
    final text = htmlToPlainText(source);
    return text.isEmpty
        ? const []
        : [
            TafsirTextBlock(
              text: text,
              spans: [TafsirTextSpan(text: text)],
              isArabic: _looksArabic(text),
            ),
          ];
  }

  final blocks = <TafsirTextBlock>[];
  final blockPattern = RegExp(
    r'<(h[1-6]|p|div)\b([^>]*)>(.*?)</\1>',
    caseSensitive: false,
    dotAll: true,
  );
  var offset = 0;
  for (final match in blockPattern.allMatches(source)) {
    if (match.start > offset) {
      blocks.addAll(_looseTafsirBlocks(source.substring(offset, match.start)));
    }
    final tag = match.group(1)!.toLowerCase();
    final attrs = match.group(2) ?? '';
    final inner = match.group(3)!;
    final headingLevel = _headingLevel(tag, inner);
    final spans = _inlineSpans(inner);
    final text = spans.map((s) => s.text).join().trim();
    if (text.isEmpty) continue;
    blocks.add(
      TafsirTextBlock(
        text: text,
        spans: spans,
        headingLevel: headingLevel,
        isArabic: _isArabicBlock(attrs, text),
        isLead: _hasClass(attrs, 'translation'),
      ),
    );
    offset = match.end;
  }
  if (offset < source.length) {
    blocks.addAll(_looseTafsirBlocks(source.substring(offset)));
  }

  if (blocks.isNotEmpty) return blocks;
  return [
    for (final paragraph in htmlToPlainText(source).split('\n\n'))
      if (paragraph.trim().isNotEmpty)
        TafsirTextBlock(
          text: paragraph.trim(),
          spans: [TafsirTextSpan(text: paragraph.trim())],
          isArabic: _looksArabic(paragraph),
        ),
  ];
}

List<TafsirTextSpan> _inlineSpans(String html) {
  final spans = <TafsirTextSpan>[];
  final grayPattern = RegExp(
    r'<span\b([^>]*)>(.*?)</span>',
    caseSensitive: false,
    dotAll: true,
  );
  var offset = 0;
  for (final match in grayPattern.allMatches(html)) {
    if (match.start > offset) {
      final text = htmlToPlainText(html.substring(offset, match.start));
      if (text.isNotEmpty) spans.add(TafsirTextSpan(text: text));
    }
    final attrs = match.group(1) ?? '';
    final text = htmlToPlainText(match.group(2)!);
    if (text.isNotEmpty) {
      spans.add(
        TafsirTextSpan(
          text: text,
          isMuted: _hasClass(attrs, 'gray'),
          isArabic: _isArabicInline(attrs),
        ),
      );
    }
    offset = match.end;
  }
  if (offset < html.length) {
    final text = htmlToPlainText(html.substring(offset));
    if (text.isNotEmpty) spans.add(TafsirTextSpan(text: text));
  }
  return _withSpacesBetweenInlinePieces(spans);
}

List<TafsirTextSpan> _withSpacesBetweenInlinePieces(
  List<TafsirTextSpan> spans,
) {
  if (spans.length < 2) return spans;
  final out = <TafsirTextSpan>[];
  for (final span in spans) {
    if (out.isNotEmpty &&
        out.last.text.isNotEmpty &&
        span.text.isNotEmpty &&
        !_endsWithSpaceOrOpeningPunctuation(out.last.text) &&
        !_startsWithSpaceOrClosingPunctuation(span.text)) {
      out.add(const TafsirTextSpan(text: ' '));
    }
    out.add(span);
  }
  return out;
}

bool _endsWithSpaceOrOpeningPunctuation(String text) =>
    RegExp(r'[\s([«]$').hasMatch(text);

bool _startsWithSpaceOrClosingPunctuation(String text) =>
    RegExp(r'^[\s,.;:!?)\]»،؟۔]').hasMatch(text);

List<TafsirTextBlock> _looseTafsirBlocks(String html) {
  final hasHeadingMarker = _hasDecorativeHeadingMarker(html);
  final text = htmlToPlainText(html);
  if (text.isEmpty) return const [];
  return [
    for (final paragraph in text.split('\n\n'))
      if (paragraph.trim().isNotEmpty)
        _looseTafsirBlock(paragraph.trim(), hasHeadingMarker),
  ];
}

TafsirTextBlock _looseTafsirBlock(String text, bool hasHeadingMarker) {
  final heading = _cleanTafsirMarkers(text).trim();
  final isHeading = hasHeadingMarker && heading.isNotEmpty;
  return TafsirTextBlock(
    text: isHeading ? heading : text,
    spans: [TafsirTextSpan(text: isHeading ? heading : text)],
    headingLevel: isHeading ? 2 : null,
    isArabic: !isHeading && _looksArabic(text),
  );
}

String _cleanTafsirMarkers(String text) {
  return text
      .replaceAll(
        RegExp(r'[٭۝۞۩◌ۣ۟۠ۡۢۤۥۦۭۧۨ۫۬\u06DD-\u06E0\u06E5-\u06ED]+'),
        '',
      )
      .trim();
}

bool _hasDecorativeHeadingMarker(String text) {
  return RegExp(
    r'[٭۝۞۩◌ۣ۟۠ۡۢۤۥۦۭۧۨ۫۬\u06DD-\u06E0\u06E5-\u06ED]{2,}',
  ).hasMatch(text);
}

bool _isArabicBlock(String attrs, String text) {
  final normalized = attrs.toLowerCase();
  if (normalized.contains('lang="ur"') ||
      normalized.contains("lang='ur'") ||
      _hasClass(attrs, 'ur')) {
    return false;
  }
  return normalized.contains('lang="ar"') ||
      normalized.contains("lang='ar'") ||
      normalized.contains('lang="fa"') ||
      normalized.contains("lang='fa'") ||
      _hasClass(attrs, 'qpc-hafs') ||
      _looksArabic(text);
}

bool _isArabicInline(String attrs) {
  final normalized = attrs.toLowerCase();
  return normalized.contains('lang="ar"') ||
      normalized.contains("lang='ar'") ||
      _hasClass(attrs, 'arabic') ||
      _hasClass(attrs, 'qpc-hafs');
}

int? _headingLevel(String tag, String inner) {
  final tagLevel = RegExp(r'^h([1-6])$').firstMatch(tag);
  if (tagLevel != null) return int.parse(tagLevel.group(1)!);
  final nested = RegExp(
    r'<h([1-6])\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(inner);
  if (nested == null) return null;
  return int.parse(nested.group(1)!);
}

bool _hasClass(String attrs, String className) {
  final classAttr = RegExp(
    r'''class\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  ).firstMatch(attrs);
  if (classAttr == null) return false;
  return classAttr
      .group(1)!
      .split(RegExp(r'\s+'))
      .any((name) => name.toLowerCase() == className.toLowerCase());
}

bool _looksArabic(String text) {
  if (_hasUrduSpecificLetters(text)) return false;
  final letters =
      RegExp(r'[\p{Letter}]', unicode: true).allMatches(text).length;
  if (letters == 0) return false;
  final arabic = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
  ).allMatches(text).length;
  return arabic / letters >= 0.45;
}

bool _hasUrduSpecificLetters(String text) {
  return RegExp(r'[ٹڈڑںےہھگپچژکگیۀۃ]').hasMatch(text);
}
