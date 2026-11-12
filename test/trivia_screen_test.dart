import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:trivia_showdown/main.dart';
import 'package:trivia_showdown/models/question.dart';
import 'package:trivia_showdown/screens/trivia_screen.dart';
import 'package:trivia_showdown/services/score_sync.dart';
import 'package:trivia_showdown/services/trivia_api.dart';
import 'package:trivia_showdown/widgets/answer_option.dart';

import 'support/scripted_client.dart';

void main() {
  Question question({
    required String text,
    required String correct,
    required List<String> wrong,
  }) {
    return Question(
      questionText: text,
      correctAnswer: correct,
      options: [correct, ...wrong],
    );
  }

  final mars = question(
    text: 'Which planet is known as the Red Planet?',
    correct: 'Mars',
    wrong: ['Venus', 'Jupiter', 'Mercury'],
  );
  final water = question(
    text: 'What is the chemical formula for water?',
    correct: 'H2O',
    wrong: ['CO2', 'NaCl', 'O2'],
  );

  List<Question> fiveQuestions() {
    return [
      mars,
      water,
      question(
        text: 'How many continents are there?',
        correct: '7',
        wrong: ['5', '6', '8'],
      ),
      question(
        text: 'Which ocean is the largest?',
        correct: 'Pacific',
        wrong: ['Atlantic', 'Indian', 'Arctic'],
      ),
      question(
        text: 'What color is a school bus in the US?',
        correct: 'Yellow',
        wrong: ['Red', 'Blue', 'Green'],
      ),
    ];
  }

  Future<void> pumpTrivia(
    WidgetTester tester, {
    required TriviaApi api,
    ScoreSyncService? scoreSync,
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TriviaShowdownApp(
        api: api,
        scoreSync:
            scoreSync ??
            ScoreSyncService(
              client: ScriptedClient((request) async {
                fail('unexpected HTTP ${request.method} ${request.url}');
              }),
              simulationDelay: Duration.zero,
            ),
      ),
    );
  }

  AnswerTone toneOf(WidgetTester tester, String label) {
    return tester
        .widget<AnswerOption>(find.widgetWithText(AnswerOption, label))
        .tone;
  }

  Future<void> choose(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(AnswerOption, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> pressContinue(WidgetTester tester) async {
    final finder = find.byKey(TriviaKeys.continueButton);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('shows a progress indicator while the request is in flight', (
    tester,
  ) async {
    final pending = Completer<List<Question>>();
    await pumpTrivia(tester, api: _FakeTriviaApi(() => pending.future));
    await tester.pump();

    expect(find.byKey(TriviaKeys.loading), findsOneWidget);
    expect(
      find.textContaining('Requesting five easy questions'),
      findsOneWidget,
    );
    expect(find.byKey(TriviaKeys.question), findsNothing);
    expect(find.byKey(TriviaKeys.errorMessage), findsNothing);

    pending.complete([mars]);
    await tester.pumpAndSettle();
    expect(find.byKey(TriviaKeys.question), findsOneWidget);
  });

  testWidgets('shows a readable error and retries into a question', (
    tester,
  ) async {
    final attempts = <Completer<List<Question>>>[];
    final api = _FakeTriviaApi(() {
      final attempt = Completer<List<Question>>();
      attempts.add(attempt);
      return attempt.future;
    });
    await pumpTrivia(tester, api: api);
    await tester.pump();
    expect(find.byKey(TriviaKeys.loading), findsOneWidget);

    attempts.single.completeError(
      const FormatException('Trivia API did not return questions.'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(TriviaKeys.loading), findsNothing);
    expect(find.byKey(TriviaKeys.question), findsNothing);
    expect(find.text('Trivia API did not return questions.'), findsOneWidget);
    expect(
      find.text('Nothing from this response was turned into a round.'),
      findsOneWidget,
    );
    expect(api.calls, 1);

    await tester.tap(find.byKey(TriviaKeys.retry));
    await tester.pump();
    expect(find.byKey(TriviaKeys.loading), findsOneWidget);
    expect(find.byKey(TriviaKeys.errorMessage), findsNothing);
    expect(api.calls, 2);

    attempts[1].complete([mars]);
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(
      find.text('Which planet is known as the Red Planet?'),
      findsOneWidget,
    );
  });

  testWidgets('marks a correct answer green and will not score it twice', (
    tester,
  ) async {
    await pumpTrivia(tester, api: _FakeTriviaApi(() async => [mars, water]));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.text('Score 0'), findsOneWidget);
    expect(toneOf(tester, 'Mars'), AnswerTone.neutral);
    final before = tester.widget<FilledButton>(
      find.byKey(TriviaKeys.continueButton),
    );
    expect(before.onPressed, isNull);

    await choose(tester, 'Mars');
    expect(find.text('Score 1'), findsOneWidget);
    expect(toneOf(tester, 'Mars'), AnswerTone.correct);
    expect(toneOf(tester, 'Venus'), AnswerTone.neutral);
    expect(
      tester
          .widget<AnswerOption>(find.widgetWithText(AnswerOption, 'Mars'))
          .onPressed,
      isNull,
    );

    await pressContinue(tester);
    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(find.text('Score 1'), findsOneWidget);
    expect(toneOf(tester, 'H2O'), AnswerTone.neutral);
    expect(
      find.text('What is the chemical formula for water?'),
      findsOneWidget,
    );
  });

  testWidgets('marks a wrong pick red and the correct option green', (
    tester,
  ) async {
    await pumpTrivia(tester, api: _FakeTriviaApi(() async => [mars]));
    await tester.pumpAndSettle();

    await choose(tester, 'Venus');

    expect(find.text('Score 0'), findsOneWidget);
    expect(toneOf(tester, 'Venus'), AnswerTone.incorrect);
    expect(toneOf(tester, 'Mars'), AnswerTone.correct);
    expect(toneOf(tester, 'Jupiter'), AnswerTone.neutral);
    expect(toneOf(tester, 'Mercury'), AnswerTone.neutral);
    expect(
      tester
          .widget<FilledButton>(find.byKey(TriviaKeys.continueButton))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('displays decoded question text from the API client', (
    tester,
  ) async {
    const body = '''
{
  "response_code": 0,
  "results": [
    {
      "question": "Fish &amp; Chips are &quot;best&quot; on &#039;Friday&#039;",
      "correct_answer": "True",
      "incorrect_answers": ["False", "Maybe", "Never"]
    }
  ]
}
''';
    final api = OpenTriviaApi(
      client: ScriptedClient((request) async => http.Response(body, 200)),
    );
    await pumpTrivia(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.text('Fish & Chips are "best" on \'Friday\''), findsOneWidget);
    expect(find.textContaining('&quot;'), findsNothing);
    expect(find.textContaining('&#039;'), findsNothing);
    expect(find.textContaining('&amp;'), findsNothing);
  });

  testWidgets('finishes the round, simulates sync, and replays', (
    tester,
  ) async {
    var round = 0;
    final api = _FakeTriviaApi(() async {
      round += 1;
      if (round == 1) {
        return fiveQuestions();
      }
      return [
        question(
          text: 'A fresh question from the replay fetch',
          correct: 'Yes',
          wrong: ['No', 'Maybe', 'Later'],
        ),
      ];
    });
    await pumpTrivia(tester, api: api);
    await tester.pumpAndSettle();

    await choose(tester, 'Mars');
    await pressContinue(tester);
    await choose(tester, 'CO2');
    await pressContinue(tester);
    await choose(tester, '7');
    await pressContinue(tester);
    await choose(tester, 'Atlantic');
    await pressContinue(tester);
    await choose(tester, 'Yellow');
    await pressContinue(tester);

    expect(find.text('3 out of 5'), findsOneWidget);
    expect(find.text('Solid round.'), findsOneWidget);
    expect(find.text('Sync Score to Leaderboard'), findsOneWidget);
    expect(find.textContaining('Classroom simulation'), findsOneWidget);
    expect(find.textContaining('No request is sent'), findsOneWidget);
    expect(find.textContaining('{"score":3,"total":5}'), findsOneWidget);

    await tester.ensureVisible(find.byKey(TriviaKeys.syncButton));
    await tester.tap(find.byKey(TriviaKeys.syncButton));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Simulation only: score 3 of 5 was not sent to a server.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(TriviaKeys.syncButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('Simulation complete'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.ensureVisible(find.byKey(TriviaKeys.replayButton));
    await tester.tap(find.byKey(TriviaKeys.replayButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('A fresh question from the replay fetch'), findsOneWidget);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.text('Score 0'), findsOneWidget);
  });

  testWidgets('posts the score when an instructor endpoint is configured', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final client = ScriptedClient((request) => response.future);
    await pumpTrivia(
      tester,
      api: _FakeTriviaApi(() async => [mars]),
      scoreSync: ScoreSyncService(
        client: client,
        endpoint: 'https://instructor.example/leaderboard',
        simulationDelay: const Duration(seconds: 30),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Venus');
    await pressContinue(tester);

    expect(find.text('0 out of 1'), findsOneWidget);
    expect(find.textContaining('Instructor leaderboard'), findsOneWidget);
    expect(find.textContaining('Classroom simulation'), findsNothing);

    await tester.tap(find.byKey(TriviaKeys.syncButton));
    await tester.pump();
    expect(find.byKey(TriviaKeys.syncProgress), findsOneWidget);

    response.complete(http.Response('{"ok": true}', 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(client.requests, hasLength(1));
    expect(client.requests.single.method, 'POST');
    expect(json.decode(client.requests.single.body), {'score': 0, 'total': 1});
    expect(
      find.text('Score 0 of 1 was saved to the leaderboard.'),
      findsOneWidget,
    );
    expect(find.textContaining('Simulation'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a rejected leaderboard write does not show success', (
    tester,
  ) async {
    final client = ScriptedClient(
      (request) async => http.Response('nope', 502),
    );
    await pumpTrivia(
      tester,
      api: _FakeTriviaApi(() async => [mars]),
      scoreSync: ScoreSyncService(
        client: client,
        endpoint: 'https://instructor.example/leaderboard',
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Mars');
    await pressContinue(tester);
    await tester.tap(find.byKey(TriviaKeys.syncButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('The leaderboard returned HTTP 502. The score was not saved.'),
      findsOneWidget,
    );
    expect(find.textContaining('was saved'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(TriviaKeys.syncButton)).onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the question layout fits a wide window', (tester) async {
    await pumpTrivia(
      tester,
      api: _FakeTriviaApi(() async => fiveQuestions()),
      size: const Size(1280, 800),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeTriviaApi implements TriviaApi {
  _FakeTriviaApi(this._fetch);

  final Future<List<Question>> Function() _fetch;
  int calls = 0;

  @override
  Future<List<Question>> fetchQuestions() {
    calls += 1;
    return _fetch();
  }
}
