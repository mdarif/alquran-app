import 'package:al_quran/core/format/html_to_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('htmlToPlainText', () {
    test('strips tags and turns block elements into paragraph breaks', () {
      const html = '<p class="en translation" lang="en">That is Book '
          'in which there is no Rayb, guidance for the Muttaqin '
          '<span>(2)</span></p><div lang="en" class="en "><h2>There is no '
          "Doubt in the Qur'an</h2></div><p lang=\"en\" class=\"en \">The "
          "Book, is the Qur'an.</p>";
      final result = htmlToPlainText(html);
      expect(
        result,
        'That is Book in which there is no Rayb, guidance for the '
        "Muttaqin (2)\n\nThere is no Doubt in the Qur'an\n\nThe Book, is "
        "the Qur'an.",
      );
    });

    test('decodes common HTML entities', () {
      expect(
        htmlToPlainText('<p>Tom &amp; Jerry&#39;s &quot;Qur&apos;an&quot;'
            '&nbsp;book</p>'),
        'Tom & Jerry\'s "Qur\'an" book',
      );
    });

    test('leaves plain text untouched', () {
      expect(htmlToPlainText('No markup here.'), 'No markup here.');
    });
  });

  group('htmlToTafsirBlocks', () {
    test('preserves headings and detects Arabic blocks', () {
      final blocks = htmlToTafsirBlocks(
        '<div lang="en" class="en"><h2>Guidance is granted to Those Who '
        'have Taqwa</h2></div>'
        '<p>Commentary body.</p><p>الم</p>',
      );

      expect(blocks, hasLength(3));
      expect(blocks[0].text, 'Guidance is granted to Those Who have Taqwa');
      expect(blocks[0].isHeading, isTrue);
      expect(blocks[0].headingLevel, 2);
      expect(blocks[0].isArabic, isFalse);
      expect(blocks[2].text, 'الم');
      expect(blocks[2].isArabic, isTrue);
    });

    test('keeps lead and muted source styling hints', () {
      final blocks = htmlToTafsirBlocks(
        '<p class="en translation" lang="en">That is Book <span>(2)</span></p>'
        '<p lang="en" class="en"><span class="gray">(there is no doubt)</span>'
        ' and they then continue</p>',
      );

      expect(blocks[0].isLead, isTrue);
      expect(blocks[0].text, 'That is Book (2)');
      expect(blocks[1].spans.first.text, '(there is no doubt)');
      expect(blocks[1].spans.first.isMuted, isTrue);
      expect(blocks[1].text, '(there is no doubt) and they then continue');
    });
  });
}
