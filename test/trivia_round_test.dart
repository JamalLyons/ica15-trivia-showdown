import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_showdown/models/question.dart';
import 'package:trivia_showdown/state/trivia_round.dart';

void main() {
  Question question(String text, String correct, List<String> wrong) {
    return Question(
      questionText: text,
      correctAnswer: correct,
      options: [correct, ...wrong],
    );
  }

  TriviaRound sampleRound() {
    return TriviaRound([
      question('Red planet?', 'Mars', ['Venus', 'Jupiter']),
      question('Water?', 'H2O', ['CO2', 'NaCl']),
      question('Cats?', 'Feline', ['Canine', 'Bovine']),
    ]);
  }

  test('a correct answer scores once and ignores later taps', () {
    final round = sampleRound();

    expect(round.answerQuestion('Mars'), isTrue);
    expect(round.score, 1);
    expect(round.selectedAnswer, 'Mars');

    expect(round.answerQuestion('Mars'), isFalse);
    expect(round.answerQuestion('Venus'), isFalse);
    expect(round.score, 1);
    expect(round.currentIndex, 0);
  });

  test('an incorrect answer scores nothing and still locks the question', () {
    final round = sampleRound();

    expect(round.answerQuestion('Venus'), isTrue);
    expect(round.score, 0);
    expect(round.selectedAnswer, 'Venus');
    expect(round.answerQuestion('Mars'), isFalse);
    expect(round.score, 0);
  });

  test('a choice that is not on the question is ignored', () {
    final round = sampleRound();

    expect(round.answerQuestion('Pluto'), isFalse);
    expect(round.hasAnswered, isFalse);
    expect(round.score, 0);
  });

  test('continue is blocked until an answer, then advances and clears it', () {
    final round = sampleRound();

    expect(round.nextQuestion(), isFalse);
    expect(round.currentIndex, 0);

    round.answerQuestion('Mars');
    expect(round.nextQuestion(), isTrue);
    expect(round.currentIndex, 1);
    expect(round.hasAnswered, isFalse);
    expect(round.score, 1);
    expect(round.current.questionText, 'Water?');
  });

  test('the final score is out of the loaded questions', () {
    final round = sampleRound();

    round.answerQuestion('Mars');
    round.nextQuestion();
    round.answerQuestion('CO2');
    round.nextQuestion();
    round.answerQuestion('Feline');
    expect(round.nextQuestion(), isTrue);

    expect(round.isComplete, isTrue);
    expect(round.score, 2);
    expect(round.total, 3);
    expect(round.answerQuestion('Feline'), isFalse);
    expect(round.nextQuestion(), isFalse);
    expect(round.score, 2);
  });

  test('an empty question list is not a playable round', () {
    expect(() => TriviaRound(const []), throwsArgumentError);
  });
}
