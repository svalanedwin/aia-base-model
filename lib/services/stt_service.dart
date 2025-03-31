import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class STTService with ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  bool isListening = false;
  bool _isProcessing = false;
  String _currentText = "";
  String _finalText = "";
  String _lastError = "";
  bool _wakeWordMode = true;
  bool _justDetectedWakeWord = false;

  // Getters
  String get currentText => _currentText;
  String get finalText => _finalText;
  String get lastError => _lastError;
  bool get isWaitingForWakeWord => _wakeWordMode;
  bool get isActiveListening => !_wakeWordMode && isListening;
  bool get isProcessing => _isProcessing;

  Future<bool> initialize() async {
    try {
      _isProcessing = true;
      notifyListeners();
      
      final initialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            _restartListening();
          }
        },
        onError: (error) {
          _lastError = "Error: ${error.errorMsg}";
          _restartListening();
          notifyListeners();
        },
      );
      
      return initialized;
    } catch (e) {
      _lastError = "Initialization error: $e";
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> startListening({bool forceListen = false}) async {
    if (!await initialize()) return false;

    try {
      _isProcessing = true;
      notifyListeners();

      _currentText = "";
      _finalText = "";
      _lastError = "";
      isListening = true;
      _wakeWordMode = !forceListen;
      _justDetectedWakeWord = false;
      
      notifyListeners();

      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );

      return true;
    } catch (e) {
      _lastError = "Start listening error: $e";
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    try {
      _isProcessing = true;
      
      if (_wakeWordMode) {
        // In wake word detection mode
        final recognizedWords = result.recognizedWords.toLowerCase();
        if (recognizedWords.contains('hey')) {
          // Wake word detected - transition to active listening
          _wakeWordMode = false;
          _justDetectedWakeWord = true;
          
          // Get text after the wake word
          final wakeWordIndex = recognizedWords.indexOf('hey');
          final textAfterWakeWord = result.recognizedWords.substring(wakeWordIndex + 3).trim();
          
          if (textAfterWakeWord.isNotEmpty) {
            _currentText = textAfterWakeWord;
          } else {
            _currentText = "";
          }
        } else {
          // Completely ignore any text before wake word
          _currentText = "";
        }
      } else {
        // In active listening mode
        if (_justDetectedWakeWord) {
          // First result after wake word - reset to ensure clean state
          _currentText = result.recognizedWords;
          _justDetectedWakeWord = false;
        } else {
          // Normal active listening
          _currentText = result.recognizedWords;
        }
      }
      
      if (result.finalResult) {
        _finalText = _currentText;
        if (!_wakeWordMode) {
          _restartListening();
        }
      }
    } catch (e) {
      _lastError = "Result handling error: $e";
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _restartListening() async {
    try {
      _isProcessing = true;
      notifyListeners();
      
      await stopListening();
      await Future.delayed(Duration(milliseconds: 300));
      await startListening();
    } catch (e) {
      _lastError = "Restart error: $e";
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      if (isListening) {
        _isProcessing = true;
        notifyListeners();
        
        await _speech.stop();
        isListening = false;
        _wakeWordMode = true;
        _currentText = "";
        _finalText = "";
        _justDetectedWakeWord = false;
        notifyListeners();
      }
    } catch (e) {
      _lastError = "Stop listening error: $e";
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clearText() {
    _currentText = "";
    _finalText = "";
    _lastError = "";
    notifyListeners();
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }
}