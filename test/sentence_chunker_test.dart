import 'package:flutter_test/flutter_test.dart';
import 'package:gemma_vision_demo/gemma/sentence_chunker.dart';

/// The chunker decides when audio can start. A false split makes the
/// synthesizer put a full stop where a speaker would not; a missed split
/// means the user waits in silence. Both are tested here.
void main() {
  /// Feed text one character at a time, the way tokens actually arrive.
  List<String> streamThrough(String text, {bool flush = true}) {
    final chunker = SentenceChunker();
    final out = <String>[];
    for (final ch in text.split('')) {
      out.addAll(chunker.add(ch));
    }
    if (flush) {
      final rest = chunker.flush();
      if (rest != null) out.add(rest);
    }
    return out;
  }

  group('basic splitting', () {
    test('splits on sentence terminators', () {
      expect(
        streamThrough('The first one here. And the second one too!'),
        ['The first one here.', 'And the second one too!'],
      );
    });

    test('handles question marks and run-on punctuation', () {
      expect(
        streamThrough('Are you quite sure about that?! Yes I am certain.'),
        ['Are you quite sure about that?!', 'Yes I am certain.'],
      );
    });

    test('emits the first sentence before the rest has arrived', () {
      // This is the whole point: audio can start on sentence one.
      final chunker = SentenceChunker();
      final first = chunker.add('This is the first sentence. And then more');
      expect(first, ['This is the first sentence.']);
    });

    test('flush returns an unterminated tail', () {
      expect(
        streamThrough('A complete sentence here. Then a trailing fragment'),
        ['A complete sentence here.', 'Then a trailing fragment'],
      );
    });

    test('empty input produces nothing', () {
      expect(streamThrough(''), isEmpty);
    });
  });

  group('false splits that would sound wrong', () {
    test('does not split a decimal number', () {
      expect(
        streamThrough('The total came to 3.14 rupees exactly.'),
        ['The total came to 3.14 rupees exactly.'],
      );
    });

    test('does not split on an abbreviation', () {
      expect(
        streamThrough('Please go and ask Dr. Bhatt about the results.'),
        ['Please go and ask Dr. Bhatt about the results.'],
      );
    });

    test('does not split on an initial', () {
      expect(
        streamThrough('It was written by J. Smith last year.'),
        ['It was written by J. Smith last year.'],
      );
    });

    test('does not split inside an ellipsis', () {
      final out = streamThrough('Well... I suppose that could work.');
      expect(out, hasLength(1));
    });

    test('does not emit a too-short fragment on its own', () {
      // "Ok." alone would be a clipped one-word utterance.
      final out = streamThrough('Ok. That is now completely sorted out.');
      expect(out.first.startsWith('Ok. That'), isTrue);
    });
  });

  group('models that punctuate badly', () {
    test('breaks a long run at a breath mark rather than never', () {
      final long = '${'word ' * 40}, and then it finally continues onward';
      final out = streamThrough(long);
      expect(out.length, greaterThan(1));
    });

    test('a totally unpunctuated monologue still produces audio', () {
      final out = streamThrough('word ' * 120);
      expect(out.length, greaterThan(1));
      // Nothing may exceed the hard ceiling by much, or playback stalls.
      expect(out.every((s) => s.length <= 260), isTrue);
    });
  });

  group('markdown must not be read aloud', () {
    test('strips bold, headings, bullets and code marks', () {
      expect(
        streamThrough('## The Heading\n**Bold words** and `code` here.'),
        ['The Heading', 'Bold words and code here.'],
      );
    });

    test('strips list markers', () {
      final out = streamThrough('- First item here.\n- Second item here.\n');
      expect(out, ['First item here.', 'Second item here.']);
    });

    test('collapses runs of spaces so pauses are natural', () {
      expect(
        streamThrough('Too    many   spaces    in this sentence.'),
        ['Too many spaces in this sentence.'],
      );
    });

    test('a newline is a structural break, so it splits', () {
      // Models use newlines for headings and list items. Speaking across one
      // runs two separate ideas together, so a line break ends a chunk even
      // when the line is short.
      expect(
        streamThrough('Day one\nVisit the fort.'),
        ['Day one', 'Visit the fort.'],
      );
    });
  });
}
