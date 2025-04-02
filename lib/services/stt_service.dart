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
  bool get isWakeWordMode => _wakeWordMode;
 

  void setWakeWordMode(bool enabled) {
  _wakeWordMode = enabled;
  notifyListeners();
}

void resetToWakeWordMode() {
  _wakeWordMode = true;
  _currentText = "";
  _finalText = "";
  notifyListeners();
}
void clearCurrentText() {
  _currentText = "";
  notifyListeners();
}

void clearFinalText() {
  _finalText = "";
  notifyListeners();
}

void clearAllText() {
  _currentText = "";
  _finalText = "";
  notifyListeners();
}

  Future<bool> initialize() async {
  try {
    _isProcessing = true;
    notifyListeners();
    
    final initialized = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'notListening' && isListening) {
          _restartListening();
        }
      },
      onError: (error) {
        _lastError = "Error: ${error.errorMsg}";
        debugPrint('Speech error: $_lastError');
        if (isListening) {
          _restartListening();
        }
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

    // Don't reset text if we're continuing a session
    if (!isListening) {
      _currentText = "";
      _finalText = "";
    }
    
    _lastError = "";
    isListening = true;
    _wakeWordMode = !forceListen;
    _justDetectedWakeWord = false;
    
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

  // In STTService
void _handleSpeechResult(SpeechRecognitionResult result) async {
  try {
    _isProcessing = true;
    notifyListeners();
    
    if (_wakeWordMode) {
      final lowerText = result.recognizedWords.toLowerCase();
      if (lowerText.contains('hey')) {
        // Wake word detected - switch to active listening
        _wakeWordMode = false;
        _justDetectedWakeWord = true;
        
        final heyIndex = lowerText.indexOf('hey');
        _currentText = result.recognizedWords.substring(heyIndex + 3).trim();
        
        debugPrint('Wake word detected - switching to active listening');
        notifyListeners();
        
        // Ensure listening continues
        if (!isListening) {
          await startListening();
        }
        return;
      }
      _currentText = "";
    } else {
      // Active listening mode
      _currentText = result.recognizedWords;
      _justDetectedWakeWord = false;
      
      if (result.finalResult) {
        _finalText = _currentText;
      }
    }
  } catch (e) {
    _lastError = "Result handling error: $e";
    debugPrint('Speech result error: $_lastError');
    await _restartListening();
  } finally {
    _isProcessing = false;
    notifyListeners();
  }
}

  Future<void> _restartListening() async {
  try {
    if (!isListening) return;
    
    _isProcessing = true;
    notifyListeners();
    
    await _speech.stop();
    await Future.delayed(Duration(milliseconds: 300));
    
    // Only restart if we're still supposed to be listening
    if (isListening) {
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    }
  } catch (e) {
    _lastError = "Restart error: $e";
    // Attempt to recover
    await startListening();
  } finally {
    _isProcessing = false;
    notifyListeners();
  }
}
Future<void> continueListening() async {
  if (isListening && !_wakeWordMode) {
    try {
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      await _restartListening();
    }
  }
}

  Future<void> stopListening() async {
   if (!isListening) return;
  
  try {
    _isProcessing = true;
    notifyListeners();
    
    await _speech.stop();
    
    // Reset only the necessary states
    _wakeWordMode = true;
    _currentText = "";
    _finalText = "";
    _justDetectedWakeWord = false;
    
    // Immediately restart listening for wake word
    await Future.delayed(Duration(milliseconds: 300)); // Small delay for stability
    await _speech.listen(
      onResult: _handleSpeechResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    
    debugPrint('Successfully returned to wake word listening');
  } catch (e) {
    _lastError = "Error stopping active listening: $e";
    debugPrint('Error returning to wake word: $_lastError');
    // Attempt full restart if partial restart fails
    await startListening();
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