import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trivia_showdown/services/trivia_api.dart';

import 'support/scripted_client.dart';

void main() {
  const encodedQuestion = '''
{
  "response_code": 0,
  "results": [
    {
      "category": "General Knowledge",
      "type": "multiple",
      "difficulty": "easy",
      "question": "Fish &amp; Chips are &quot;best&quot; on &#039;Friday&#039;",
      "correct_answer": "Mars",
      "incorrect_answers": ["Venus", "Jupiter", "Mercury"]
    }
  ]
}
''';

  String fiveQuestions() {
    final items = List.generate(5, (index) {
      return '''
      {
        "question": "Question ${index + 1}?",
        "correct_answer": "Right ${index + 1}",
        "incorrect_answers": ["A", "B", "C"]
      }
      ''';
    }).join(',');
    return '{"response_code": 0, "results": [$items]}';
  }

  OpenTriviaApi apiReturning(
    http.Response response, {
    Duration? timeout,
    Random? random,
  }) {
    return OpenTriviaApi(
      client: ScriptedClient((request) async => response),
      timeout: timeout ?? const Duration(seconds: 10),
      random: random ?? _ZeroRandom(),
    );
  }

  test('requests the required URL and parses five questions', () async {
    final client = ScriptedClient(
      (request) async => http.Response(fiveQuestions(), 200),
    );
    final api = OpenTriviaApi(client: client, random: _ZeroRandom());

    final questions = await api.fetchQuestions();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.method, 'GET');
    expect(client.requests.single.url, OpenTriviaApi.endpoint);
    expect(
      client.requests.single.url.toString(),
      'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple',
    );
    expect(questions, hasLength(5));
    expect(questions.first.questionText, 'Question 1?');
    expect(questions.last.correctAnswer, 'Right 5');
    expect(questions.first.options, containsAll(['Right 1', 'A', 'B', 'C']));
  });

  test('decodes entities before the question is returned', () async {
    final questions = await apiReturning(http.Response(encodedQuestion, 200))
        .fetchQuestions();

    expect(
      questions.single.questionText,
      'Fish & Chips are "best" on \'Friday\'',
    );
    expect(questions.single.questionText, isNot(contains('&quot;')));
    expect(questions.single.questionText, isNot(contains('&amp;')));
    expect(questions.single.questionText, isNot(contains('&#039;')));
  });

  test(
    'rejects a non-200 response without treating the body as a round',
    () async {
      expect(
        () => apiReturning(
          http.Response('{"response_code": 0, "results": []}', 503),
        ).fetchQuestions(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'The trivia service returned HTTP 503. Expected status 200.',
          ),
        ),
      );
    },
  );

  test('rejects a non-zero API response code', () async {
    for (final code in [1, 2, 3, 4]) {
      expect(
        () => apiReturning(
          http.Response(
            '{"response_code": $code, "results": [{"question": "Q"}]}',
            200,
          ),
        ).fetchQuestions(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Trivia API did not return questions.',
          ),
        ),
      );
    }
  });

  test('treats an empty results list as a failure', () async {
    expect(
      () => apiReturning(
        http.Response('{"response_code": 0, "results": []}', 200),
      ).fetchQuestions(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'No questions were returned.',
        ),
      ),
    );
  });

  test('rejects unreadable JSON and a missing results field', () async {
    expect(
      () => apiReturning(http.Response('not-json', 200)).fetchQuestions(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'The trivia service returned data that could not be read.',
        ),
      ),
    );
    expect(
      () =>
          apiReturning(http.Response('{"response_code": 0}', 200))
              .fetchQuestions(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Trivia API did not return questions.',
        ),
      ),
    );
  });

  test('reports a timeout and a connection failure', () async {
    final hanging = OpenTriviaApi(
      client: HangingClient(),
      timeout: const Duration(milliseconds: 10),
    );
    expect(
      hanging.fetchQuestions,
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'The request timed out. Check your connection and try again.',
        ),
      ),
    );

    final offline = OpenTriviaApi(
      client: ScriptedClient((request) async {
        throw http.ClientException('connection refused', request.url);
      }),
    );
    expect(
      offline.fetchQuestions,
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Could not reach the trivia service. Check your connection and try again.',
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
