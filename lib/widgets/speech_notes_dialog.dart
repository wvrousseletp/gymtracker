import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechNotesDialog extends StatefulWidget {
  final String exerciseName;
  final String initialNote;
  final Function(String) onSave;

  const SpeechNotesDialog({
    super.key,
    required this.exerciseName,
    required this.initialNote,
    required this.onSave,
  });

  @override
  State<SpeechNotesDialog> createState() => _SpeechNotesDialogState();
}

class _SpeechNotesDialogState extends State<SpeechNotesDialog> {
  late TextEditingController _controller;
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: (result) {
      setState(() {
        _controller.text = result.recognizedWords;
      });
    });
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.1)),
      ),
      title: Text(
        "Anotações: ${widget.exerciseName}",
        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E))),
            decoration: InputDecoration(
              hintText: "Senti o ombro, banco inclinado no nível 3...",
              hintStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93))),
              filled: true,
              fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_speechEnabled) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTapDown: (_) => _startListening(),
              onTapUp: (_) => _stopListening(),
              onTapCancel: () => _stopListening(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isListening ? Colors.redAccent : Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.white : Colors.blue,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isListening ? "Ouvindo... Solte para parar" : "Segure para falar",
              style: TextStyle(
                color: _isListening ? Colors.redAccent : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)))),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_controller.text);
            Navigator.pop(context);
          },
          child: Text("Salvar", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
