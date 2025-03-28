import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class STTService with ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  bool isListening = false;
  String _currentText = "";
  String _finalText = "";

  String get currentText => _currentText;
  String get finalText => _finalText;

  Future<bool> initialize() async {
    return await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          stopListening();
        }
      },
      onError: (error) {
        stopListening();
        _currentText = "Error: ${error.errorMsg}";
        notifyListeners();
      },
    );
  }

  Future<bool> startListening() async {
    if (!await initialize()) return false;

    _currentText = "";
    _finalText = "";
    isListening = true;
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _finalText = result.recognizedWords;
        }
        _currentText = result.recognizedWords;
        notifyListeners();
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );

    return true;
  }

  Future<void> stopListening() async {
    if (isListening) {
      await _speech.stop();
      isListening = false;
      notifyListeners();
    }
  }

  void clearText() {
    _currentText = "";
    _finalText = "";
    notifyListeners();
  }
}