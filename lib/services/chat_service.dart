
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Needed for compute()
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class ChatService extends ChangeNotifier {
  List<String> messages = [];
  TextEditingController controller = TextEditingController();

  Future<void> sendMessage() async {
    String userMessage = controller.text;
    if (userMessage.isEmpty) return;

    messages.add("You: $userMessage");
    notifyListeners();

    // Offload AI call to a separate isolate
    String aiResponse = await compute(fetchAIResponse, userMessage);
    messages.add("AI: $aiResponse");
    notifyListeners();

    controller.clear();
  }
}

// Move AI call to an isolate (avoids blocking UI)
Future<String> fetchAIResponse(String prompt) async {
  try {
    final apiKey = ''; 

    if (apiKey == null || apiKey.isEmpty) {
      return "Error: API key not found!";
    }

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/completions"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [{"role": "user", "content": prompt}],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"] ?? "No response from AI.";
    } else {
      return "Error: ${response.statusCode} - ${response.body}";
    }
  } catch (e) {
    return "Error: Failed to fetch AI response. Details: $e";
  }
}
