import 'package:flutter/material.dart';
import '../../blocs/siswa/exam_session_state.dart';

/// QuestionNavigator widget that displays a beautiful, premium question palette.
/// It includes:
/// - A progress indicator showing X / Y questions answered.
/// - A modern grid showing color-coded question numbers.
/// - A clear legend of the color codes.
/// - Smooth navigation callbacks.
class QuestionNavigator extends StatelessWidget {
  final ExamSessionActive state;
  final ValueChanged<int> onQuestionTap;

  const QuestionNavigator({
    super.key,
    required this.state,
    required this.onQuestionTap,
  });

  int _getAnsweredCount() {
    int count = 0;
    for (final q in state.questions) {
      final hasAnswer = state.session.answers.containsKey(q.id) &&
          (state.session.answers[q.id]?.toString().trim().isNotEmpty ?? false);
      if (hasAnswer) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCount = state.questions.length;
    final answeredCount = _getAnsweredCount();
    final progress = totalCount > 0 ? (answeredCount / totalCount) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Title + Badge Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Navigasi Soal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$answeredCount / $totalCount Terjawab',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 20),

          // Legend color-coding
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _LegendItem(
                  color: theme.colorScheme.primary,
                  label: 'PG (Terjawab)',
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _LegendItem(
                  color: Colors.green[600]!,
                  label: 'Essay (Terjawab)',
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _LegendItem(
                  color: Colors.transparent,
                  borderColor: theme.colorScheme.outline.withValues(alpha: 0.5),
                  label: 'Belum Dijawab',
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _LegendItem(
                  color: Colors.transparent,
                  borderColor: theme.colorScheme.outline.withValues(alpha: 0.15),
                  label: 'Belum Dikunjungi',
                  theme: theme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Grid of numbers
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                final q = state.questions[index];
                final isCurrent = index == state.currentIndex;
                final isVisited = state.visitedQuestions.contains(q.id);
                final hasAnswer = state.session.answers.containsKey(q.id) &&
                    (state.session.answers[q.id]?.toString().trim().isNotEmpty ?? false);
                final isFlagged = state.flaggedQuestions.contains(q.id);

                // Define styling based on state and type
                Color bgColor = Colors.transparent;
                Color textColor = theme.colorScheme.onSurface;
                Border border = Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: isVisited ? 0.5 : 0.15),
                  width: 1.5,
                );

                if (hasAnswer) {
                  if (q.isPg) {
                    bgColor = theme.colorScheme.primary;
                    textColor = theme.colorScheme.onPrimary;
                    border = Border.all(color: Colors.transparent);
                  } else {
                    bgColor = Colors.green[600]!;
                    textColor = Colors.white;
                    border = Border.all(color: Colors.transparent);
                  }
                } else if (isFlagged) {
                  bgColor = Colors.amber[600]!;
                  textColor = Colors.white;
                  border = Border.all(color: Colors.transparent);
                }

                // Current question highlight (thicker colored border)
                if (isCurrent) {
                  border = Border.all(
                    color: theme.colorScheme.secondary,
                    width: 3.5,
                  );
                }

                return Material(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onQuestionTap(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final String label;
  final ThemeData theme;

  const _LegendItem({
    required this.color,
    this.borderColor,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
