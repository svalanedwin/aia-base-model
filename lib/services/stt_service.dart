import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class STTService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  bool isListening = false;
  String text = ""; // Recognized speech text

  // Start listening to speech
  Future<void> startListening() async {
    bool available = await _speech.initialize(onStatus: (status) {
      print("STT Status: $status");
    }, onError: (errorNotification) {
      print("STT Error: $errorNotification");
    });
    
    if (available) {
      isListening = true;
      notifyListeners();  // Notify listeners that we are listening
      _speech.listen(onResult: (result) {
        text = result.recognizedWords;  // Update recognized words
        notifyListeners();  // Notify listeners for UI update
      });
    } else {
      // Handle case if STT initialization fails
      text = "Speech recognition is not available.";
      notifyListeners();
    }
  }

  // Stop listening to speech
  void stopListening() {
    isListening = false;
    _speech.stop();
    notifyListeners();  // Notify listeners for UI update
  }
}
