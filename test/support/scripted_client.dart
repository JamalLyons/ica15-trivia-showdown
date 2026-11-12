import 'dart:async';

import 'package:http/http.dart' as http;

/// HTTP client whose [send] is supplied by the test.
class ScriptedClient extends http.BaseClient {
  ScriptedClient(this.handler);

  final Future<http.Response> Function(http.Request request) handler;
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final outgoing = request as http.Request;
    requests.add(outgoing);
    final response = await handler(outgoing);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

/// Never completes, so a caller can observe its own timeout.
class HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}
