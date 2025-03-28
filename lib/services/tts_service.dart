import 'package:flutter_tts/flutter_tts.dart';
// Text-to-Speech Service
class TTSService {
  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text) async {
    await _tts.setLanguage("en-US");
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}