import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'screens/trivia_screen.dart';
import 'services/score_sync.dart';
import 'services/trivia_api.dart';
import 'showdown_colors.dart';

/// Empty unless the app is built with `--dart-define=SCORE_ENDPOINT=...`.
const String kScoreEndpoint = String.fromEnvironment('SCORE_ENDPOINT');

void main() {
  final client = http.Client();
  runApp(
    TriviaShowdownApp(
      api: OpenTriviaApi(client: client),
      scoreSync: ScoreSyncService(client: client, endpoint: kScoreEndpoint),
    ),
  );
}

class TriviaShowdownApp extends StatelessWidget {
  const TriviaShowdownApp({
    super.key,
    required this.api,
    required this.scoreSync,
  });

  final TriviaApi api;
  final ScoreSyncService scoreSync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Showdown',
      debugShowCheckedModeBanner: false,
      theme: buildTriviaTheme(),
      home: TriviaScreen(api: api, scoreSync: scoreSync),
    );
  }
}

ThemeData buildTriviaTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: ShowdownColors.plum,
      primary: ShowdownColors.plum,
      onPrimary: Colors.white,
      surface: ShowdownColors.paper,
    ),
    scaffoldBackgroundColor: ShowdownColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: ShowdownColors.plum,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ShowdownColors.plum,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD9D0E6),
        disabledForegroundColor: ShowdownColors.muted,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ShowdownColors.plum,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: ShowdownColors.plum, width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ShowdownColors.ink,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 15),
    ),
  );
}
