import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class ChatService extends ChangeNotifier {
  final String apiKey;
  List<String> messages = [];
  TextEditingController controller = TextEditingController();

  ChatService(this.apiKey);

  Future<void> sendMessage() async {
    String userMessage = controller.text;
    if (userMessage.isEmpty) return;

    messages.add("You: $userMessage");
    notifyListeners();

    // Offload AI call to a separate isolate (avoids blocking UI)
    String aiResponse = await compute(fetchAIResponse, {'prompt': userMessage, 'apiKey': apiKey});
    messages.add("AI: $aiResponse");
    notifyListeners();

    controller.clear();
  }
}

// Move AI call to an isolate (avoids blocking UI)
Future<String> fetchAIResponse(Map<String, String> data) async {
  try {
    String prompt = data['prompt']!;
    String apiKey = data['apiKey']!;

    if (apiKey.isEmpty) {
      return "Error: API key not found!";
    }

    final response = await http.post(
      Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["candidates"]?[0]["content"]["parts"]?[0]["text"] ?? "No response from AI.";
    } else {
      return "Error: ${response.statusCode} - ${response.body}";
    }
  } catch (e) {
    return "Error: Failed to fetch AI response. Details: $e";
  }
}
