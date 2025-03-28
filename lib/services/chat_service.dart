import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  ChatMessage({required this.role, required this.content});
}

class ChatService extends ChangeNotifier {
  final String apiKey;
  List<ChatMessage> messages = [];
  TextEditingController controller = TextEditingController();
  bool isTyping = false;
  bool _cancelRequest = false;

  ChatService(this.apiKey);

  Future<void> sendMessage() async {
    final userMessage = controller.text.trim();
    if (userMessage.isEmpty) return;

    // Add user message
    messages.add(ChatMessage(role: 'user', content: userMessage));
    notifyListeners();
    controller.clear();

    // Start typing indicator
    isTyping = true;
    notifyListeners();

    try {
      // Get AI response (non-streaming version)
      final aiResponse = await compute(_fetchAIResponse, {
        'prompt': userMessage,
        'apiKey': apiKey
      });

      if (_cancelRequest) {
        _cancelRequest = false;
        isTyping = false;
        notifyListeners();
        return;
      }

      // Add AI response
      messages.add(ChatMessage(role: 'assistant', content: aiResponse));
    } catch (e) {
      messages.add(ChatMessage(
        role: 'assistant',
        content: "Error: Failed to get AI response. ${e.toString()}"
      ));
    } finally {
      isTyping = false;
      _cancelRequest = false;
      notifyListeners();
    }
  }

  static Future<String> _fetchAIResponse(Map<String, String> data) async {
    try {
      final prompt = data['prompt']!;
      final apiKey = data['apiKey']!;

      if (apiKey.isEmpty) {
        return "Error: API key not found!";
      }

      final response = await http.post(
        Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData["candidates"]?[0]["content"]["parts"]?[0]["text"] ?? "No response from AI.";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: Failed to fetch AI response. Details: $e";
    }
  }

  void stopResponse() {
    _cancelRequest = true;
    isTyping = false;
    notifyListeners();
  }

  void clearMessages() {
    messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
