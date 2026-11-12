import 'dart:math';

import '../services/html_entities.dart';

/// One multiple-choice trivia question ready to display.
class Question {
  Question({
    required this.questionText,
    required this.correctAnswer,
    required List<String> options,
  }) : options = List<String>.unmodifiable(options) {
    if (this.options.isEmpty || !this.options.contains(correctAnswer)) {
      throw ArgumentError('options must include the correct answer.');
    }
  }

  final String questionText;
  final String correctAnswer;
  final List<String> options;

  /// Maps one Open Trivia Database result into display text.
  ///
  /// Combines the correct answer with the incorrect ones, shuffles that list,
  /// and decodes HTML entities in the prompt and every option.
  factory Question.fromJson(Map<String, dynamic> json, {Random? random}) {
    final questionRaw = json['question'];
    final correctRaw = json['correct_answer'];
    final incorrectRaw = json['incorrect_answers'];
    if (questionRaw is! String ||
        correctRaw is! String ||
        incorrectRaw is! List) {
      throw const FormatException('Trivia API did not return questions.');
    }

    final incorrect = <String>[];
    for (final choice in incorrectRaw) {
      if (choice is! String) {
        throw const FormatException('Trivia API did not return questions.');
      }
      incorrect.add(decodeHtmlEntities(choice));
    }

    final correctAnswer = decodeHtmlEntities(correctRaw);
    final options = <String>[...incorrect, correctAnswer];
    options.shuffle(random ?? Random());
    return Question(
      questionText: decodeHtmlEntities(questionRaw),
      correctAnswer: correctAnswer,
      options: options,
    );
  }
}
