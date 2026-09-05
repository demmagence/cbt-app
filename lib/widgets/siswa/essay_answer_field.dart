import 'package:flutter/material.dart';

/// Every edit reaches the session immediately, including the last keystroke
/// before navigating or submitting. Persistence status belongs to the session.
class EssayAnswerField extends StatefulWidget {
  final String initialText;
  final ValueChanged<String>? onChanged;
  const EssayAnswerField({super.key, this.initialText = '', this.onChanged});
  @override
  State<EssayAnswerField> createState() => _EssayAnswerFieldState();
}

class _EssayAnswerFieldState extends State<EssayAnswerField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  @override
  void didUpdateWidget(EssayAnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != widget.initialText) {
      _controller.value = TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lembar Jawaban:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          minLines: 5,
          maxLines: null,
          maxLength: 10000,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Tulis jawaban Anda di sini...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            widget.onChanged?.call(value);
            setState(() {});
          },
        ),
        Text(
          '${text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length} kata',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
