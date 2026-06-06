import 'dart:async';
import 'package:flutter/material.dart';

/// Save status for the auto-save indicator.
enum EssaySaveStatus { saved, saving, unsaved }

/// A premium multi-line text area widget for essay answers.
///
/// Features:
/// - Responsive height (min 5 lines, expands as needed)
/// - Real-time word count and character count
/// - Auto-save indicator ("Tersimpan" / "Menyimpan...")
/// - Debounced auto-save callback (default: 3 seconds after stop typing)
class EssayAnswerField extends StatefulWidget {
  /// Initial answer text.
  final String initialText;

  /// Called immediately on each keystroke (for local state sync).
  final ValueChanged<String>? onChanged;

  /// Called after the debounce period elapses, with the current text.
  final ValueChanged<String>? onAutoSave;

  /// Debounce duration before triggering [onAutoSave]. Default: 3 seconds.
  final Duration debounceDuration;

  const EssayAnswerField({
    super.key,
    this.initialText = '',
    this.onChanged,
    this.onAutoSave,
    this.debounceDuration = const Duration(seconds: 3),
  });

  @override
  State<EssayAnswerField> createState() => _EssayAnswerFieldState();
}

class _EssayAnswerFieldState extends State<EssayAnswerField> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;
  EssaySaveStatus _saveStatus = EssaySaveStatus.saved;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(EssayAnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync text if the initial text changed from the outside (question switch).
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != widget.initialText) {
      _controller.text = widget.initialText;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      // Reset save status when switching questions
      _debounceTimer?.cancel();
      setState(() {
        _saveStatus = EssaySaveStatus.saved;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onChanged?.call(text);

    setState(() {
      _saveStatus = EssaySaveStatus.saving;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onAutoSave?.call(text);
      if (mounted) {
        setState(() {
          _saveStatus = EssaySaveStatus.saved;
        });
      }
    });
  }

  int _getWordCount() {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordCount = _getWordCount();
    final charCount = _controller.text.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row: label + auto-save indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lembar Jawaban:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildSaveIndicator(theme),
          ],
        ),
        const SizedBox(height: 8),

        // Multi-line expandable text field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            color: theme.colorScheme.surface,
          ),
          child: TextField(
            controller: _controller,
            minLines: 5,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            decoration: InputDecoration(
              hintText: 'Tulis jawaban Anda di sini...',
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Footer row: word count + char count
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CountChip(
              icon: Icons.text_fields_rounded,
              label: '$wordCount kata',
              theme: theme,
            ),
            const SizedBox(width: 8),
            _CountChip(
              icon: Icons.numbers_rounded,
              label: '$charCount karakter',
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveIndicator(ThemeData theme) {
    switch (_saveStatus) {
      case EssaySaveStatus.saved:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: Colors.green[600]),
            const SizedBox(width: 4),
            Text(
              'Tersimpan',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      case EssaySaveStatus.saving:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Menyimpan...',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      case EssaySaveStatus.unsaved:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange[700]),
            const SizedBox(width: 4),
            Text(
              'Belum tersimpan',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
    }
  }
}

/// A small info chip showing an icon and label.
class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _CountChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
