import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_showdown/services/html_entities.dart';

void main() {
  test('decodes the entities Open Trivia Database uses most', () {
    expect(decodeHtmlEntities('&quot;'), '"');
    expect(decodeHtmlEntities('&#039;'), "'");
    expect(decodeHtmlEntities('&amp;'), '&');
    expect(
      decodeHtmlEntities(
        'Fish &amp; Chips are &quot;best&quot; on &#039;Friday&#039;',
      ),
      'Fish & Chips are "best" on \'Friday\'',
    );
  });

  test('decodes named, decimal, and hexadecimal references', () {
    expect(decodeHtmlEntities('caf&eacute;'), 'café');
    expect(decodeHtmlEntities('&#233;'), 'é');
    expect(decodeHtmlEntities('&#xE9;'), 'é');
    expect(decodeHtmlEntities('&#X27;'), "'");
    expect(decodeHtmlEntities('&lt;tag&gt;'), '<tag>');
    expect(decodeHtmlEntities('Hello&nbsp;World'), 'Hello\u00A0World');
    expect(decodeHtmlEntities('&ldquo;Hi&rdquo;'), '“Hi”');
    expect(decodeHtmlEntities('it&rsquo;s'), 'it’s');
  });

  test('leaves ordinary text and unknown entities alone', () {
    expect(decodeHtmlEntities('Mars'), 'Mars');
    expect(decodeHtmlEntities('100% sure'), '100% sure');
    expect(decodeHtmlEntities('a & b'), 'a & b');
    expect(decodeHtmlEntities('&notareal;'), '&notareal;');
  });

  test('does not double-decode a single pass', () {
    expect(decodeHtmlEntities('&amp;quot;'), '&quot;');
  });

  test('decodes a live-style question prompt', () {
    expect(
      decodeHtmlEntities(
        'In &quot;Shrek&quot;, what comedic actor voices Donkey?',
      ),
      'In "Shrek", what comedic actor voices Donkey?',
    );
  });
}
