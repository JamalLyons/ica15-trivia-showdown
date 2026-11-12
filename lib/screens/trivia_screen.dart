import 'package:material_ui/material_ui.dart';

import '../services/score_sync.dart';
import '../services/trivia_api.dart';
import '../showdown_colors.dart';
import '../state/trivia_round.dart';
import '../widgets/answer_option.dart';

/// Finder keys shared with the widget tests.
abstract final class TriviaKeys {
  static const loading = Key('loading-indicator');
  static const errorMessage = Key('error-message');
  static const retry = Key('retry-button');
  static const progress = Key('progress-label');
  static const score = Key('score-label');
  static const question = Key('question-text');
  static const continueButton = Key('continue-button');
  static const resultsScore = Key('results-score');
  static const syncButton = Key('sync-button');
  static const syncNote = Key('sync-note');
  static const replayButton = Key('replay-button');
  static const syncProgress = Key('sync-progress');
}

enum _LoadStatus { loading, error, ready }

class TriviaScreen extends StatefulWidget {
  const TriviaScreen({super.key, required this.api, required this.scoreSync});

  final TriviaApi api;
  final ScoreSyncService scoreSync;

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  String? _errorMessage;
  TriviaRound? _round;
  bool _syncing = false;
  bool _synced = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadTriviaData();
  }

  Future<void> _loadTriviaData() async {
    final generation = ++_loadGeneration;
    if (_status != _LoadStatus.loading ||
        _errorMessage != null ||
        _round != null) {
      setState(() {
        _status = _LoadStatus.loading;
        _errorMessage = null;
        _round = null;
        _syncing = false;
        _synced = false;
      });
    }

    try {
      final questions = await widget.api.fetchQuestions();
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _round = TriviaRound(questions);
        _status = _LoadStatus.ready;
        _errorMessage = null;
        _syncing = false;
        _synced = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _status = _LoadStatus.error;
        _errorMessage = describeLoadError(error);
        _round = null;
        _syncing = false;
        _synced = false;
      });
    }
  }

  void _answerQuestion(String choice) {
    final round = _round;
    if (round == null || _status != _LoadStatus.ready || round.isComplete) {
      return;
    }
    if (round.answerQuestion(choice)) {
      setState(() {});
    }
  }

  void _nextQuestion() {
    final round = _round;
    if (round == null || !round.nextQuestion()) {
      return;
    }
    setState(() {});
  }

  Future<void> _syncScoreToCloud() async {
    final round = _round;
    if (round == null || !round.isComplete || _syncing || _synced) {
      return;
    }
    final generation = _loadGeneration;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);
    try {
      final result = await widget.scoreSync.sync(
        ScoreSubmission(score: round.score, total: round.total),
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _syncing = false;
        _synced = true;
      });
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => _syncing = false);
      messenger.showSnackBar(SnackBar(content: Text(describeSyncError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trivia Showdown'),
            SizedBox(height: 2),
            Text(
              'Jamal Lyons · CSC 4360',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ShowdownColors.onPlum,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (_status) {
          _LoadStatus.loading => const _LoadingView(),
          _LoadStatus.error => _ErrorView(
            message: _errorMessage ?? 'Could not load questions.',
            onRetry: _loadTriviaData,
          ),
          _LoadStatus.ready => _ReadyView(
            round: _round!,
            simulated: widget.scoreSync.isSimulated,
            syncing: _syncing,
            synced: _synced,
            onAnswer: _answerQuestion,
            onContinue: _nextQuestion,
            onSync: _syncScoreToCloud,
            onReplay: _loadTriviaData,
          ),
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              key: TriviaKeys.loading,
              color: ShowdownColors.plum,
            ),
            SizedBox(height: 24),
            Text(
              'Requesting five easy questions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ShowdownColors.ink,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Open Trivia Database · General Knowledge',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: ShowdownColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: ShowdownColors.plum),
              const SizedBox(height: 16),
              const Text(
                "Couldn't load the round",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: ShowdownColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                key: TriviaKeys.errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: ShowdownColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nothing from this response was turned into a round.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: ShowdownColors.muted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: TriviaKeys.retry,
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.round,
    required this.simulated,
    required this.syncing,
    required this.synced,
    required this.onAnswer,
    required this.onContinue,
    required this.onSync,
    required this.onReplay,
  });

  final TriviaRound round;
  final bool simulated;
  final bool syncing;
  final bool synced;
  final ValueChanged<String> onAnswer;
  final VoidCallback onContinue;
  final VoidCallback onSync;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: round.isComplete
            ? _ResultsBody(
                score: round.score,
                total: round.total,
                simulated: simulated,
                syncing: syncing,
                synced: synced,
                onSync: onSync,
                onReplay: onReplay,
              )
            : _QuestionBody(
                round: round,
                onAnswer: onAnswer,
                onContinue: onContinue,
              ),
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    required this.round,
    required this.onAnswer,
    required this.onContinue,
  });

  final TriviaRound round;
  final ValueChanged<String> onAnswer;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final question = round.current;
    final number = round.currentIndex + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Question $number of ${round.total}',
          key: TriviaKeys.progress,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ShowdownColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: number / round.total,
                  minHeight: 8,
                  backgroundColor: ShowdownColors.line,
                  color: ShowdownColors.plum,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              key: TriviaKeys.score,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ShowdownColors.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Score ${round.score}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ShowdownColors.goldInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ShowdownColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ShowdownColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GENERAL KNOWLEDGE · EASY',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: ShowdownColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                question.questionText,
                key: TriviaKeys.question,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: ShowdownColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < question.options.length; index++) ...[
          AnswerOption(
            letter: String.fromCharCode(65 + index),
            label: question.options[index],
            tone: _tone(round, question.options[index]),
            onPressed: round.hasAnswered
                ? null
                : () => onAnswer(question.options[index]),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        FilledButton(
          key: TriviaKeys.continueButton,
          onPressed: round.hasAnswered ? onContinue : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

AnswerTone _tone(TriviaRound round, String option) {
  if (!round.hasAnswered) {
    return AnswerTone.neutral;
  }
  if (option == round.current.correctAnswer) {
    return AnswerTone.correct;
  }
  if (option == round.selectedAnswer) {
    return AnswerTone.incorrect;
  }
  return AnswerTone.neutral;
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.score,
    required this.total,
    required this.simulated,
    required this.syncing,
    required this.synced,
    required this.onSync,
    required this.onReplay,
  });

  final int score;
  final int total;
  final bool simulated;
  final bool syncing;
  final bool synced;
  final VoidCallback onSync;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final submission = ScoreSubmission(score: score, total: total);
    final note = _syncNote(
      simulated: simulated,
      syncing: syncing,
      synced: synced,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Icon(Icons.emoji_events, size: 48, color: ShowdownColors.plum),
        const SizedBox(height: 12),
        Text(
          _headline(score, total),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ShowdownColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$score out of $total',
          key: TriviaKeys.resultsScore,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: ShowdownColors.plum,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Final score for this loaded round.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: ShowdownColors.muted),
        ),
        const SizedBox(height: 20),
        Container(
          key: TriviaKeys.syncNote,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: simulated ? const Color(0xFFFFF7E6) : ShowdownColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: simulated ? const Color(0xFFE4C56A) : ShowdownColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                simulated ? 'Classroom simulation' : 'Instructor leaderboard',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ShowdownColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note,
                style: const TextStyle(height: 1.4, color: ShowdownColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Payload: ${submission.toJsonString()}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: ShowdownColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: TriviaKeys.syncButton,
          onPressed: syncing || synced ? null : onSync,
          child: const Text('Sync Score to Leaderboard'),
        ),
        if (syncing) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            key: TriviaKeys.syncProgress,
            minHeight: 4,
            color: ShowdownColors.plum,
            backgroundColor: ShowdownColors.line,
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          key: TriviaKeys.replayButton,
          onPressed: syncing ? null : onReplay,
          child: const Text('Play again'),
        ),
      ],
    );
  }
}

String _headline(int score, int total) {
  if (total <= 0) {
    return 'Round complete.';
  }
  if (score == total) {
    return 'Clean sweep.';
  }
  if (score * 2 >= total) {
    return 'Solid round.';
  }
  if (score == 0) {
    return 'Tough set.';
  }
  return 'Worth another pass.';
}

String _syncNote({
  required bool simulated,
  required bool syncing,
  required bool synced,
}) {
  if (syncing) {
    return simulated
        ? 'Waiting out the classroom simulation. No request is being sent.'
        : 'Sending the score. Success appears only after the server accepts it.';
  }
  if (synced) {
    return simulated
        ? 'Simulation complete. No request was sent, and nothing was saved on a server.'
        : 'Saved. The leaderboard accepted this score.';
  }
  return simulated
      ? 'Sync Score to Leaderboard waits briefly, then confirms. No request is sent.'
      : 'Sync Score to Leaderboard sends this score with HTTP POST. Success appears only after the server accepts it.';
}
