import '../models/question.dart';

/// Local round state: one accepted answer per question, then a final score.
class TriviaRound {
  TriviaRound(List<Question> questions)
    : questions = List<Question>.unmodifiable(questions) {
    if (questions.isEmpty) {
      throw ArgumentError('A round needs at least one loaded question.');
    }
  }

  final List<Question> questions;
  int currentIndex = 0;
  int score = 0;
  String? selectedAnswer;

  int get total => questions.length;

  bool get isComplete => currentIndex >= questions.length;

  bool get hasAnswered => selectedAnswer != null;

  Question get current {
    if (isComplete) {
      throw StateError('The round is complete.');
    }
    return questions[currentIndex];
  }

  /// Accepts the first choice for the current question.
  ///
  /// Later calls do nothing, so a question can add at most one point.
  bool answerQuestion(String choice) {
    if (isComplete || selectedAnswer != null) {
      return false;
    }
    if (!current.options.contains(choice)) {
      return false;
    }
    selectedAnswer = choice;
    if (choice == current.correctAnswer) {
      score += 1;
    }
    return true;
  }

  /// Moves to the next question after an answer, or finishes the round.
  bool nextQuestion() {
    if (isComplete || selectedAnswer == null) {
      return false;
    }
    currentIndex += 1;
    selectedAnswer = null;
    return true;
  }
}
