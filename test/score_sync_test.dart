import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trivia_showdown/services/score_sync.dart';

import 'support/scripted_client.dart';

void main() {
  const submission = ScoreSubmission(score: 4, total: 5);

  test(
    'the default sync is a labeled simulation and sends no request',
    () async {
      final client = ScriptedClient((request) async {
        fail('simulation must not send ${request.method} ${request.url}');
      });
      final service = ScoreSyncService(
        client: client,
        simulationDelay: Duration.zero,
      );

      expect(service.isSimulated, isTrue);
      final result = await service.sync(submission);

      expect(client.requests, isEmpty);
      expect(result.simulated, isTrue);
      expect(result.message, contains('Simulation only'));
      expect(result.message.toLowerCase(), contains('not sent'));
      expect(result.message, contains('4 of 5'));
    },
  );

  test('a blank endpoint still uses the simulation', () {
    expect(ScoreSyncService(endpoint: '').isSimulated, isTrue);
    expect(ScoreSyncService(endpoint: '   ').isSimulated, isTrue);
  });

  test('a configured endpoint posts the score and waits for success', () async {
    final client = ScriptedClient(
      (request) async => http.Response('{"ok": true}', 201),
    );
    final service = ScoreSyncService(
      client: client,
      endpoint: 'https://instructor.example/leaderboard',
    );

    final result = await service.sync(submission);

    expect(service.isSimulated, isFalse);
    expect(result.simulated, isFalse);
    expect(result.message, contains('saved'));
    expect(result.message.toLowerCase(), isNot(contains('simulation')));
    final request = client.requests.single;
    expect(request.method, 'POST');
    expect(request.url.toString(), 'https://instructor.example/leaderboard');
    expect(request.headers['content-type'], 'application/json; charset=utf-8');
    expect(json.decode(request.body), {'score': 4, 'total': 5});
  });

  test('a failed leaderboard response is not reported as saved', () async {
    final client = ScriptedClient(
      (request) async => http.Response('nope', 500),
    );
    final service = ScoreSyncService(
      client: client,
      endpoint: 'https://instructor.example/leaderboard',
    );

    expect(
      () => service.sync(submission),
      throwsA(
        isA<ScoreSyncException>().having(
          (error) => error.message,
          'message',
          'The leaderboard returned HTTP 500. The score was not saved.',
        ),
      ),
    );
    expect(client.requests, hasLength(1));
  });

  test('a leaderboard timeout or connection failure stays a failure', () async {
    final hanging = ScoreSyncService(
      client: HangingClient(),
      endpoint: 'https://instructor.example/leaderboard',
      requestTimeout: const Duration(milliseconds: 10),
    );
    expect(
      () => hanging.sync(submission),
      throwsA(
        isA<ScoreSyncException>().having(
          (error) => error.message,
          'message',
          contains('timed out'),
        ),
      ),
    );

    final offline = ScoreSyncService(
      client: ScriptedClient((request) async {
        throw http.ClientException('offline', request.url);
      }),
      endpoint: 'https://instructor.example/leaderboard',
    );
    expect(
      () => offline.sync(submission),
      throwsA(
        isA<ScoreSyncException>().having(
          (error) => error.message,
          'message',
          'Could not reach the leaderboard. The score was not saved.',
        ),
      ),
    );
  });
}
