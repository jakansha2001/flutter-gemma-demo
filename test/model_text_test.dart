import 'package:flutter_test/flutter_test.dart';
import 'package:gemma_vision_demo/gemma/model_text.dart';

/// Regression tests for protocol noise leaking into the visible answer.
/// Each case here was observed on-device with Gemma 4 E2B.
void main() {
  group('tool-call JSON', () {
    test('strips the mixed text+JSON turn seen on device', () {
      const raw =
          'Task "buy milk" has been marked as done.'
          '{"role":"assistant","tool_calls":[{"type":"function","function":'
          '{"name":"complete_task","arguments":{"title":"groceries"}}}]}'
          'Task "groceries" has been marked as done.';
      expect(
        ModelText.sanitize(raw),
        'Task "buy milk" has been marked as done.'
        'Task "groceries" has been marked as done.',
      );
    });

    test('handles several concatenated objects', () {
      const raw = 'A{"role":"assistant","tool_calls":[]}B'
          '{"role":"assistant","tool_calls":[]}C';
      expect(ModelText.sanitize(raw), 'ABC');
    });

    test('a brace inside a string does not close the object early', () {
      const raw = 'Done.'
          '{"role":"assistant","tool_calls":[{"function":'
          '{"arguments":{"title":"fix the } bug"}}}]}'
          ' Next.';
      expect(ModelText.sanitize(raw), 'Done. Next.');
    });

    test('an escaped quote does not break string tracking', () {
      const raw = r'X{"role":"assistant","content":"say \"hi\""}Y';
      expect(ModelText.sanitize(raw), 'XY');
    });

    test('hides a partial object still streaming in', () {
      const raw = 'Marked done.{"role":"assistant","tool_ca';
      expect(ModelText.sanitize(raw, streaming: true), 'Marked done.');
    });

    test('leaves ordinary JSON the user asked for alone', () {
      // Only the assistant-envelope shape is protocol noise. A code block the
      // user actually requested must survive.
      const raw = 'Here is the config:\n{"port": 8080, "debug": true}';
      expect(ModelText.sanitize(raw), raw);
    });
  });

  group('reasoning markers', () {
    test('strips the interleaved channel markers seen on device', () {
      const raw = '<|channel>thought\nThe user wants two actions<channel|>'
          'Both tasks are done.';
      expect(ModelText.sanitize(raw), 'Both tasks are done.');
    });

    test('strips many small interleaved blocks', () {
      const raw = '<|channel>thought\nThe<channel|>'
          '<|channel>thought\n user<channel|>Answer.';
      expect(ModelText.sanitize(raw), 'Answer.');
    });

    test('hides an unterminated block mid-stream', () {
      const raw = 'Hello.<|channel>thought\nstill thinking';
      expect(ModelText.sanitize(raw, streaming: true), 'Hello.');
    });

    test('strips DeepSeek/Qwen style think blocks too', () {
      expect(
        ModelText.sanitize('<think>hmm</think>Answer.'),
        'Answer.',
      );
    });

    test('removes stray markers with no matching pair', () {
      expect(ModelText.sanitize('Hi<channel|> there<end_of_turn>'), 'Hi there');
    });
  });

  group('forSpeech', () {
    test('drops a code-switched token the synthesizer cannot say', () {
      // Observed on device: "open-source" came out as "open-ソース".
      expect(
        ModelText.forSpeech('It is an open-ソース toolkit.'),
        'It is an open toolkit.',
      );
    });

    test('keeps accented Latin', () {
      expect(
        ModelText.forSpeech('A café in Zürich, naïve but fine.'),
        'A café in Zürich, naïve but fine.',
      );
    });

    test('leaves ordinary English untouched', () {
      const plain = 'Flutter is a UI toolkit made by Google in 2017.';
      expect(ModelText.forSpeech(plain), plain);
    });

    test('drops a wholly non-Latin sentence to nothing', () {
      expect(ModelText.forSpeech('これはテストです'), '');
    });

    test('keeps normal punctuation and digits', () {
      const s = 'Yes — it costs 1,200 (about 40%); see "docs".';
      expect(ModelText.forSpeech(s), s);
    });
  });

  group('whitespace', () {
    test('collapses the blank runs that removal leaves behind', () {
      const raw = 'One.\n\n\n\n<|channel>thought\nx<channel|>\n\n\nTwo.';
      expect(ModelText.sanitize(raw), 'One.\n\nTwo.');
    });

    test('keeps the trailing space between tokens while streaming', () {
      expect(ModelText.sanitize('Hello ', streaming: true), 'Hello ');
      expect(ModelText.sanitize('Hello ', streaming: false), 'Hello');
    });

    test('is a no-op on clean text', () {
      const clean = 'Just a normal answer with **markdown** and a list:\n- one';
      expect(ModelText.sanitize(clean), clean);
    });

    test('handles empty input', () {
      expect(ModelText.sanitize(''), '');
    });
  });
}
