import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/question.dart';

/// Reads five easy General Knowledge questions from Open Trivia Database.
abstract class TriviaApi {
  Future<List<Question>> fetchQuestions();
}

/// HTTP client for the activity's fixed Open Trivia Database request.
class OpenTriviaApi implements TriviaApi {
  OpenTriviaApi({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    this.random,
  }) : _client = client ?? http.Client();

  /// Five easy multiple-choice General Knowledge questions.
  static final Uri endpoint = Uri.parse(
    'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple',
  );

  final Duration timeout;
  final http.Client _client;
  final Random? random;

  @override
  Future<List<Question>> fetchQuestions() async {
    final http.Response response;
    try {
      response = await _client.get(endpoint).timeout(timeout);
    } on TimeoutException {
      throw const FormatException(
        'The request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const FormatException(
        'Could not reach the trivia service. Check your connection and try again.',
      );
    }

    // Transport success and a usable API payload are different checks.
    // A non-200 response is never parsed into a round.
    if (response.statusCode != 200) {
      throw FormatException(
        'The trivia service returned HTTP ${response.statusCode}. Expected status 200.',
      );
    }

    final Object? decoded;
    try {
      decoded = json.decode(response.body);
    } on FormatException {
      throw const FormatException(
        'The trivia service returned data that could not be read.',
      );
    }
    if (decoded is! Map) {
      throw const FormatException(
        'The trivia service returned data that could not be read.',
      );
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['response_code'] != 0) {
      throw const FormatException('Trivia API did not return questions.');
    }

    final results = data['results'];
    if (results is! List) {
      throw const FormatException('Trivia API did not return questions.');
    }
    if (results.isEmpty) {
      throw const FormatException('No questions were returned.');
    }

    final questions = <Question>[];
    for (final item in results) {
      if (item is! Map) {
        throw const FormatException('Trivia API did not return questions.');
      }
      questions.add(
        Question.fromJson(Map<String, dynamic>.from(item), random: random),
      );
    }
    return questions;
  }
}

/// Turns a load failure into copy for the error screen.
String describeLoadError(Object error) {
  if (error is FormatException && error.message.isNotEmpty) {
    return error.message;
  }
  return 'Could not reach the trivia service. Check your connection and try again.';
}
