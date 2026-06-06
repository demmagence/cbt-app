import 'package:flutter/material.dart';

/// A premium and compact countdown timer widget with status color-coding.
///
/// States:
/// - Normal (>= 5 minutes): Primary theme color
/// - Warning (< 5 minutes): Orange/Amber color
/// - Critical (< 1 minute): Red color with blinking animation
class CountdownTimer extends StatefulWidget {
  /// Remaining time in seconds.
  final int remainingTime;

  const CountdownTimer({
    super.key,
    required this.remainingTime,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkBlinkState();
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkBlinkState();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _checkBlinkState() {
    if (widget.remainingTime < 60) {
      if (!_blinkController.isAnimating) {
        _blinkController.repeat(reverse: true);
      }
    } else {
      if (_blinkController.isAnimating) {
        _blinkController.stop();
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Color _getTimerColor(ThemeData theme) {
    if (widget.remainingTime < 60) {
      return Colors.red[700]!;
    } else if (widget.remainingTime < 300) {
      return Colors.amber[800]!;
    } else {
      return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getTimerColor(theme);
    final formattedTime = _formatDuration(widget.remainingTime);
    final isCritical = widget.remainingTime < 60;

    final timerWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_filled_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          formattedTime,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    if (isCritical) {
      return FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.2).animate(_blinkController),
        child: timerWidget,
      );
    }

    return timerWidget;
  }
}
