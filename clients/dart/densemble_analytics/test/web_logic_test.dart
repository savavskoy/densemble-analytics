import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:densemble_analytics/src/web_logic.dart';
import 'package:test/test.dart';

void main() {
  test('utm marks are parsed, others ignored', () {
    expect(parseUtm('?utm_source=threads&utm_medium=social&utm_campaign=launch&utm_term=x&foo=1'),
        {'source': 'threads', 'medium': 'social', 'campaign': 'launch'});
    expect(parseUtm(''), isEmpty);
    expect(parseUtm('?%zz'), isEmpty);
    expect(parseUtm('?utm_source=${'y' * 500}')['source'], hasLength(120));
  });

  test('path loses query and fragment and gets a leading slash', () {
    expect(EventContext.cleanPath('/blog/a?x=1#y'), '/blog/a');
    expect(EventContext.cleanPath('no/slash?q'), '/no/slash');
    expect(EventContext.cleanPath('?only'), isNull);
  });

  test('referrer and utm go with the first event of the page load only', () {
    var path = '/a?x=1';
    final c = PageLoadContext(pathname: () => path, language: () => 'uk', referrer: 'https://example.org/', search: '?utm_source=a');
    final first = c.current();
    expect(first.referrer, 'https://example.org/');
    expect(first.utm, {'source': 'a'});
    path = '/b';
    final second = c.current();
    expect(second.referrer, isNull);
    expect(second.utm, isEmpty);
    expect(second.path, '/b');
    expect(second.language, 'uk');
  });
}
