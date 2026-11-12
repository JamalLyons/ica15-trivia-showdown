import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_showdown/models/question.dart';

void main() {
  const raw = {
    'question': 'Which planet is known as the &quot;Red Planet&quot;?',
    'correct_answer': 'Mars',
    'incorrect_answers': ['Venus', 'Jupiter', 'Mercury'],
  };

  test('fromJson decodes text and shuffles with the supplied random', () {
    final question = Question.fromJson(raw, random: _ZeroRandom());

    expect(question.questionText, 'Which planet is known as the "Red Planet"?');
    expect(question.correctAnswer, 'Mars');
    // nextInt always returns 0, so shuffle walks the list toward the front.
    expect(question.options, ['Jupiter', 'Mercury', 'Mars', 'Venus']);
  });

  test('fromJson keeps every answer exactly once', () {
    final question = Question.fromJson(raw, random: Random(7));

    expect(question.options, hasLength(4));
    expect(question.options.toSet(), {'Mars', 'Venus', 'Jupiter', 'Mercury'});
    expect(question.options, contains(question.correctAnswer));
  });

  test('fromJson decodes entities in every option', () {
    final question = Question.fromJson({
      'question': 'Pick one',
      'correct_answer': 'Fish &amp; Chips',
      'incorrect_answers': ['&quot;No&quot;', '&#039;Yes&#039;'],
    }, random: _ZeroRandom());

    expect(question.correctAnswer, 'Fish & Chips');
    expect(question.options, containsAll(['Fish & Chips', '"No"', "'Yes'"]));
  });

  test('fromJson rejects a result that is missing fields', () {
    expect(
      () => Question.fromJson({'question': 'Only a prompt'}),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Trivia API did not return questions.',
        ),
      ),
    );
  });
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
