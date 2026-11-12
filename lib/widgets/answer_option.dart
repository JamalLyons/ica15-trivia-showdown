import 'package:material_ui/material_ui.dart';

import '../showdown_colors.dart';

enum AnswerTone { neutral, correct, incorrect }

/// One shuffled choice. Green marks the correct option, red an incorrect pick.
///
/// A check or X is drawn with the color so the result is not color-only.
class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.letter,
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final String letter;
  final String label;
  final AnswerTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(tone);
    final status = switch (tone) {
      AnswerTone.correct => 'Correct answer',
      AnswerTone.incorrect => 'Incorrect selection',
      AnswerTone.neutral => null,
    };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: status == null ? '$letter. $label' : '$letter. $label. $status',
      child: Material(
        color: palette.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.border,
                width: tone == AnswerTone.neutral ? 1 : 2,
              ),
            ),
            child: Row(
              children: [
                _LetterBadge(
                  letter: letter,
                  palette: palette,
                  filled: tone != AnswerTone.neutral,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: palette.foreground,
                    ),
                  ),
                ),
                if (tone == AnswerTone.correct)
                  const Icon(Icons.check_circle, color: ShowdownColors.correct)
                else if (tone == AnswerTone.incorrect)
                  const Icon(Icons.cancel, color: ShowdownColors.incorrect),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

_Palette _paletteFor(AnswerTone tone) {
  return switch (tone) {
    AnswerTone.correct => const _Palette(
      background: ShowdownColors.correctBackground,
      foreground: ShowdownColors.correct,
      border: ShowdownColors.correct,
    ),
    AnswerTone.incorrect => const _Palette(
      background: ShowdownColors.incorrectBackground,
      foreground: ShowdownColors.incorrect,
      border: ShowdownColors.incorrect,
    ),
    AnswerTone.neutral => const _Palette(
      background: ShowdownColors.card,
      foreground: ShowdownColors.ink,
      border: ShowdownColors.line,
    ),
  };
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({
    required this.letter,
    required this.palette,
    required this.filled,
  });

  final String letter;
  final _Palette palette;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? palette.border : ShowdownColors.paper,
        shape: BoxShape.circle,
        border: Border.all(color: palette.border),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : palette.foreground,
        ),
      ),
    );
  }
}
