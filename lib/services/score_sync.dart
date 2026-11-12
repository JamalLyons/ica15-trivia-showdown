import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Final score carried toward a leaderboard.
class ScoreSubmission {
  const ScoreSubmission({required this.score, required this.total});

  final int score;
  final int total;

  Map<String, Object> toJson() => {'score': score, 'total': total};

  String toJsonString() => json.encode(toJson());
}

/// Outcome of a score action. [simulated] is true only when no request was sent.
class ScoreSyncResult {
  const ScoreSyncResult({required this.simulated, required this.message});

  final bool simulated;
  final String message;
}

class ScoreSyncException implements Exception {
  const ScoreSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Posts a score when an instructor endpoint is configured.
///
/// With no endpoint, this waits briefly and returns a labeled simulation.
/// That path does not call the HTTP client and does not persist anything.
class ScoreSyncService {
  ScoreSyncService({
    http.Client? client,
    String? endpoint,
    this.simulationDelay = const Duration(milliseconds: 1200),
    this.requestTimeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       endpoint = _blankToNull(endpoint);

  final http.Client _client;
  final String? endpoint;
  final Duration simulationDelay;
  final Duration requestTimeout;

  /// True when the classroom simulation will run instead of HTTP POST.
  bool get isSimulated => endpoint == null;

  Future<ScoreSyncResult> sync(ScoreSubmission submission) async {
    if (isSimulated) {
      await Future<void>.delayed(simulationDelay);
      return ScoreSyncResult(
        simulated: true,
        message:
            'Simulation only: score ${submission.score} of ${submission.total} was not sent to a server.',
      );
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint!),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: submission.toJsonString(),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const ScoreSyncException(
        'The leaderboard request timed out. The score was not saved.',
      );
    } on http.ClientException {
      throw const ScoreSyncException(
        'Could not reach the leaderboard. The score was not saved.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ScoreSyncException(
        'The leaderboard returned HTTP ${response.statusCode}. The score was not saved.',
      );
    }

    return ScoreSyncResult(
      simulated: false,
      message:
          'Score ${submission.score} of ${submission.total} was saved to the leaderboard.',
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

String describeSyncError(Object error) {
  if (error is ScoreSyncException && error.message.isNotEmpty) {
    return error.message;
  }
  return 'The score was not saved.';
}
